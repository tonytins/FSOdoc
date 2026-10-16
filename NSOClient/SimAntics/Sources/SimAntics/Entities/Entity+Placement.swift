import Foundation
import TSOFiles

extension Entity {
    private func data(_ variable: ObjectVariable) -> Int16 {
        objectData[Int(variable.rawValue)]
    }

    /// The rectangle the entity would take up at a position and facing, or `nil` if it takes up
    /// none (`VMGameObject.GetObstacle`): the definition's footprint mask, rotated a quarter turn
    /// per compass point, trims each side of a square half the tile width (8 by default) wide.
    public func obstacle(at position: LotPosition, facing direction: Direction) -> Obstacle? {
        guard data(.flags) & EntityFlag.hasZeroExtent == 0 else { return nil }
        let shift = direction.wallOffset * 4
        var mask = UInt32(object.definition.footprintMask) << shift
        mask = (mask >> 16) | (mask & 0xFFFF)
        var half = Int(object.definition.tileWidth) / 2
        if half == 0 { half = 8 }
        let x = Int(position.x), y = Int(position.y)
        return Obstacle(x + half - Int((mask >> 4) & 0xF), y + half - Int((mask >> 8) & 0xF),
                        x - half + Int((mask >> 12) & 0xF), y - half + Int(mask & 0xF))
    }

    /// Whether the entity may go to a position (`VMEntity.PositionValid`): on the lot, against the
    /// walls it needs and clear of those it can't have, on a floor it allows, and clear of other
    /// objects, unless `flags` allow overlapping. With `userBuildableLimit`, it must also be in the
    /// buildable area. The lot is flat, so slopes never fail.
    ///
    /// - Throws: any error an "allow intersection" entry point throws.
    public func placement(at position: LotPosition, facing direction: Direction,
                          flags: PlaceRequestFlags = []) throws(SimAnticsError) -> PlacementResult {
        guard !position.isOutOfWorld else { return PlacementResult() }
        let architecture = vm.architecture
        if (flags.contains(.userBuildableLimit) && architecture.isUserOutOfBounds(position)) || architecture.isOutOfBounds(position) {
            return PlacementResult(.locationOutOfBounds)
        }

        let wall = try architecture.wall(atX: Int(position.tileX), y: Int(position.tileY), level: Int(position.level))
        let wallStatus = wallChangeValid(wall, facing: direction, checkUnused: true)
        guard wallStatus == .success else { return PlacementResult(wallStatus) }
        let floorStatus = floorChangeValid(try architecture.preciseFloor(at: position), level: position.level)
        guard floorStatus == .success else { return PlacementResult(floorStatus) }

        if flags.contains(.allowIntersection) { return PlacementResult() }
        var result = try objectPlacement(at: position, facing: direction)
        if result.object != nil && !flags.contains(.acceptSlots) { result.status = .cantIntersectOtherObjects }
        return result
    }

    /// `FloorChangeValid`: water and pools need the flags that allow them, bare ground on the
    /// ground floor needs "on terrain", air above it needs "in air" (or a level offset), and floor
    /// needs "on floor".
    func floorChangeValid(_ floor: UInt16, level: Int8) -> PlacementError {
        let flags = PlacementFlags(rawValue: data(.placementFlags))
        let levelOffset = object.definition.levelOffset
        if floor == 65535 {
            if flags.isDisjoint(with: [.allowOnPool, .requirePool]) { return .cantPlaceOnWater }
        } else {
            if flags.contains(.requirePool) { return .mustPlaceOnPool }
            if floor == 65534 {
                if flags.isDisjoint(with: [.onWater, .requireWater]) { return .cantPlaceOnWater }
            } else {
                if flags.contains(.requireWater) { return .mustPlaceOnWater }
                if floor == 0 {
                    if level == 1 {
                        if !flags.contains(.onTerrain) { return .notAllowedOnTerrain }
                    } else if !flags.contains(.inAir) && levelOffset == 0 {
                        return .cantPlaceInAir
                    }
                } else if !flags.contains(.onFloor) && (levelOffset == 0 || !flags.contains(.inAir)) {
                    return .notAllowedOnFloor
                }
            }
        }
        return .success
    }

