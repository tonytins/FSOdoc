extension Primitives {
    /// Waits for a number of ticks, or until an interaction or an interrupt comes (opcode 17).
    ///
    /// Ports FreeSO's `VMIdleForInput`. Each run counts the ticks since the wait began off the
    /// argument it names, as Sleep does. An interaction tree, or main with interactions queued, ends
    /// it, as does an interrupt or the count running out (all true). Otherwise it waits: every tick
    /// when it allows interactions to be pushed, or else until the count would run out.
    ///
    /// NSOClient has no interaction queue yet, so main always finds it empty, as FreeSO does on a
    /// lot with no Sims; in an interaction tree it reports ``SimAnticsError/unsupported(_:)``.
    public enum IdleForInput: Primitive {
        public static let name = "idle_for_input"
        public static let opcode: UInt8 = 17

        public struct Operand: PrimitiveOperand, Equatable {
            /// The argument the count is in.
            public var argument: Int16
            /// 1: check for interactions to push every tick.
            public var allowPush: UInt16

            public init(argument: Int16, allowPush: UInt16 = 0) {
                self.argument = argument
                self.allowPush = allowPush
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                argument = reader.int16()
                allowPush = reader.uint16()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.int16(argument)
                    writer.uint16(allowPush)
                }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let thread = frame.thread
            let scheduler = frame.vm.scheduler
            let idleStart = thread.idleStartTick
            thread.idleStartTick = 0
            guard operand.argument >= 0, Int(operand.argument) < frame.arguments.count else {
                throw .indexOutOfRange("parameter \(operand.argument)")
            }
            let index = Int(operand.argument)
            let elapsed = idleStart != 0 && idleStart < scheduler.currentTick ? scheduler.currentTick &- idleStart : 1
            frame.arguments[index] &-= Int16(truncatingIfNeeded: elapsed)

            // With no interaction queue, main can't push one, and an interaction tree can't be cancelled.
            guard !frame.isActionTree else { throw .unsupported("interactions") }
            if thread.isInterrupted {
                thread.isInterrupted = false
                return .gotoTrue
            }
            if frame.arguments[index] < 0 { return .gotoTrue }
            if operand.allowPush == 1 { return .continueNextTick }
            guard let caller = frame.caller else { throw .nullReference("no caller to schedule") }
            thread.idleStartTick = scheduler.currentTick
            scheduler.scheduleTick(for: caller, in: UInt32(bitPattern: Int32(frame.arguments[index])) &+ 1)
            return .continueFutureTick
        }
    }
}
