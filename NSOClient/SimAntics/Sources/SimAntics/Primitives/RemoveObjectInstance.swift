extension Primitives {
    /// Deletes the caller or the stack object (opcode 18).
    ///
    /// Ports FreeSO's `VMRemoveObjectInstance`. Target 0 is the caller, anything else the stack
    /// object; with "cleanup all" every part of a multi-tile object goes. Deletion waits for the
    /// end of the tick while entities run (see ``VM/delete(_:wholeGroup:)``). With no such object
    /// it does nothing. Either way it's true.
    public enum RemoveObjectInstance: Primitive {
        public static let name = "remove_object_instance"
        public static let opcode: UInt8 = 18

        public struct Operand: PrimitiveOperand, Equatable {
            /// 0 for the caller; anything else for the stack object.
            public var target: Int16
            /// Bit 0: return immediately (unused here, as in FreeSO); bit 1: delete every part.
            public var flags: UInt8

            public init(target: Int16, flags: UInt8 = 0) {
                self.target = target
                self.flags = flags
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                target = reader.int16()
                flags = reader.uint8()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.int16(target)
                    writer.uint8(flags)
                }
            }

            public var cleanupAll: Bool { flags & 2 != 0 }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            if let entity = operand.target == 0 ? frame.caller : frame.stackObject {
                try frame.vm.delete(entity, wholeGroup: operand.cleanupAll)
            }
            return .gotoTrue
        }
    }
}
