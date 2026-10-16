import Foundation
import Testing
import TSOFiles
@testable import SimAntics

/// Placement on an 8 by 8 lot: bare ground, floor at (2, 2), a pool at (3, 3), and a wall on
/// the top-right (north) edge of (5, 5).
@Suite struct PlacementTests {
    private let footprintMask = 75, tileWidth = 65, wallStyle = 44

    private func withLot(lampWords: [Int: UInt16] = [:], _ body: (VM, MultitileGroup) throws -> Void) throws {
        try withVM(chair: [
            objdChunk(label: "table", guid: tableGUID, words: [masterID: 5, subIndex: 0xFFFF], id: 129),
            objdChunk(label: "table left", guid: leftGUID, words: [masterID: 5, subIndex: 0x0000], id: 130),
            objdChunk(label: "table right", guid: rightGUID, words: [masterID: 5, subIndex: 0x0100], id: 131),
            objdChunk(label: "lamp", guid: lampGUID, words: lampWords, id: 133),
        ], objects: [tableGUID, leftGUID, rightGUID, lampGUID]) { vm, _ throws in
            var architecture = try Architecture(width: 8, height: 8)
            try architecture.setFloor(1, atX: 2, y: 2, level: 1)
            try architecture.setFloor(Architecture.poolPattern, atX: 3, y: 3, level: 1)
            try architecture.setWall(WallTile(segments: .topRight, topRightStyle: 1), atX: 5, y: 5, level: 1)
            architecture.regenerateRooms()
            vm.architecture = architecture
            try body(vm, try #require(try vm.createObject(guid: lampGUID)))
        }
    }

    private func set(_ entity: Entity, _ variable: ObjectVariable, _ value: Int16) {
        entity.objectData[Int(variable.rawValue)] = value
        // Objects set their allowed heights in init; floor height (bit 0) is what most allow.
        if variable == .placementFlags { entity.objectData[Int(ObjectVariable.allowedHeightFlags.rawValue)] = 1 }
    }

    private func tile(_ x: Int16, _ y: Int16, level: Int8 = 1) -> LotPosition { .center(ofTileX: x, y: y, level: level) }

    @Test func turnsTheFootprintMaskWithTheFacing() throws {
        try withLot(lampWords: [footprintMask: 0x1234]) { vm, lamp throws in
            let entity = lamp.objects[0]
            #expect(entity.obstacle(at: tile(4, 4), facing: .north) == Obstacle(65, 68, 77, 78))
            #expect(entity.obstacle(at: tile(4, 4), facing: .east) == Obstacle(66, 65, 76, 77))
            set(entity, .flags, 1 << 2) // no extent
            #expect(entity.obstacle(at: tile(4, 4), facing: .north) == nil)
        }
        try withLot(lampWords: [tileWidth: 32]) { _, lamp throws in
            #expect(lamp.objects[0].obstacle(at: tile(4, 4), facing: .north) == Obstacle(56, 56, 88, 88))
        }
    }

    @Test func checksTheFloor() throws {
        try withLot { vm, lamp throws in
            let entity = lamp.objects[0]
            #expect(try entity.placement(at: tile(1, 1), facing: .north).status == .notAllowedOnTerrain)
            set(entity, .placementFlags, PlacementFlags.onTerrain.rawValue)
            #expect(try entity.placement(at: tile(1, 1), facing: .north).status == .success)
            #expect(try entity.placement(at: tile(2, 2), facing: .north).status == .notAllowedOnFloor)
            #expect(try entity.placement(at: tile(3, 3), facing: .north).status == .cantPlaceOnWater)
            #expect(try entity.placement(at: tile(1, 1, level: 2), facing: .north).status == .cantPlaceInAir)
            #expect(try entity.placement(at: tile(8, 0), facing: .north).status == .locationOutOfBounds)
            #expect(try vm.place(lamp, at: tile(1, 1, level: 6), facing: .north).status == .notAllowedOnFloor)
            set(entity, .placementFlags, PlacementFlags.onFloor.rawValue)
            #expect(try entity.placement(at: tile(2, 2), facing: .north).status == .success)
            #expect(try entity.placement(at: .outOfWorld, facing: .north).status == .success)
            entity.objectData[Int(ObjectVariable.allowedHeightFlags.rawValue)] = 2  // only on a counter
            #expect(try entity.placement(at: tile(2, 2), facing: .north).status == .heightNotAllowed)
        }
    }

    @Test func checksTheWalls() throws {
        try withLot { vm, lamp throws in
            let entity = lamp.objects[0]
            set(entity, .placementFlags, PlacementFlags.onTerrain.rawValue)
            set(entity, .wallPlacementFlags, WallPlacementFlags.wallRequiredInFront.rawValue)
            #expect(try entity.placement(at: tile(5, 5), facing: .north).status == .success)
            #expect(try entity.placement(at: tile(5, 5), facing: .east).status == .mustBeAgainstWall)
            #expect(try entity.placement(at: tile(4, 4), facing: .north).status == .mustBeAgainstWall)
            set(entity, .wallPlacementFlags, WallPlacementFlags.wallNotAllowedInFront.rawValue)
            #expect(try entity.placement(at: tile(5, 5), facing: .north).status == .cantBeThroughWall)
            #expect(try entity.placement(at: tile(5, 5), facing: .south).status == .success)
            try vm.architecture.setWall(WallTile(segments: .verticalDiagonal), atX: 6, y: 6, level: 1)
            #expect(try entity.placement(at: tile(6, 6), facing: .north).status == .cantBeThroughWall)
            set(entity, .wallPlacementFlags, WallPlacementFlags.diagonalRequired.rawValue)
            #expect(try entity.placement(at: tile(4, 4), facing: .north).status == .mustBeOnDiagonal)
        }
    }

    @Test func objectsCantOverlapUnlessOneHasNoExtent() throws {
        try withLot { vm, first throws in
            let second = try #require(try vm.createObject(guid: lampGUID))
            for group in [first, second] { set(group.objects[0], .placementFlags, PlacementFlags.onTerrain.rawValue) }
            #expect(try vm.place(first, at: tile(4, 4), facing: .north).status == .success)
            #expect(first.objects[0].footprint == Obstacle(64, 64, 80, 80))
            #expect(vm.entities(inRoom: 1).contains { $0 === first.objects[0] })
            let blocked = try vm.place(second, at: tile(4, 4), facing: .north)
            #expect(blocked.status == .cantIntersectOtherObjects && blocked.object === first.objects[0])
            #expect(second.objects[0].position.isOutOfWorld)
            #expect(try vm.place(second, at: tile(4, 4), facing: .north, flags: .allowIntersection).status == .success)
            #expect(try vm.place(second, at: tile(5, 4), facing: .north).status == .success)  // touching edges don't overlap
        }
    }

    @Test func turnsAMultiTileObjectAndUndoesAFailedMove() throws {
        try withLot { vm, lamp throws in
            let table = try #require(try vm.createObject(guid: tableGUID))
            for part in table.objects + lamp.objects { set(part, .placementFlags, PlacementFlags.onTerrain.rawValue) }
            #expect(try vm.place(table, at: tile(1, 1), facing: .east).status == .success)
            #expect(table.objects.map(\.position) == [tile(1, 1), tile(1, 2)])     // the right part turns south
            #expect(table.objects.allSatisfy { $0.direction == .east })
            #expect(try vm.place(lamp, at: tile(3, 4), facing: .north).status == .success)
            // Facing south from (4, 4), the right part turns west onto the lamp: nothing moves.
            #expect(try vm.place(table, at: tile(4, 4), facing: .south).status == .cantIntersectOtherObjects)
            #expect(table.objects.map(\.position) == [tile(1, 1), tile(1, 2)])
            #expect(table.objects.allSatisfy { $0.footprint != nil && $0.direction == .east })
        }
    }

    @Test func marksTheWallsAnExclusiveObjectUses() throws {
        try withLot { vm, first throws in
            let second = try #require(try vm.createObject(guid: lampGUID))
            for group in [first, second] {
                set(group.objects[0], .placementFlags, PlacementFlags.onTerrain.rawValue)
                set(group.objects[0], .wallPlacementFlags, WallPlacementFlags.wallRequiredInFront.rawValue)
                set(group.objects[0], .exclusivePlacementFlags, 2)
            }
            #expect(try vm.place(first, at: tile(5, 5), facing: .north).status == .success)
            #expect(try vm.architecture.wall(atX: 5, y: 5, level: 1).occupiedWalls == .topRight)
            #expect(first.objects[0].objectData[Int(ObjectVariable.wallAdjacencyFlags.rawValue)] == 1)
            #expect(try second.objects[0].placement(at: tile(5, 5), facing: .north, flags: .allowIntersection).status
                    == .mustBeAgainstUnusedWall)
            try vm.move(first.objects[0], to: .outOfWorld)
            #expect(try vm.architecture.wall(atX: 5, y: 5, level: 1).occupiedWalls.isEmpty)
        }
    }

