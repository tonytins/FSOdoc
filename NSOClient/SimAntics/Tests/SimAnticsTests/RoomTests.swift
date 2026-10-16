import Foundation
import Testing
import TSOContent
@testable import SimAntics

/// The owner's lots, in `NSOClient/Lots`.
let ownerLotsDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("../../../Lots").standardizedFileURL

/// Compares room generation with `fso-oracle room-maps` over FreeSO's empty lot, the owner's lots,
/// and the synthetic blueprints from `OracleCases/make_blueprints.py`.
@Suite(.enabled(if: oracleDirectory != nil, "TSO_ORACLE_DIR is not set"))
struct OracleRoomMapTests {
    @Test func matchesFreeSO() throws {
        let directory = try required(oracleDirectory)
        var matched = 0, mismatches: [String] = []
        for response in try jsonLines(directory.appendingPathComponent("rooms.jsonl")) {
            let file = try required(response["file"] as? String)
            guard response["error"] == nil else { continue }
            let candidates = [directory.appendingPathComponent("blueprints/\(file)"),
                              freeSOContentDirectory.appendingPathComponent("Blueprints/\(file)"),
                              ownerLotsDirectory.appendingPathComponent(file)]
            let url = try required(candidates.first { FileManager.default.fileExists(atPath: $0.path) }, "blueprint \(file)")
            let architecture = try Blueprint(xml: try Data(contentsOf: url)).architecture()

            var actual: [String: Any] = ["size": [architecture.width, architecture.height]]
            actual["maps"] = architecture.roomMaps.map { $0.map.map(Int.init) }
            actual["rooms"] = architecture.rooms.dropFirst().map { room -> [Any] in
                [Int(room.id), Int(room.lightBaseRoom), Int(room.level) - 1, room.isOutside, Int(room.area), room.isPool,
                 room.adjacentRooms.map(Int.init),
                 [room.bounds.x, room.bounds.y, room.bounds.width, room.bounds.height],
                 room.supportRooms.map(Int.init)]
            }
            let expected = response.filter { ["size", "maps", "rooms"].contains($0.key) }
            if canonical(actual) == canonical(expected) {
                matched += 1
            } else {
                mismatches.append("\(file): \(firstDifference(expected, actual))")
            }
        }
        print("Room maps against FreeSO: \(matched) matched, \(mismatches.count) mismatched")
        #expect(matched > 1)
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches, first: \(mismatches.prefix(5).joined(separator: "\n"))")
    }

    private func firstDifference(_ expected: [String: Any], _ actual: [String: Any]) -> String {
        for key in ["size", "rooms", "maps"] {
            let lhs = (expected[key] as? [Any]) ?? [], rhs = (actual[key] as? [Any]) ?? []
            for (index, pair) in zip(lhs, rhs).enumerated() where canonical(["v": pair.0]) != canonical(["v": pair.1]) {
                return "\(key)[\(index)]: FreeSO \(canonical(["v": pair.0]).prefix(300)) Swift \(canonical(["v": pair.1]).prefix(300))"
            }
            if lhs.count != rhs.count { return "\(key): FreeSO has \(lhs.count), Swift \(rhs.count)" }
        }
        return "?"
    }
}

/// Hand-built lots, checked against what FreeSO's fill does.
struct RoomTests {
    /// Walls around a rectangle of tiles, as blueprints store them.
    private func box(_ architecture: inout Architecture, x: Range<Int>, y: Range<Int>, style: UInt16 = 1,
                     level: Int = 1) throws {
        func add(_ segments: WallSegments, _ tileX: Int, _ tileY: Int) throws {
            var tile = try architecture.wall(atX: tileX, y: tileY, level: level)
            tile.segments.formUnion(segments)
            if segments.contains(.topLeft) { tile.topLeftStyle = style }
            if segments.contains(.topRight) { tile.topRightStyle = style }
            try architecture.setWall(tile, atX: tileX, y: tileY, level: level)
        }
        for row in y {
            try add(.topLeft, x.lowerBound, row)
            try add(.topLeft, x.upperBound, row)
        }
        for column in x {
            try add(.topRight, column, y.lowerBound)
            try add(.topRight, column, y.upperBound)
        }
    }

