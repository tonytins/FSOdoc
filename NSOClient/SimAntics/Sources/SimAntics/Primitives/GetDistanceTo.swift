import Foundation

extension Primitives {
    /// The distance from the stack object to another object, in whole tiles, into a temp (opcode 11).
    ///
    /// Ports FreeSO's `VMGetDistanceTo`. The object is read from a variable; FreeSO's operand reader
    /// makes it the caller's ID (`MyObject` 11) when flag 1 is clear, so the caller is never used
    /// directly. The distance is the straight line between the two positions, ignoring levels, in
    /// sixteenths of a tile, divided by 16 and rounded down. A missing stack object or object, or a
    /// temp past the last, fails, as FreeSO's null reference and index do.
    public enum GetDistanceTo: Primitive {
        public static let name = "get_distance_to"
        public static let opcode: UInt8 = 11

        public struct Operand: PrimitiveOperand, Equatable {
            /// The temp the result goes in.
            public var temp: UInt16
            /// As stored. Bit 0 set: the object comes from `object`; clear: it's the caller.
            public var flags: UInt8
            /// The variable holding the object's ID, as stored; its scope is one byte.
            public var object: Variable

            public init(temp: UInt16, flags: UInt8, object: Variable) {
                self.temp = temp
                self.flags = flags
                self.object = object
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                temp = reader.uint16()
                flags = reader.uint8()
                let scope = reader.uint8()
                object = Variable(rawScope: UInt16(scope), data: reader.int16())
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint16(temp)
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
            guard let from = frame.stackObject else { throw .nullReference("Get Distance To with no stack object") }
            let id = try frame.value(of: operand.effectiveObject)
            guard let to = frame.vm.entity(id: id) else { throw .nullReference("Get Distance To: no object \(id)") }
            let dx = Double(from.position.x) - Double(to.position.x), dy = Double(from.position.y) - Double(to.position.y)
            let tiles = (sqrt(dx * dx + dy * dy) / 16).rounded(.down)
            guard Int(operand.temp) < frame.thread.tempRegisters.count else { throw .indexOutOfRange("temp \(operand.temp)") }
            frame.thread.tempRegisters[Int(operand.temp)] = Int16(tiles)
            return .gotoTrue
        }
    }
}