    @Test func putsAWindowsStyleOnItsWall() throws {
        try withLot(lampWords: [wallStyle: 7]) { vm, lamp throws in
            let window = lamp.objects[0]
            set(window, .placementFlags, PlacementFlags.onTerrain.rawValue)
            set(window, .wallPlacementFlags, WallPlacementFlags.wallRequiredInFront.rawValue)
            set(window, .flagField2, 1 << 14)
            #expect(try vm.place(lamp, at: tile(5, 5), facing: .north).status == .success)
            #expect(try vm.architecture.wall(atX: 5, y: 5, level: 1).objectTopRightStyle == 7)
            #expect(vm.architecture.isDirty)                         // rooms follow on the next tick
            try vm.move(window, to: .outOfWorld)
            #expect(try vm.architecture.wall(atX: 5, y: 5, level: 1).objectTopRightStyle == 0)
        }
    }

    @Test func recomputesTheFootprintWithTheOldFlags() throws {
        try withLot { vm, lamp throws in
            let entity = lamp.objects[0]
            set(entity, .placementFlags, PlacementFlags.onTerrain.rawValue)
            try vm.place(lamp, at: tile(4, 4), facing: .north)
            let flags = entity.objectData[Int(ObjectVariable.flags.rawValue)]
            _ = try entity.setValue(flags | 1 << 2, of: ObjectVariable.flags.rawValue)
            #expect(entity.footprint != nil)                         // FreeSO saw the flags before the change
            _ = try entity.setValue(flags, of: ObjectVariable.flags.rawValue)
            #expect(entity.footprint == nil)
        }
    }
}
