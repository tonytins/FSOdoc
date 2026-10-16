extension Primitives {
    /// Tests whether an object is of a type (opcode 32).
    ///
    /// Ports FreeSO's `VMTestObjectType`. The object ID comes from a variable. It's true when
    /// the object's GUID, or its multi-tile lead's, is the operand's GUID, false otherwise, and
    /// an error exit (not an exception) when there's no object with that ID.
    public enum TestObjectType: Primitive {
        public static let name = "test_object_type"
        public static let opcode: UInt8 = 32

        public struct Operand: PrimitiveOperand, Equatable {
            public var guid: UInt32
            /// The variable holding the object ID; its scope is stored in one byte.
            public var objectID: Variable

            public init(guid: UInt32, objectID: Variable) {
                self.guid = guid
                self.objectID = objectID
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                guid = reader.uint32()
                let data = reader.int16()
                objectID = Variable(rawScope: UInt16(reader.uint8()), data: data)
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint32(guid)
                    writer.int16(objectID.data)
                    writer.uint8(UInt8(truncatingIfNeeded: objectID.rawScope))
                }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            guard let entity = frame.vm.entity(id: try frame.value(of: operand.objectID)) else { return .error }
            if entity.object.guid == operand.guid || entity.masterDefinition?.guid == operand.guid {
                return .gotoTrue
            }
            return .gotoFalse
        }
    }
}