    @Test func anEmptyLotIsOneOutdoorRoomPerLevel() throws {
        let architecture = try Architecture(width: 8, height: 8)
        #expect(architecture.rooms.count == 1 + Architecture.stories)
        for (index, room) in architecture.rooms.dropFirst().enumerated() {
            #expect(room.id == UInt16(index + 1) && room.level == Int8(index + 1))
            #expect(room.isOutside && room.area == 64 && !room.isPool)
            #expect(room.bounds == TileRect(x: 0, y: 0, width: 8, height: 8))
        }
        #expect(architecture.room(at: .center(ofTileX: 3, y: 3, level: 2)) == 2)
    }

    @Test func wallsMakeAnIndoorRoom() throws {
        var architecture = try Architecture(width: 8, height: 8)
        try box(&architecture, x: 2..<5, y: 3..<5)
        #expect(architecture.isDirty)
        architecture.regenerateRooms()
        #expect(!architecture.isDirty)
        let inside = architecture.room(at: .center(ofTileX: 2, y: 3, level: 1))
        let room = architecture.rooms[Int(inside)]
        #expect(inside == 2 && !room.isOutside && room.area == 6)
        #expect(room.bounds == TileRect(x: 2, y: 3, width: 3, height: 2))
        #expect(room.lightBaseRoom == inside && room.adjacentRooms.isEmpty)
        #expect(architecture.room(at: .center(ofTileX: 5, y: 3, level: 1)) == 1)
    }

    @Test func aFenceJoinsLightAndTheOutdoors() throws {
        var architecture = try Architecture(width: 8, height: 8)
        try box(&architecture, x: 2..<5, y: 3..<5, style: 2)
        architecture.regenerateRooms()
        let inside = architecture.rooms[2]
        // A fence doesn't stop the fill from noting the room beyond, so the inside is outdoors.
        #expect(inside.isOutside && inside.adjacentRooms == [1] && inside.lightBaseRoom == 1)
        #expect(architecture.rooms[1].supportRooms == [1, 2])
    }

    @Test func diagonalsSplitTiles() throws {
        var architecture = try Architecture(width: 4, height: 4)
        try architecture.setWall(WallTile(segments: .verticalDiagonal, topLeftPattern: 0, topLeftStyle: 0),
                                 atX: 1, y: 1, level: 1)
        try architecture.setWall(WallTile(segments: .horizontalDiagonal), atX: 2, y: 2, level: 1)
        architecture.regenerateRooms()
        // On the ground floor the halves of each diagonal join the rooms around them, which
        // the fill wraps into one; the map still records the split.
        let vertical = architecture.roomMaps[0].map[1 + 1 * 4], horizontal = architecture.roomMaps[0].map[2 + 2 * 4]
        #expect(vertical & 0x8000_0000 == 0 && horizontal & 0x8000_0000 != 0)
        #expect(architecture.room(at: LotPosition(x: 16 + 12, y: 16 + 2, level: 1)) == UInt16(vertical & 0xFFFF))
        #expect(architecture.room(at: LotPosition(x: 16 + 2, y: 16 + 12, level: 1)) == UInt16((vertical >> 16) & 0x7FFF))
        #expect(architecture.room(at: LotPosition(x: 32 + 2, y: 32 + 2, level: 1)) == UInt16(horizontal & 0xFFFF))
        #expect(architecture.room(at: LotPosition(x: 32 + 12, y: 32 + 12, level: 1)) == UInt16((horizontal >> 16) & 0x7FFF))
    }

    @Test func poolsAreTheirOwnRooms() throws {
        var architecture = try Architecture(width: 6, height: 6)
        try architecture.setFloor(Architecture.poolPattern, atX: 2, y: 2, level: 1)
        try architecture.setFloor(Architecture.poolPattern, atX: 3, y: 2, level: 1)
        architecture.regenerateRooms()
        let pool = architecture.rooms[Int(architecture.room(at: .center(ofTileX: 3, y: 2, level: 1)))]
        #expect(pool.isPool && pool.area == 2 && pool.isOutside && pool.adjacentRooms == [1])
    }

