/// A rectangle of tiles.
public struct TileRect: Sendable, Hashable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// One room: a region of floor bounded by walls, a change of floor, or water (FreeSO's `VMRoom`).
///
/// Routing obstacles and lighting's wall lines aren't ported yet.
public struct Room: Sendable, Hashable {
    public var id: UInt16
    /// The room whose light this room shares: the lowest-numbered room it's joined to through
    /// rooms that aren't separated by walls.
    public var lightBaseRoom: UInt16
    /// 1 is the ground floor.
    public var level: Int8
    public var isOutside: Bool
    /// Tiles and half tiles, each counted once.
    public var area: UInt16
    public var isPool: Bool
    /// Rooms next to this one that a fence, floor change, or water separates rather than a
    /// wall, in the order they were found.
    public var adjacentRooms: [UInt16]
    public var bounds: TileRect
    /// For a light base room, the rooms that share its light.
    public var supportRooms: [UInt16]

    /// Room 0, which FreeSO keeps as an unused first entry.
    static let placeholder = Room(id: 0, lightBaseRoom: 0, level: 0, isOutside: false, area: 0, isPool: false,
                                  adjacentRooms: [], bounds: TileRect(x: 0, y: 0, width: 0, height: 0),
                                  supportRooms: [])
}

/// Which room each tile of one level is in (FreeSO's `VMRoomMap`).
///
/// Each entry packs two room IDs, one per side of a diagonal wall: the low 16 bits, then
/// bits 16 to 30. Bit 31 marks a tile split by a horizontal diagonal. A tile without a
/// diagonal has the same room in both halves.
public struct RoomMap: Sendable {
    public let width: Int
    public let height: Int
    public private(set) var map: [UInt32]

    /// Generates a level's rooms with FreeSO's flood fill (`GenerateMap`), appending them to `rooms`.
    ///
    /// Tiles are taken across then down; each one not yet in a room starts a new room, which
    /// spreads to its neighbors until walls, a change of floor, or water stop it. The fill wraps
    /// around the lot's edges, as FreeSO's does. The first room on each level is outside, as are
    /// rooms that touch it without a wall between. Above the ground floor, tiles without floor
    /// only join each other.
    init(walls: [WallTile], floors: [UInt16], width: Int, height: Int, level: Int8, rooms: inout [Room]) {
        var fill = Fill(walls: walls, floors: floors, width: width, height: height, noAir: rooms.count > 1)
        fill.run(level: level, rooms: &rooms)
        self.width = width
        self.height = height
        map = fill.map
    }
}

private struct Fill {
    struct Step {
        var x: Int
        var y: Int
        /// The edges the fill may cross from this tile (or half tile).
        var sides: WallSegments
    }

    let walls: [WallTile]
    let floors: [UInt16]
    let width: Int
    let height: Int
    /// Whether tiles without floor stop the fill: on every level but the ground floor.
    let noAir: Bool
    var map: [UInt32]
    var pending: [Step] = []
    var adjacent: [UInt16] = []
    /// The floor pattern the current room spreads over.
    var expectedTile: UInt16 = 0

    init(walls: [WallTile], floors: [UInt16], width: Int, height: Int, noAir: Bool) {
        self.walls = walls
        self.floors = floors
        self.width = width
        self.height = height
        self.noAir = noAir
        map = Array(repeating: 0, count: width * height)
    }

