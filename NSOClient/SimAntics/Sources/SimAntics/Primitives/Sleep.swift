extension Primitives {
    /// Waits a number of ticks held in an argument (opcode 0).
    ///
    /// Ports FreeSO's `VMSleep`. Each time it runs, the argument goes down by the ticks since
    /// the wait began (or by 1 on the first run), wrapping like a C# `short`. At exactly -1 the
    /// wait ends: the thread's idle start is cleared, one random number is drawn (FreeSO does this
    /// so desynced clients drift apart), and it takes the true branch. Otherwise the caller is
    /// scheduled `argument + 1` ticks ahead, the count read as unsigned as in FreeSO, so a value
    /// below -1 waits about 2^32 ticks. An interrupted thread ends the wait at once.
    public enum Sleep: Primitive {
        public static let name = "sleep"
        public static let opcode: UInt8 = 0

        public struct Operand: PrimitiveOperand, Equatable {
            /// The argument that counts down.
            public var argument: Int16

            public init(argument: Int16) {
                self.argument = argument
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                argument = reader.int16()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { $0.int16(argument) }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let thread = frame.thread
            let scheduler = frame.vm.scheduler
            guard operand.argument >= 0, Int(operand.argument) < frame.arguments.count else {
                throw .indexOutOfRange("parameter \(operand.argument)")
            }
            let index = Int(operand.argument)
            let idleStart = thread.idleStartTick
            let elapsed = idleStart != 0 && idleStart < scheduler.currentTick ? scheduler.currentTick &- idleStart : 1
            frame.arguments[index] &-= Int16(truncatingIfNeeded: elapsed)

            if thread.isInterrupted {
                thread.idleStartTick = 0
                thread.isInterrupted = false
                return .gotoTrue
            }
            if frame.arguments[index] == -1 {
                thread.idleStartTick = 0
                _ = frame.vm.random.next(below: 1)
                return .gotoTrue
            }
            guard let caller = frame.caller else { throw .nullReference("no caller to schedule") }
            thread.idleStartTick = scheduler.currentTick
            scheduler.scheduleTick(for: caller, in: UInt32(bitPattern: Int32(frame.arguments[index])) &+ 1)
            return .continueFutureTick
        }
    }
}
