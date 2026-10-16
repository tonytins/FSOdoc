import TSOContent

/// One routine running on a thread.
///
/// Ports FreeSO's `VMStackFrame`.
public final class StackFrame {
    public unowned let thread: VMThread
    public var routine: Routine
    public var instructionPointer: UInt16 = 0
    /// The entity whose behavior this is. `nil` where 2017 allows a null caller.
    public var caller: Entity?
    /// The entity the code runs on.
    public var callee: Entity?
    /// The object whose files the code came from; private and semi-global calls resolve through it.
    public var codeOwner: GameObject
    public var locals: [Int16] = []
    public var arguments: [Int16] = []
    /// Set on the frames of an interaction, which return to the queue instead of to a caller.
    public var discardsResult = false
    public var isActionTree = false

    private var storedStackObject: Entity?
    private var storedStackObjectID: Int16 = 0

    public init(thread: VMThread, routine: Routine, caller: Entity?, callee: Entity?, codeOwner: GameObject) {
        self.thread = thread
        self.routine = routine
        self.caller = caller
        self.callee = callee
        self.codeOwner = codeOwner
    }

    public var vm: VM { thread.vm }

    /// The object the code has selected to work on.
    public var stackObject: Entity? {
        get { storedStackObject }
        set {
            storedStackObject = newValue
            storedStackObjectID = newValue?.objectID ?? 0
        }
    }

    /// The stack object's ID. Setting an ID with no entity keeps the ID and clears the object, as in 2017.
    public var stackObjectID: Int16 {
        get { storedStackObjectID }
        set {
            storedStackObjectID = newValue
            storedStackObject = vm.entity(id: newValue)
        }
    }

    /// The instruction at the instruction pointer.
    public func currentInstruction() throws(SimAnticsError) -> Instruction {
        guard Int(instructionPointer) < routine.instructions.count else {
            throw .indexOutOfRange("instruction \(instructionPointer) of routine \(routine.id)")
        }
        return routine.instructions[Int(instructionPointer)]
    }
}