    mutating func run(level: Int8, rooms: inout [Room]) {
        var outside = true
        var index = 0
        var remaining = true
        while remaining {
            pending.removeAll()
            remaining = false
            // Find the next tile, or side of a diagonal, without a room.
            while index < map.count {
                remaining = true
                let wall = walls[index]
                let room = UInt32(truncatingIfNeeded: rooms.count)
                let x = index % width, y = index / width
                if map[index] == 0 && wall.segments.isDisjoint(with: .anyDiagonal) {
                    expectedTile = floors[index]
                    map[index] = room | room << 16
                    pending.append(Step(x: x, y: y, sides: .anySide))
                    break
                } else if map[index] & 0xFFFF == 0 {
                    let sides: WallSegments
                    if wall.segments.contains(.horizontalDiagonal) {
                        sides = [.topLeft, .topRight]
                        expectedTile = wall.topLeftStyle
                        map[index] |= 0x8000_0000
                    } else {
                        sides = [.topRight, .bottomRight]
                        expectedTile = wall.topLeftPattern
                    }
                    map[index] |= room
                    pending.append(Step(x: x, y: y, sides: sides))
                    break
                } else if map[index] & 0x7FFF_0000 == 0 {
                    let sides: WallSegments
                    if wall.segments.contains(.horizontalDiagonal) {
                        sides = [.bottomLeft, .bottomRight]
                        expectedTile = wall.topLeftPattern
                        map[index] |= 0x8000_0000
                    } else {
                        sides = [.topLeft, .bottomLeft]
                        expectedTile = wall.topLeftStyle
                    }
                    map[index] |= room << 16
                    pending.append(Step(x: x, y: y, sides: sides))
                    index += 1
                    break
                } else {
                    remaining = false
                }
                index += 1
            }
            guard remaining, let start = pending.last else { continue }

            let roomID = UInt16(truncatingIfNeeded: rooms.count)
            adjacent.removeAll()
            var area: UInt16 = 0
            var minX = start.x, maxX = start.x, minY = start.y, maxY = start.y
            while let step = pending.popLast() {
                area &+= 1
                minX = min(minX, step.x)
                maxX = max(maxX, step.x)
                minY = min(minY, step.y)
                maxY = max(maxY, step.y)
                spread(from: step, room: roomID)
            }
            close(room: roomID, level: level, area: area,
                  bounds: TileRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1),
                  outside: &outside, rooms: &rooms)
            outside = false
        }
    }

    /// Spreads to the four neighbors a step may reach. A normal wall (style 1) stops the
    /// fill; any other wall only makes the rooms on either side adjacent.
    private mutating func spread(from step: Step, room: UInt16) {
        let plusX = (step.x + 1) % width, minusX = (step.x + width - 1) % width
        let plusY = (step.y + 1) % height, minusY = (step.y + height - 1) % height
        let here = walls[step.x + step.y * width]
        let east = walls[plusX + step.y * width], south = walls[step.x + plusY * width]

        var open = !east.segments.contains(.topLeft)
        if (open || east.topLeftStyle != 1) && step.sides.contains(.bottomRight) {
            spread(ontoX: plusX, y: step.y, from: 0, room: room, forceAdjacent: !open)
        }
        open = !here.segments.contains(.topLeft)
        if (open || here.topLeftStyle != 1) && step.sides.contains(.topLeft) {
            spread(ontoX: minusX, y: step.y, from: 2, room: room, forceAdjacent: !open)
        }
        open = !south.segments.contains(.topRight)
        if (open || south.topRightStyle != 1) && step.sides.contains(.bottomLeft) {
            spread(ontoX: step.x, y: plusY, from: 1, room: room, forceAdjacent: !open)
        }
        open = !here.segments.contains(.topRight)
        if (open || here.topRightStyle != 1) && step.sides.contains(.topRight) {
            spread(ontoX: step.x, y: minusY, from: 3, room: room, forceAdjacent: !open)
        }
    }

    /// `SpreadOnto`: claims a tile, or the side of a diagonal facing `direction` (0 from −x,
    /// 1 from −y, 2 from +x, 3 from +y), or records the room already there as adjacent.
    private mutating func spread(ontoX x: Int, y: Int, from direction: Int, room: UInt16, forceAdjacent: Bool) {
        let index = x + y * width
        let wall = walls[index]
        let hasExpectation = (expectedTile == 0 && noAir) || expectedTile > 65533

        let target: (room: UInt16, floor: UInt16, claim: UInt32, sides: WallSegments)
        let low = UInt16(truncatingIfNeeded: map[index]), high = UInt16(truncatingIfNeeded: (map[index] >> 16) & 0x7FFF)
        let room32 = UInt32(room)
        if wall.segments.contains(.horizontalDiagonal) {
            target = direction < 2
                ? (low, wall.topLeftStyle, room32 | 0x8000_0000, [.topLeft, .topRight])
                : (high, wall.topLeftPattern, room32 << 16 | 0x8000_0000, [.bottomLeft, .bottomRight])
        } else if wall.segments.contains(.verticalDiagonal) {
            target = direction > 0 && direction < 3
                ? (low, wall.topLeftPattern, room32, [.topRight, .bottomRight])
                : (high, wall.topLeftStyle, room32 << 16, [.topLeft, .bottomLeft])
        } else {
            target = (low, floors[index], room32 | room32 << 16, .anySide)
        }

        let blocked = hasExpectation
            ? expectedTile != target.floor
            : (target.floor == 0 && noAir) || target.floor > 65533
        if forceAdjacent || target.room > 0 || blocked {
            // Already filled, or something other than a wall divides the space here.
            if target.room != room && target.room > 0 && !adjacent.contains(target.room) {
                adjacent.append(target.room)
            }
            return
        }
        map[index] |= target.claim
        pending.append(Step(x: x, y: y, sides: target.sides))
    }

    /// Records a filled room: links its neighbors, spreads "outside", and merges light bases.
    private func close(room roomID: UInt16, level: Int8, area: UInt16, bounds: TileRect,
                       outside: inout Bool, rooms: inout [Room]) {
        var lightBase = roomID
        var joinsLight = false
        for neighbor in adjacent {
            let room = rooms[Int(neighbor)]
            if lightBase > room.lightBaseRoom {
                joinsLight = true
                lightBase = room.lightBaseRoom
            }
            if !rooms[Int(neighbor)].adjacentRooms.contains(roomID) { rooms[Int(neighbor)].adjacentRooms.append(roomID) }
            if outside {
                Self.makeOutside(Int(room.id), in: &rooms)
            } else if room.isOutside {
                outside = true
            }
        }
        var supportRooms: [UInt16] = []
        if joinsLight {
            rooms[Int(lightBase)].supportRooms.append(roomID)
        } else {
            supportRooms.append(roomID)
        }
        rooms.append(Room(id: roomID, lightBaseRoom: lightBase, level: level + 1, isOutside: outside,
                          area: area, isPool: expectedTile > 65533, adjacentRooms: adjacent, bounds: bounds,
                          supportRooms: supportRooms))
        for neighbor in adjacent {
            Self.switchLightBase(of: rooms[Int(neighbor)], to: lightBase, in: &rooms)
        }
    }

    /// `MakeOutside`: marks a room outside, and every room joined to it that isn't yet.
    private static func makeOutside(_ start: Int, in rooms: inout [Room]) {
        rooms[start].isOutside = true
        var queue = rooms[start].adjacentRooms, next = 0
        while next < queue.count {
            let visit = Int(queue[next])
            next += 1
            guard visit < rooms.count, !rooms[visit].isOutside else { continue }
            rooms[visit].isOutside = true
            queue += rooms[visit].adjacentRooms
        }
    }

    /// `TrySwitchBaseRoom`: moves every room sharing `room`'s light base over to `newBase`.
    private static func switchLightBase(of room: Room, to newBase: UInt16, in rooms: inout [Room]) {
        let oldBase = Int(room.lightBaseRoom)
        guard oldBase != Int(newBase) else { return }
        for member in rooms[oldBase].supportRooms {
            rooms[Int(newBase)].supportRooms.append(member)
            rooms[Int(member)].lightBaseRoom = newBase
        }
        rooms[oldBase].supportRooms.removeAll()
    }
}
