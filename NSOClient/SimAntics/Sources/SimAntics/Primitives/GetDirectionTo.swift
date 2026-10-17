import Foundation

extension Primitives {
    /// The direction from one object to the stack object, in eighths of a turn (opcode 12).
    ///
    /// Ports FreeSO's `VMGetDirectionTo`. The object is read from a variable; FreeSO's operand
    /// reader makes it the caller's ID (`MyObject` 11) when flag 1 is clear, so the caller is never
    /// used directly. The angle is FreeSO's: `atan2(dx, -dy)` between the two positions, normalized
    /// and taken modulo a full turn, then rounded half to even into 0 to 8 (8 is a hair under a
    /// full turn). A missing stack object or object fails, as FreeSO's null reference does.
    public enum GetDirectionTo: Primitive {
        public static let name = "get_direction_to"
        public static let opcode: UInt8 = 12

        public struct Operand: PrimitiveOperand, Equatable {
            /// Where the result goes; its scope is stored in two bytes.
            public var result: Variable
            /// As stored. Bit 0 set: the object comes from `object`; clear: it's the caller.
            public var flags: UInt8
            /// The variable holding the object's ID, as stored; its scope is one byte.
            public var object: Variable

            public init(result: Variable, flags: UInt8, object: Variable) {
                self.result = result
                self.flags = flags
                self.object = object
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                let resultData = reader.int16()
                result = Variable(rawScope: reader.uint16(), data: resultData)
                flags = reader.uint8()
                let scope = reader.uint8()
                object = Variable(rawScope: UInt16(scope), data: reader.int16())
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.int16(result.data)
                    writer.uint16(result.rawScope)
                    writer.uint8(flags)
                    writer.uint8(UInt8(truncatingIfNeeded: object.rawScope))
                    writer.int16(object.data)
                }
            }

            /// The object as FreeSO's reader leaves it: the caller's ID when flag 1 is clear.
            var effectiveObject: Variable {
                flags & 1 == 0 ? Variable(.myObject, Int16(ObjectVariable.objectID.rawValue)) : object
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            guard let to = frame.stackObject else { throw .nullReference("Get Direction To with no stack object") }
            let id = try frame.value(of: operand.effectiveObject)
            guard let from = frame.vm.entity(id: id) else { throw .nullReference("Get Direction To: no object \(id)") }
            let fullTurn = Double.pi * 2
            let angle = normalized(atan2(Double(to.position.x) - Double(from.position.x),
                                         Double(from.position.y) - Double(to.position.y)))
            let eighths = (positiveModulo(angle, fullTurn) / Double.pi * 4).rounded(.toNearestOrEven)
            _ = try frame.setValue(Int16(eighths), of: operand.result)
            return .gotoTrue
        }

        /// `DirectionUtils.PosMod`: C#'s `%` on doubles truncates, like `truncatingRemainder`.
        static func positiveModulo(_ x: Double, _ m: Double) -> Double {
            (x.truncatingRemainder(dividingBy: m) + m).truncatingRemainder(dividingBy: m)
        }

        /// `DirectionUtils.Normalize`: into -π through π.
        static func normalized(_ direction: Double) -> Double {
            let value = positiveModulo(direction, Double.pi * 2)
            return value > Double.pi ? value - Double.pi * 2 : value
        }
    }
}