    /// `WallChangeValid`: the walls around the tile, turned to the facing, against the walls the
    /// object needs (low four bits of its wall flags) and can't have (bits 8 to 11).
    func wallChangeValid(_ wall: WallTile, facing direction: Direction, checkUnused: Bool) -> PlacementError {
        let flags = Int(data(.wallPlacementFlags))
        let diagonal = !wall.segments.isDisjoint(with: .anyDiagonal)
        if diagonal && flags & Int(WallPlacementFlags.diagonalAllowed.rawValue) == 0 { return .cantBeThroughWall }
        if !diagonal && flags & Int(WallPlacementFlags.diagonalRequired.rawValue) != 0 { return .mustBeOnDiagonal }

        let rotate = (direction.wallOffset + 1) % 4
        let walls = Self.rotate(Int(wall.segments.rawValue), by: rotate)
        let used = Self.rotate(Int(wall.occupiedWalls.rawValue), by: rotate)
        if flags & walls != flags & 15 { return .mustBeAgainstWall }
        if data(.exclusivePlacementFlags) & 2 != 0 && checkUnused && flags & used != 0 { return .mustBeAgainstUnusedWall }
        if flags & (walls << 8) != 0 { return .cantBeThroughWall }
        return .success
    }

    /// `RotateWallSegs`: turns the four side bits.
    static func rotate(_ sides: Int, by quarterTurns: Int) -> Int {
        ((sides << (4 - quarterTurns)) & 15) | ((sides & 15) >> quarterTurns)
    }

    /// `VMContext.GetObjPlace`: whether another object in the room is in the way. Each one that
    /// overlaps is asked through "allow intersection" (entry point 5), this object first; if
    /// neither allows it, it's in the way, unless this object can stack on its first slot.
    func objectPlacement(at position: LotPosition, facing direction: Direction) throws(SimAnticsError) -> PlacementResult {
        let allowedHeights = data(.allowedHeightFlags)
        let weight = data(.weight)
        let noFloor = allowedHeights & 1 == 0
        var result = PlacementResult(noFloor ? .heightNotAllowed : .success)
        guard let footprint = obstacle(at: position, facing: direction), position.level >= 1 else { return result }

        for other in vm.entities(inRoom: vm.architecture.room(at: position)) {
            if other.group === group || ignoreIntersection?.objects.contains(where: { $0 === other }) == true { continue }
            guard let otherFootprint = other.footprint, otherFootprint.intersects(footprint) else { continue }
            if try executeEntryPoint(.allowIntersection, runImmediately: true, stackObject: other,
                                     arguments: [other.objectID, 0, 0, 0]) { continue }
            if try other.executeEntryPoint(.allowIntersection, runImmediately: true, stackObject: self,
                                           arguments: [objectID, 0, 0, 0]) { continue }
            result = PlacementResult(.cantIntersectOtherObjects, object: other)
            // Something solid is here; maybe this object stacks on its first slot.
            guard allowedHeights > 1, other.totalSlots > 0, other.slot(0) == nil || other.slot(0) === self else {
                continue
            }
            if (1 << ((other.slotHeight(0) - 1) & 31)) & Int(allowedHeights) != 0 {
                if weight < other.objectData[Int(ObjectVariable.supportStrength.rawValue)] {
                    return PlacementResult(.success, object: other)
                }
                result.status = .cantSupportWeight
            } else if noFloor {
                if allowedHeights & (1 << 3) != 0 {
                    result.status = .counterHeight
                } else {
                    result.status = other.slotHeight(0) == 8 ? .cannotPlaceComputerOnEndTable : .heightNotAllowed
                }
            }
        }
        return result
    }

    /// `SetWallUse`: records which walls the object is against in object data 5 and, for exclusive
    /// wall placement, marks or clears them as occupied on its tile.
    func setWallUse(occupied: Bool, exclusive: Bool) throws(SimAnticsError) {
        let tileX = Int(position.tileX), tileY = Int(position.tileY), level = Int(position.level)
        var wall = try vm.architecture.wall(atX: tileX, y: tileY, level: level)
        let rotate = (8 - (direction.wallOffset + 1)) % 4
        // FreeSO takes the flags modulo 15, not masked with 15.
        let sides = UInt8(truncatingIfNeeded: Self.rotate(Int(data(.wallPlacementFlags)) % 15, by: rotate))
        guard sides != 0 else { return }

        let around = Self.rotate(Int(wall.segments.rawValue), by: (4 - rotate) % 4)
        var adjacency: Int16 = 0
        if around & Int(WallSegments.topLeft.rawValue) != 0 { adjacency |= 1 }      // wall on the left
        if around & Int(WallSegments.topRight.rawValue) != 0 { adjacency |= 4 }     // wall in front
        if around & Int(WallSegments.bottomRight.rawValue) != 0 { adjacency |= 2 }  // wall on the right
        if around & Int(WallSegments.bottomLeft.rawValue) != 0 { adjacency |= 8 }   // wall behind
        objectData[Int(ObjectVariable.wallAdjacencyFlags.rawValue)] = adjacency

        guard exclusive else { return }
        let segments = WallSegments(rawValue: Int32(sides))
        if occupied { wall.occupiedWalls.formUnion(segments) } else { wall.occupiedWalls.subtract(segments) }
        try vm.architecture.setWall(wall, atX: tileX, y: tileY, level: level)
    }

