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
            /// The variable holding the object ID.
            public var idData: Int16
            public var idScope: UInt8

            public init(guid: UInt32, idScope: UInt8, idData: Int16) {
                self.guid = guid
                self.idScope = idScope
                self.idData = idData
            }

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                guid = reader.uint32()
                idData = reader.int16()
                idScope = reader.uint8()
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint32(guid)
                    writer.int16(idData)
                    writer.uint8(idScope)
                }
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let objectID = try VMMemory.value(scope: operand.idScope, data: operand.idData, in: frame)
            guard let entity = frame.vm.entity(id: objectID) else { return .error }
            if entity.object.guid == operand.guid || entity.masterDefinition?.guid == operand.guid {
                return .gotoTrue
            }
            return .gotoFalse
        }
    }
}