    @Test func positionsOffTheLotAreRoomZero() throws {
        let architecture = try Architecture(width: 4, height: 4)
        #expect(architecture.room(at: .outOfWorld) == 0)
        #expect(architecture.room(at: .center(ofTileX: 4, y: 0, level: 1)) == 0)
        #expect(architecture.room(at: .center(ofTileX: 0, y: 0, level: 6)) == 0)
        #expect(throws: SimAnticsError.self) { try Architecture(width: 0, height: 4) }
        var mutable = architecture
        #expect(throws: SimAnticsError.self) { try mutable.setFloor(1, atX: 4, y: 0, level: 1) }
        #expect(throws: SimAnticsError.self) { try mutable.setWall(.empty, atX: 0, y: 0, level: 6) }
    }

    @Test func blueprintsLoadFloorsPoolsAndWalls() throws {
        let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <house><size>6</size><category>3</category><world>
              <floors><floor level="0" x="1" y="1" value="70001" /><floor level="1" x="2" y="2" value="9" /></floors>
              <walls><wall level="0" x="3" y="3" segments="3" tls="1" trs="2" tlp="5" /></walls>
              <pools><pool x="4" y="4" value="0" /></pools>
            </world><objects /></house>
            """
        let blueprint = try Blueprint(xml: Data(xml.utf8))
        #expect(blueprint.size == 6 && blueprint.category == 3)
        let architecture = try blueprint.architecture()
        #expect(try architecture.floor(atX: 1, y: 1, level: 1) == 4465) // truncated, as (ushort) does
        #expect(try architecture.floor(atX: 2, y: 2, level: 2) == 9)
        #expect(try architecture.floor(atX: 4, y: 4, level: 1) == Architecture.poolPattern)
        #expect(try architecture.wall(atX: 3, y: 3, level: 1)
                == WallTile(segments: [.topLeft, .topRight], topLeftPattern: 5, topLeftStyle: 1, topRightStyle: 2))
        #expect(!architecture.isDirty)

        #expect(throws: BlueprintError.self) { try Blueprint(xml: Data("<house>".utf8)) }
        #expect(throws: BlueprintError.self) { try Blueprint(xml: Data("<house><world/></house>".utf8)) }
        #expect(throws: BlueprintError.self) { try Blueprint(xml: Data("<house><size>x</size></house>".utf8)) }
        let offLot = try Blueprint(xml: Data("<house><size>4</size><world><pools><pool x=\"4\" y=\"0\"/></pools></world></house>".utf8))
        #expect(throws: BlueprintError.self) { try offLot.architecture() }
    }
}

@Suite struct EntityRoomTests {
    @Test func movingAnEntityRecordsItsRoom() throws {
        try withVM { vm, chair throws in
            var architecture = try Architecture(width: 8, height: 8)
            try architecture.setFloor(Architecture.poolPattern, atX: 2, y: 2, level: 1)
            architecture.regenerateRooms()
            vm.architecture = architecture
            let room = Int(ObjectVariable.room.rawValue)
            try vm.move(chair, to: .center(ofTileX: 2, y: 2, level: 1))
            #expect(chair.objectData[room] == 2)
            try vm.move(chair, to: .center(ofTileX: 2, y: 2, level: 2))
            #expect(chair.objectData[room] == 3) // the ground floor has rooms 1 and 2
            try vm.move(chair, to: .outOfWorld)
            #expect(chair.objectData[room] == 0)
        }
    }

    @Test func changesTakeEffectOnTheNextTick() throws {
        try withVM { vm, chair throws in
            try vm.move(chair, to: .center(ofTileX: 2, y: 2, level: 1))
            let room = Int(ObjectVariable.room.rawValue)
            #expect(chair.objectData[room] == 1)
            try vm.architecture.setFloor(Architecture.poolPattern, atX: 2, y: 2, level: 1)
            // Until the tick, lookups use the rooms from before the change.
            #expect(vm.architecture.isDirty && vm.architecture.room(at: chair.position) == 1)
            vm.tick()
            #expect(!vm.architecture.isDirty && chair.objectData[room] == 2)
        }
    }

    @Test func loadingABlueprintPutsEntitiesInRooms() throws {
        try withVM { vm, chair throws in
            try vm.move(chair, to: .center(ofTileX: 1, y: 1, level: 1))
            let xml = "<house><size>4</size><world><pools><pool x=\"1\" y=\"1\"/></pools></world></house>"
            try vm.load(try Blueprint(xml: Data(xml.utf8)))
            #expect(vm.lotSize.width == 4 && vm.lotSize.height == 4)
            #expect(chair.objectData[Int(ObjectVariable.room.rawValue)] == 2)
        }
    }
}
