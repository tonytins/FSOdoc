extension Primitives {
    /// A debugger breakpoint (opcode 15). Ports FreeSO's `VMBreakPoint`, which doesn't stop: it's
    /// always true. Its operand's bytes are ignored.
    public enum Breakpoint: Primitive {
        public static let name = "breakpoint"
        public static let opcode: UInt8 = 15

        public struct Operand: PrimitiveOperand, Equatable {
            public var bytes: [UInt8]
            public init(bytes: [UInt8]) { self.bytes = bytes }
            public func encoded() -> [UInt8] { OperandWriter.bytes { writer in bytes.prefix(8).forEach { writer.uint8($0) } } }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode { .gotoTrue }
    }

    /// A visual effect (opcode 35). Ports FreeSO's `VMSpecialEffect`, which on a TSO lot does
    /// nothing (it only centers The Sims 1's camera): always true. Its operand's bytes are ignored.
    public enum SpecialEffect: Primitive {
        public static let name = "special_effect"
        public static let opcode: UInt8 = 35

        public struct Operand: PrimitiveOperand, Equatable {
            public var bytes: [UInt8]
            public init(bytes: [UInt8]) { self.bytes = bytes }
            public func encoded() -> [UInt8] { OperandWriter.bytes { writer in bytes.prefix(8).forEach { writer.uint8($0) } } }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode { .gotoTrue }
    }

    /// Stops the sounds the caller or the stack object is playing (opcode 48). Ports FreeSO's
    /// `VMStopAllSounds`. Headless, as on FreeSO's server, nothing plays, so there's nothing to stop:
    /// always true.
    public enum StopAllSounds: Primitive {
        public static let name = "stop_all_sounds"
        public static let opcode: UInt8 = 48

        public struct Operand: PrimitiveOperand, Equatable {
            /// 1: the stack object's sounds; anything else, the caller's.
            public var flags: UInt8
            public init(flags: UInt8 = 0) { self.flags = flags }
            public init(bytes: [UInt8]) { var reader = OperandReader(bytes); flags = reader.uint8() }
            public func encoded() -> [UInt8] { OperandWriter.bytes { writer in writer.uint8(flags) } }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode { .gotoTrue }
    }
}
