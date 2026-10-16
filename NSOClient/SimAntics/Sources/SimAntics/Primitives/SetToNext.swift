extension Primitives {
    /// Finds the next object after an ID that fits a search (opcode 31).
    ///
    /// Ports FreeSO's `VMSetToNext`. The search starts after the object ID in the target
    /// variable and writes the first match back; it's false when nothing is left. Searches:
    ///
    /// - every object, non-Sims, objects of a GUID, and objects in the category held in
    ///   parameter 0, in object ID order;
    /// - Sims and family members, which only look at Sims (none are ported yet, so false);
    /// - "closest house", which is always false in 2017;
    /// - The Sims 1 neighbors and careers, which fail in TSO as 2017 has no neighborhood;
    /// - parts of a multi-tile object, which is false for an object alone in its group (every
    ///   entity, until multi-tile groups are ported);
    /// - objects on the same tile and objects next to one, which need positions (unsupported,
    ///   except where 2017 fails first).
    ///
    /// When the operand's top flag bit is clear, 2017 ignores the stored target and uses the
    /// stack object ID; the operand keeps the stored bytes so it encodes back unchanged.
    public enum SetToNext: Primitive {
        public static let name = "set_to_next"
        public static let opcode: UInt8 = 31

        /// `VMSetToNextSearchType`.
        public enum Search: UInt8, Sendable {
            case object = 0, person, nonPerson, partOfMultiTileObject, objectOfType, neighborID
            case objectWithCategoryInParameter0, neighborOfType, objectOnSameTile, objectAdjacentToObjectInLocal
            case career, closestHouse, familyMember
        }

        public struct Operand: PrimitiveOperand, Equatable {
            public var guid: UInt32
            /// The search type in the low 7 bits; the top bit says the target fields are used.
            public var flags: UInt8
            public var storedTargetScope: UInt8
            public var local: UInt8
            public var storedTargetData: UInt8

            public init(bytes: [UInt8]) {
                var reader = OperandReader(bytes)
                guid = reader.uint32()
                flags = reader.uint8()
                storedTargetScope = reader.uint8()
                local = reader.uint8()
                storedTargetData = reader.uint8()
            }

            public init(guid: UInt32 = 0, search: UInt8, targetScope: UInt8, targetData: UInt8, local: UInt8 = 0) {
                self.guid = guid
                flags = 0x80 | (search & 0x7F)
                storedTargetScope = targetScope
                self.local = local
                storedTargetData = targetData
            }

            public func encoded() -> [UInt8] {
                OperandWriter.bytes { writer in
                    writer.uint32(guid)
                    writer.uint8(flags)
                    writer.uint8(storedTargetScope)
                    writer.uint8(local)
                    writer.uint8(storedTargetData)
                }
            }

            public var rawSearch: UInt8 { flags & 0x7F }
            /// The variable searched from and written; without the top flag bit, the stack object ID.
            public var target: Variable {
                flags & 0x80 == 0 ? Variable(.stackObjectID, 0) : Variable(rawScope: UInt16(storedTargetScope), data: Int16(storedTargetData))
            }
        }

        public static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let vm = frame.vm
            let target = try frame.value(of: operand.target)

            let candidates: [Entity]?
            switch Search(rawValue: operand.rawSearch) {
            case .partOfMultiTileObject:
                // Only objects created through their group's lead are in a multi-tile group; every
                // other object is a group of one, which 2017 answers with false. Groups aren't
                // ported yet, so every entity is a group of one.
                return .gotoFalse
            case .objectAdjacentToObjectInLocal:
                throw .unsupported("finding adjacent objects needs positions")
            case .career, .neighborID, .neighborOfType:
                throw .nullReference("TSO has no neighborhood or careers")
            case .objectOnSameTile:
                guard vm.entity(id: target) != nil else { throw .nullReference("no object \(target)") }
                throw .unsupported("finding objects on a tile needs positions")
            case .person, .familyMember:
                candidates = [] // Sims aren't ported, so there are none
            case .objectOfType:
                candidates = vm.objects(withGUID: operand.guid)
            case .objectWithCategoryInParameter0:
                guard let category = frame.arguments.first else { throw .indexOutOfRange("parameter 0") }
                candidates = vm.objects(inCategory: category)
            case .closestHouse:
                // 2017 gives up at the first object after the target, and false if there's none.
                return .gotoFalse
            case .object, .nonPerson, nil:
                candidates = vm.entities
            }
            guard let candidates else { return .gotoFalse }
            guard let next = candidates.first(where: { $0.objectID > target }) else { return .gotoFalse }
            try frame.setValue(next.objectID, of: operand.target)
            return .gotoTrue
        }
    }
}
