import TSOContent
import TSOFiles

/// The temp registers, which a check thread may share with its entity's thread.
public final class Registers {
    public var temps = [Int16](repeating: 0, count: 20)
    /// The two 32-bit temps (`TempXL`).
    public var tempXL = [Int32](repeating: 0, count: 2)

    public init() {}

    func copy() -> Registers {
        let copy = Registers()
        copy.temps = temps
        copy.tempXL = tempXL
        return copy
    }
}

/// An entity's interpreter: a stack of routines and the registers they share.
///
/// Ports FreeSO's `VMThread` without the interaction queue and routing frames: instructions,
/// subroutine calls, exit codes and branches, running `main` when the stack empties, check
/// threads (``evaluateCheck(entity:frame:)``), and error handling. An error resets the
/// frame's caller and callee, and is reported at most once every 600 ticks (20 seconds).
public final class VMThread {
    /// FreeSO's guard against routines that never yield; the count restarts each entity tick.
    public static let maximumInstructionsPerTick = 500_000
    /// Ticks between error reports (`DialogCooldown`).
    static let errorCooldownTicks = 30 * 20

    public unowned let entity: Entity
    /// Whether this is a check thread, which runs a routine to completion and has no `main`.
    public let isCheck: Bool
    public var registers: Registers
    /// The running routines; the last is executing.
    public var stack: [StackFrame] = []
    /// How the last routine to leave the stack exited (`LastStackExitCode`).
    public private(set) var lastExitCode: ExitCode = .gotoFalse
    /// The error that ended the last tick, if one did.
    public private(set) var lastError: SimAnticsError?
    /// The tick the current wait started on, or 0 (`ScheduleIdleStart`). Sleep counts from it.
    public internal(set) var idleStartTick: UInt32 = 0
    /// Set when something wakes the thread early (`Interrupt`); Sleep then ends at once.
    public var isInterrupted = false
    /// The tick the entity is scheduled to run next, or 0 (`ScheduleIdleEnd`).
    public internal(set) var scheduledTick: UInt32 = 0
    /// Ticks until another error may be reported (`DialogCooldown`).
    public private(set) var errorCooldown = 0
    /// Instructions run since the entity's tick began (`TicksThisFrame`).
    var instructionsThisTick = 0

    private var continuesExecution = false

    init(entity: Entity, isCheck: Bool = false, registers: Registers = Registers()) {
        self.entity = entity
        self.isCheck = isCheck
        self.registers = registers
    }

    public var vm: VM { entity.vm }

    public var tempRegisters: [Int16] {
        get { registers.temps }
        set { registers.temps = newValue }
    }

    public var tempXL: [Int32] {
        get { registers.tempXL }
        set { registers.tempXL = newValue }
    }

    /// Runs a routine to completion on a temporary check thread, as `VMThread.EvaluateCheck` does.
    ///
    /// The check shares the entity's temps while the scheduler is running entities and works
    /// on a copy otherwise. It returns how the routine exited, or `returnFalse` if it failed.
    public static func evaluateCheck(entity: Entity, frame: StackFrame) -> ExitCode {
        let shared = entity.vm.scheduler.isRunning
        let check = VMThread(entity: entity, isCheck: true,
                             registers: shared ? entity.thread.registers : entity.thread.registers.copy())
        frame.thread = check
        check.push(frame)
        while !check.stack.isEmpty && check.errorCooldown == 0 {
            check.tick()
        }
        return check.errorCooldown > 0 ? .returnFalse : check.lastExitCode
    }

    /// Runs instructions until one yields. With an empty stack, a normal thread first pushes `main`.
    public func tick() {
        lastError = nil
        if errorCooldown > 0 { errorCooldown -= 1 }
        do throws(SimAnticsError) {
            if stack.isEmpty {
                if isCheck { return }
                try entity.executeEntryPoint(.main, runImmediately: false)
                if stack.isEmpty { return }
            }
            if stack.last?.isActionTree == true { throw .unsupported("interactions") }
            continuesExecution = true
            while continuesExecution {
                instructionsThisTick += 1
                if instructionsThisTick > Self.maximumInstructionsPerTick + 1 { throw .infiniteLoop }
                continuesExecution = false
                try nextInstruction()
            }
        } catch {
            handle(error)
        }
    }

    /// FreeSO's handler: report the error unless one was reported recently, then reset the frame's
    /// caller and callee (or clear a check thread's stack).
    private func handle(_ error: SimAnticsError) {
        lastError = error
        guard let frame = stack.last else { return }
        let recentlyFailed = errorCooldown > Self.errorCooldownTicks - 10
        if errorCooldown == 0 {
            vm.report(error, by: entity)
            errorCooldown = Self.errorCooldownTicks
        }
        guard !isCheck else {
            stack.removeAll()
            return
        }
        // When the caller is the callee, FreeSO resets it twice; its reset guard only stops nesting.
        frame.callee?.reset()
        frame.caller?.reset()
        if recentlyFailed {
            // An object that fails again within 10 ticks is deleted, with every part of it.
            vm.delete(entity, wholeGroup: true)
        }
    }

