import TSOFiles

/// The entities that make up one object (FreeSO's `VMMultitileGroup`).
///
/// Most objects are a group of one. A multi-tile object, such as a two-tile bed or a counter run,
/// is one entity per part, each with its own definition (`OBJD`) and object ID, created together
/// from the master definition and moved, initialized, and deleted together. Each part's offset from
/// the group's position comes from its definition's sub-index and level offset.
///
/// Catalog prices aren't ported yet, so ``price`` stays 0.
public final class MultitileGroup {
    /// Whether the group was created from a multi-tile master definition.
    public let isMultiTile: Bool
    /// The parts, in the order they were added: for a multi-tile object, the order of their
    /// definitions in the master's file.
    public private(set) var objects: [Entity] = []
    /// Each part's offset from the group's position, in sixteenths of a tile, and levels.
    public private(set) var offsets: [LotPosition] = []
    public var name = ""
    /// The price paid, after initial depreciation (`Price`).
    public var price: Int32 = 0
    /// The price the owner set for sale, or -1 when it's not for sale (`SalePrice`).
    public var salePrice: Int32 = -1

    init(isMultiTile: Bool) {
        self.isMultiTile = isMultiTile
    }

    /// Adds a part at the offset its definition gives (`AddObject`): the high byte of the
    /// sub-index is the x tile, the low byte the y tile, each signed, and the level offset the level.
    func add(_ entity: Entity) {
        let subIndex = UInt16(bitPattern: entity.object.definition.subIndex)
        let offset = LotPosition(x: Int16(Int8(truncatingIfNeeded: subIndex >> 8)) * 16,
                                 y: Int16(Int8(truncatingIfNeeded: subIndex)) * 16,
                                 level: Int8(truncatingIfNeeded: entity.object.definition.levelOffset))
        objects.append(entity)
        offsets.append(offset)
    }

    /// The part that leads the group (`BaseObject`): the first whose definition says it leads,
    /// else the first at offset zero, else the first part; `nil` for an empty group.
    public var leadObject: Entity? {
        if let lead = objects.first(where: { $0.object.definition.myLeadObject > 0 }) { return lead }
        let origin = LotPosition(x: 0, y: 0, level: 0)
        if let index = offsets.firstIndex(of: origin) { return objects[index] }
        return objects.first
    }

    /// Adds another group's parts to this one, at their offsets from the lead and facing its way
    /// (`Combine`, for dynamic multi-tile objects). FreeSO computes a rotation for the offsets and
    /// then discards it, so they aren't rotated. The other group keeps its list.
    func combine(_ other: MultitileGroup) {
        guard let lead = leadObject else { return }
        for part in other.objects {
            let offset = LotPosition(x: Int16(truncatingIfNeeded: Int(part.position.x) - Int(lead.position.x)),
                                     y: Int16(truncatingIfNeeded: Int(part.position.y) - Int(lead.position.y)),
                                     level: Int8(truncatingIfNeeded: Int(part.position.level) - Int(lead.position.level)))
            objects.append(part)
            offsets.append(offset)
            part.group = self
            part.direction = lead.direction
        }
    }

    /// Takes a deleted part out of the group (`RemoveObject`).
    func remove(_ entity: Entity) {
        guard let index = objects.firstIndex(where: { $0 === entity }) else { return }
        objects.remove(at: index)
        offsets.remove(at: index)
    }

    /// Breaks the group's references to its parts, which refer back to it.
    func removeAll() {
        objects.removeAll()
        offsets.removeAll()
    }
}
