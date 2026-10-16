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
    /// - parts of a multi-tile object, by ID, wrapping around to the lowest; false for an object
    ///   that isn't multi-tile;
    /// - objects on the pointer object's tile, wrapping around to the lowest ID;
    /// - objects next to the anchor object in a local: the first object on each neighboring tile,
    ///   north, east, south, then west, continuing after the side the pointer object is on.
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
                // The next part by ID after the target, wrapping to the lowest; false for an object
                // that isn't multi-tile (or doesn't exist).
                guard let pointer = vm.entity(id: target), pointer.group.isMultiTile else { return .gotoFalse }
                let ids = pointer.group.objects.map(\.objectID)
                guard let next = ids.filter({ $0 > target }).min() ?? ids.min() else { return .gotoFalse }
                try frame.setValue(next, of: operand.target)
                return .gotoTrue
            case .objectAdjacentToObjectInLocal:
                return try nextAdjacentObject(after: target, operand: operand, in: frame)
            case .career, .neighborID, .neighborOfType:
                throw .nullReference("TSO has no neighborhood or careers")
            case .objectOnSameTile:
                // Same tile wraps around to the lowest ID, so it always finds the pointer itself.
                guard let pointer = vm.entity(id: target) else { throw .nullReference("no object \(target)") }
                guard let onTile = vm.objects(at: pointer.position), let first = onTile.first else { return .gotoFalse }
                try frame.setValue((onTile.first { $0.objectID > target } ?? first).objectID, of: operand.target)
                return .gotoTrue
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

        /// The four neighboring tiles, north, east, south, then west.
        private static let neighborSteps: [(x: Int16, y: Int16)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]

        private static func nextAdjacentObject(after target: Int16, operand: Operand,
                                               in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            let vm = frame.vm
            guard Int(operand.local) < frame.locals.count else { throw .indexOutOfRange("local \(operand.local)") }
            let anchor = vm.entity(id: frame.locals[Int(operand.local)])
            var start = 0
            if let pointer = vm.entity(id: target) {
                guard let anchor else { throw .nullReference("no anchor object") }
                let side = side(of: pointer.position, from: anchor.position)
                if side == 3 { return .gotoFalse }
                start = side + 1
            }
            guard let anchor else { throw .nullReference("no anchor object") }
            for step in neighborSteps[start...] {
                let tile = LotPosition.center(ofTileX: anchor.position.tileX &+ step.x, y: anchor.position.tileY &+ step.y,
                                              level: anchor.position.level)
                if let first = vm.objects(at: tile)?.first {
                    try frame.setValue(first.objectID, of: operand.target)
                    return .gotoTrue
                }
            }
            return .gotoFalse
        }

        /// Which neighbor a position is, as 2017 judges it: 0 north, 1 east, 2 south, 3 west.
        private static func side(of position: LotPosition, from anchor: LotPosition) -> Int {
            let dx = Int(position.tileX) - Int(anchor.tileX), dy = Int(position.tileY) - Int(anchor.tileY)
            if dx == 0 { return dy < 0 ? 0 : 2 }
            return dx < 0 ? 3 : 1
        }
    }
}