    /// `SetWallStyle` for a door or window: puts a style on the top-left (side 3) or top-right
    /// (side 0) wall of its tile; FreeSO leaves the other two sides alone. A door also marks the
    /// wall as having one. FreeSO first swaps a style from 22 to 255 for a generated one, which
    /// only drawing sees; this keeps the definition's value.
    func setWallStyle(side: Int, to value: UInt16) throws(SimAnticsError) {
        guard side == 0 || side == 3 else { return }
        let tileX = Int(position.tileX), tileY = Int(position.tileY), level = Int(position.level)
        var wall = try vm.architecture.wall(atX: tileX, y: tileY, level: level)
        let isDoor = data(.flagField2) & EntityFlag.architecturalDoor != 0
        if side == 0 {
            wall.objectTopRightStyle = value
            if isDoor { wall.topRightDoor = value != 0 }
        } else {
            wall.objectTopLeftStyle = value
            if isDoor { wall.topLeftDoor = value != 0 }
        }
        try vm.architecture.setWall(wall, atX: tileX, y: tileY, level: level)
    }

    /// Puts the definition's wall style (or 0) on each wall a door or window needs.
    func setArchitecturalWallStyles(to value: UInt16) throws(SimAnticsError) {
        guard data(.flagField2) & (EntityFlag.architecturalWindow | EntityFlag.architecturalDoor) != 0 else { return }
        let flags = WallPlacementFlags(rawValue: data(.wallPlacementFlags))
        let side = direction.wallOffset
        if flags.contains(.wallRequiredInFront) { try setWallStyle(side: side % 4, to: value) }
        if flags.contains(.wallRequiredOnRight) { try setWallStyle(side: (side + 1) % 4, to: value) }
        if flags.contains(.wallRequiredBehind) { try setWallStyle(side: (side + 2) % 4, to: value) }
        if flags.contains(.wallRequiredOnLeft) { try setWallStyle(side: (side + 3) % 4, to: value) }
    }

    /// `UpdateDynamicMultitile`: joins objects of the same kind within a tile into this one's group,
    /// then runs the dynamic multi-tile entry point with a bit for each neighbor's direction,
    /// relative to this object's facing.
    func updateDynamicMultitile() throws(SimAnticsError) {
        var neighbors: Int16 = 0
        for other in vm.entities where other !== self {
            let dx = Int16(truncatingIfNeeded: Int(other.position.x) - Int(position.x))
            let dy = Int16(truncatingIfNeeded: Int(other.position.y) - Int(position.y))
            guard other.object.guid == object.guid, abs(Int(dx >> 4)) < 2, abs(Int(dy >> 4)) < 2 else { continue }
            if other.group !== group {
                let joining = other.group.objects
                group.combine(other.group)
                for part in joining { try part.updateDynamicMultitile() }
            }
            let angle = Self.positiveModulo(Self.normalized(atan2(Double(Int(other.position.x) - Int(position.x)),
                                                                  Double(Int(position.y) - Int(other.position.y)))),
                                            Double.pi * 2)
            let octant = Int((angle / Double.pi * 4).rounded(.toNearestOrEven))
            let relative = Int(Self.positiveModulo(Double(octant - direction.wallOffset * 2), 8))
            neighbors |= Int16(truncatingIfNeeded: 1 << relative)
        }
        try executeEntryPoint(.dynamicMultiTileUpdate, runImmediately: true, arguments: [neighbors, 0, 0, 0])
    }

    /// `DirectionUtils.PosMod`.
    private static func positiveModulo(_ x: Double, _ m: Double) -> Double {
        (x.truncatingRemainder(dividingBy: m) + m).truncatingRemainder(dividingBy: m)
    }

    /// `DirectionUtils.Normalize`: an angle in (-pi, pi].
    private static func normalized(_ angle: Double) -> Double {
        let wrapped = positiveModulo(angle, Double.pi * 2)
        return wrapped > Double.pi ? wrapped - Double.pi * 2 : wrapped
    }
}
