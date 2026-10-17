extension Primitives {
    /// Wakes the stack object (opcode 49).
    ///
    /// Ports FreeSO's `VMNotifyOutOfIdle`. The stack object's next run is brought forward, as
    /// ``VMScheduler/rescheduleInterrupt(_:)`` does, and its thread is marked interrupted, which
    /// ends a Sleep at once. With no stack object it does nothing. Either way it's true.
    public enum NotifyStackObjectOutOfIdle: Primitive {
        public static let name = "stackobj_notify_out_of_idle"
        public static let opcode: UInt8 = 49

        /// No fields: the operand's bytes are ignored.
        public struct Operand: PrimitiveOperand, Equatable {
            public init() {}
            public init(bytes: [UInt8]) {}
            public func encoded() -> [UInt8] { OperandWriter.bytes { _ in } }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            if let stackObject = frame.stackObject {
                frame.vm.scheduler.rescheduleInterrupt(stackObject)
                stackObject.thread.isInterrupted = true
            }
            return .gotoTrue
        }
    }
}
