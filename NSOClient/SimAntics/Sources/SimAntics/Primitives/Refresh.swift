extension Primitives {
    /// Refreshes an object's graphic, its room's lighting, or its room's score (opcode 7).
    ///
    /// Ports FreeSO's `VMRefresh`. The target is the caller (0) or the stack object (1); any
    /// other target is none. A graphic refresh (type 0) only redraws, so headless it does
    /// nothing. Lighting (1) and room score (2) look up the target's room, which fails with no
    /// target, as in 2017. An object out of the world is in room 0, which has nothing to
    /// refresh. Every entity is out of the world until the lot model is ported, so for now
    /// those refreshes change nothing; with rooms, they'll recompute the room's light and score.
    /// Other types do nothing. Always true.
    public enum Refresh: Primitive {
        public static let name = "refresh"
        public static let opcode: UInt8 = 7

        public struct Operand: PrimitiveOperand, Equatable {
            /// 0 for the caller, 1 for the stack object.
            public var target: Int16
            /// 0 graphic, 1 lighting, 2 room score.
            public var type: Int16

            public init(target: Int16, type: Int16) {
                self.target = target
                self.type = type
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                target = reader.int16()
                type = reader.int16()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.int16(target)
                    writer.int16(type)
                }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let target: Entity? = switch operand.target {
            case 0: frame.caller
            case 1: frame.stackObject
            default: nil
            }
            if operand.type == 1 || operand.type == 2 {
                guard target != nil else { throw .nullReference("no object to find the room of") }
                // Out of the world: room 0, nothing to refresh (see the type's documentation).
            }
            return .gotoTrue
        }
    }
}