    /// Adds a routine to the top of the stack with fresh locals. Empty routines aren't pushed, as in FreeSO.
    public func push(_ frame: StackFrame) {
        guard !frame.routine.instructions.isEmpty else { return }
        stack.append(frame)
        frame.locals = [Int16](repeating: 0, count: Int(max(frame.routine.localCount, frame.routine.argumentCount)))
        frame.instructionPointer = 0
    }

    // MARK: Execution

    private func nextInstruction() throws(SimAnticsError) {
        guard let frame = stack.last else { return }
        let instruction = try frame.currentInstruction()
        switch instruction.operand {
        case .subroutine(let operand):
            try callSubroutine(instruction.opcode, operand: operand, from: frame)
            continuesExecution = true
        case .missingPrimitive:
            try handleResult(.gotoTrue, of: instruction, in: frame)
        case .unportedPrimitive(let name):
            throw .unsupported("primitive \(instruction.opcode) (\(name))")
        case .primitive(let primitive):
            try handleResult(try primitive.execute(in: frame), of: instruction, in: frame)
        }
    }

    /// Opcodes 256 to 4095 call the global, 4096 to 8191 the code owner's file, and 8192 and up its semi-global.
    private func callSubroutine(_ opcode: UInt16, operand: SubroutineOperand, from frame: StackFrame) throws(SimAnticsError) {
        guard let routine = try vm.routine(opcode: opcode, codeOwner: frame.codeOwner) else {
            try pop(.error)
            return
        }
        let child = StackFrame(thread: self, routine: routine, caller: frame.caller, callee: frame.callee,
                               codeOwner: frame.codeOwner)
        child.stackObject = frame.stackObject
        child.isActionTree = frame.isActionTree
        child.arguments = try (0..<max(Int(routine.argumentCount), 4)).map { (index) throws(SimAnticsError) -> Int16 in
            let argument = index > 3 ? -1 : operand.arguments[index]
            guard argument == -1 && operand.usesTemps else { return argument }
            guard index < tempRegisters.count else { throw .indexOutOfRange("temp \(index)") }
            return tempRegisters[index]
        }
        push(child)
    }

    private func handleResult(_ result: ExitCode, of instruction: Instruction, in frame: StackFrame) throws(SimAnticsError) {
        switch result {
        case .continueNextTick:
            waitForNextTick()
        case .continueFutureTick:
            continuesExecution = false
        case .error:
            continuesExecution = false
            try pop(result)
        case .returnTrue, .returnFalse:
            try pop(result)
        case .gotoTrue:
            try move(frame, to: instruction.truePointer, continuing: true)
        case .gotoFalse:
            try move(frame, to: instruction.falsePointer, continuing: true)
        case .gotoTrueNextTick:
            try move(frame, to: instruction.truePointer, continuing: false)
            waitForNextTick()
        case .gotoFalseNextTick:
            try move(frame, to: instruction.falsePointer, continuing: false)
            waitForNextTick()
        case .continue:
            continuesExecution = true
        case .interrupt:
            stack.removeAll()
            lastExitCode = result
        }
    }

    private func waitForNextTick() {
        idleStartTick = vm.scheduler.currentTick
        vm.scheduler.scheduleTick(for: entity, in: 1)
        continuesExecution = false
    }

    /// 255 returns false, 254 returns true, and 253 follows whichever branch isn't 253.
    private func move(_ frame: StackFrame, to pointer: UInt8, continuing: Bool) throws(SimAnticsError) {
        switch pointer {
        case 255:
            try pop(.returnFalse)
        case 254:
            try pop(.returnTrue)
        case 253:
            let instruction = try frame.currentInstruction()
            if instruction.truePointer != 253 { return try move(frame, to: instruction.truePointer, continuing: continuing) }
            if instruction.falsePointer != 253 { return try move(frame, to: instruction.falsePointer, continuing: continuing) }
            try pop(.error)
        default:
            frame.instructionPointer = UInt16(pointer)
        }
        // As in FreeSO, this overrides whatever a pop above decided.
        continuesExecution = continuing
    }

    /// Removes the top routine and hands its result to the one below, which treats a return as a branch.
    private func pop(_ result: ExitCode) throws(SimAnticsError) {
        guard let finished = stack.popLast() else { return }
        lastExitCode = result
        if finished.discardsResult { throw .unsupported("returning to the interaction queue") }
        guard let parent = stack.last else {
            continuesExecution = false
            return
        }
        let parentResult: ExitCode = switch result {
        case .returnTrue: .gotoTrue
        case .returnFalse: .gotoFalse
        default: result
        }
        try handleResult(parentResult, of: try parent.currentInstruction(), in: parent)
    }
}
