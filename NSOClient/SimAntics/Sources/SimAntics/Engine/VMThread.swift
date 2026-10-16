import TSOContent
import TSOFiles

/// An entity's interpreter: a stack of routines and the registers they share.
///
/// Ports the execution half of FreeSO's `VMThread`: instructions, subroutine calls,
/// exit codes, and branches. The interaction queue, entry points (running `main` when
/// the stack is empty), routing frames, and entity reset aren't ported yet; an error
/// clears the stack instead of resetting the entity.
public final class VMThread {
    /// 2017's guard against routines that never yield.
    public static let maximumInstructionsPerTick = 500_000

    public unowned let entity: Entity
    public var tempRegisters = [Int16](repeating: 0, count: 20)
    /// The two 32-bit temps (`TempXL`).
    public var tempXL = [Int32](repeating: 0, count: 2)
    /// The running routines; the last is executing.
    public var stack: [StackFrame] = []
    /// How the last routine to leave the stack exited.
    public private(set) var lastExitCode: ExitCode?
    /// The error that ended the last tick, if one did.
    public private(set) var lastError: SimAnticsError?
    /// The tick a wait for the next tick started on (`ScheduleIdleStart`).
    public private(set) var idleStartTick: UInt32 = 0

    private var continuesExecution = false
    private var instructionsThisTick = 0

    init(entity: Entity) {
        self.entity = entity
    }

    public var vm: VM { entity.vm }

    /// Runs instructions until one yields. A SimAntics error clears the stack and is kept in ``lastError``.
    public func tick() {
        instructionsThisTick = 0
        lastError = nil
        guard !stack.isEmpty else { return }
        do throws(SimAnticsError) {
            continuesExecution = true
            while continuesExecution {
                instructionsThisTick += 1
                if instructionsThisTick > Self.maximumInstructionsPerTick + 1 { throw .infiniteLoop }
                continuesExecution = false
                try nextInstruction()
            }
        } catch {
            lastError = error
            stack.removeAll()
        }
    }

    /// Adds a routine to the top of the stack with fresh locals. Empty routines aren't pushed, as in 2017.
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
        // As in 2017, this overrides whatever a pop above decided.
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
