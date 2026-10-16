/// Which edges and diagonals of a tile have a wall (FreeSO's `WallSegments`).
///
/// A tile owns the walls on its top-left (−x) and top-right (−y) edges; the bottom edges
/// belong to the neighbors, though blueprints mark them on both.
public struct WallSegments: OptionSet, Sendable, Hashable {
    public var rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let topLeft = WallSegments(rawValue: 1)
    public static let topRight = WallSegments(rawValue: 2)
    public static let bottomRight = WallSegments(rawValue: 4)
    public static let bottomLeft = WallSegments(rawValue: 8)
    /// A diagonal from the top-right corner to the bottom-left one.
    public static let horizontalDiagonal = WallSegments(rawValue: 16)
    /// A diagonal from the top-left corner to the bottom-right one.
    public static let verticalDiagonal = WallSegments(rawValue: 32)

    public static let anyDiagonal: WallSegments = [.horizontalDiagonal, .verticalDiagonal]
    public static let anySide: WallSegments = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

/// The walls on one tile (FreeSO's `WallTile`, without the state objects set at run time).
///
/// Style 1 is a normal wall; other styles are fences and the like, which divide rooms only
/// where a floor or pool does. On a diagonal tile, `topLeftStyle` and `topLeftPattern` hold
/// the floor patterns of the two halves instead.
public struct WallTile: Sendable, Hashable {
    public var segments: WallSegments
    public var topLeftPattern: UInt16
    public var topRightPattern: UInt16
    public var bottomLeftPattern: UInt16
    public var bottomRightPattern: UInt16
    public var topLeftStyle: UInt16
    public var topRightStyle: UInt16
    /// Styles that doors and windows put on the wall (`ObjSetTLStyle`, `ObjSetTRStyle`); only drawing reads them.
    public var objectTopLeftStyle: UInt16 = 0
    public var objectTopRightStyle: UInt16 = 0
    /// Whether a door is in the wall, which routing will read (`TopLeftDoor`, `TopRightDoor`).
    public var topLeftDoor = false
    public var topRightDoor = false
    /// Walls an object with exclusive wall placement is against (`OccupiedWalls`).
    public var occupiedWalls: WallSegments = []

    public init(segments: WallSegments = [], topLeftPattern: UInt16 = 0, topRightPattern: UInt16 = 0,
                bottomLeftPattern: UInt16 = 0, bottomRightPattern: UInt16 = 0,
                topLeftStyle: UInt16 = 0, topRightStyle: UInt16 = 0) {
        self.segments = segments
        self.topLeftPattern = topLeftPattern
        self.topRightPattern = topRightPattern
        self.bottomLeftPattern = bottomLeftPattern
        self.bottomRightPattern = bottomRightPattern
        self.topLeftStyle = topLeftStyle
        self.topRightStyle = topRightStyle
    }

    /// No walls.
    public static let empty = WallTile()
}

/// A lot's walls, floors, and the rooms they make (FreeSO's `VMArchitecture`).
///
/// Changes mark the architecture dirty; rooms are regenerated on the next tick, as in FreeSO, so
/// a room lookup between a change and the tick still sees the old rooms. Terrain, roofs,
/// support for upper floors, and build-mode costs aren't ported yet.
public struct Architecture: Sendable {
    /// Levels, ground floor first.
    public static let stories = 5
    /// The pattern FreeSO gives pool tiles; anything above 65533 counts as water.
    public static let poolPattern: UInt16 = 65535

    public let width: Int
    public let height: Int
    /// Walls by level (0 is the ground floor), then tile, across then down.
    public private(set) var walls: [[WallTile]]
    /// Floor patterns by level, then tile; 0 is no floor.
    public private(set) var floors: [[UInt16]]
    /// Each level's room map, from the last regeneration.
    public private(set) var roomMaps: [RoomMap]
    /// Every room on every level, from the last regeneration. Index 0 is an unused placeholder,
    /// so room IDs start at 1 (FreeSO's `RoomData`).
    public private(set) var rooms: [Room]
    /// Whether walls or floors changed since rooms were last generated.
    public private(set) var isDirty = false
    /// Identifies one generation of ``rooms``, so a VM can tell its room lists are out of date.
    final class Generation: Sendable {}
    private(set) var generation = Generation()

    /// An empty lot: no walls and no floors, with its rooms generated.
    ///
    /// FreeSO generates rooms only once a lot loads; this port keeps a fresh architecture
    /// consistent from the start instead.
    ///
    /// - Throws: ``SimAnticsError/simantics(_:)`` if the size is outside 1...255 tiles, the
    ///   most FreeSO's 16-bit tile offsets can number.
    public init(width: Int, height: Int) throws(SimAnticsError) {
        guard (1...255).contains(width), (1...255).contains(height) else {
            throw .simantics("lot size \(width)x\(height) is outside 1...255")
        }
        self.width = width
        self.height = height
        walls = Array(repeating: Array(repeating: .empty, count: width * height), count: Self.stories)
        floors = Array(repeating: Array(repeating: 0, count: width * height), count: Self.stories)
        roomMaps = []
        rooms = []
        regenerateRooms()
    }

    // MARK: Tiles

    public func wall(atX tileX: Int, y tileY: Int, level: Int) throws(SimAnticsError) -> WallTile {
        walls[try levelIndex(level)][try offset(tileX, tileY)]
    }

    public func floor(atX tileX: Int, y tileY: Int, level: Int) throws(SimAnticsError) -> UInt16 {
        floors[try levelIndex(level)][try offset(tileX, tileY)]
    }

    /// Sets a tile's walls (`SetWall`). A tile without segments is cleared entirely.
    public mutating func setWall(_ wall: WallTile, atX tileX: Int, y tileY: Int, level: Int) throws(SimAnticsError) {
        let index = try offset(tileX, tileY), story = try levelIndex(level)
        walls[story][index] = wall.segments.rawValue > 0 ? wall : .empty
        isDirty = true
    }

    /// Sets a tile's floor without the support and placement checks build mode makes
    /// (`SetFloor` with `force`), as loading a lot does.
    public mutating func setFloor(_ pattern: UInt16, atX tileX: Int, y tileY: Int, level: Int) throws(SimAnticsError) {
        let index = try offset(tileX, tileY), story = try levelIndex(level)
        floors[story][index] = pattern
        isDirty = true
    }

    /// Whether a position is off the lot or outside its levels (`VMContext.IsOutOfBounds`).
    public func isOutOfBounds(_ position: LotPosition) -> Bool {
        position.x < 0 || position.y < 0 || position.level < 1 || Int(position.tileX) >= width
            || Int(position.tileY) >= height || Int(position.level) > Self.stories
    }

    /// The floor under a position, or on a diagonal tile, the pattern of the half it's in (`GetPreciseFloor`).
    ///
    /// - Throws: ``SimAnticsError/indexOutOfRange(_:)`` off the lot.
    public func preciseFloor(at position: LotPosition) throws(SimAnticsError) -> UInt16 {
        let tileX = Int(position.tileX), tileY = Int(position.tileY), level = Int(position.level)
        let wall = try self.wall(atX: tileX, y: tileY, level: level)
        let inX = Int(position.x) % 16, inY = Int(position.y) % 16
        if wall.segments.contains(.verticalDiagonal) {
            return inX - inY > 0 ? wall.topLeftPattern : wall.topLeftStyle
        } else if wall.segments.contains(.horizontalDiagonal) {
            return inX + inY > 15 ? wall.topLeftPattern : wall.topLeftStyle
        }
        return try floor(atX: tileX, y: tileY, level: level)
    }

    // MARK: Rooms

    /// Regenerates every level's room map (`RegenRoomMap`), level by level, so rooms on upper
    /// levels number after the ones below.
    public mutating func regenerateRooms() {
        var rooms = [Room.placeholder]
        roomMaps = (0..<Self.stories).map { story in
            RoomMap(walls: walls[story], floors: floors[story], width: width, height: height,
                    level: Int8(story), rooms: &rooms)
        }
        self.rooms = rooms
        isDirty = false
        generation = Generation()
    }

    /// The room at a position, or 0 off the lot (`GetRoomAt`). On a tile split by a diagonal
    /// wall, the position within the tile picks the side.
    public func room(at position: LotPosition) -> UInt16 {
        let tileX = Int(position.tileX), tileY = Int(position.tileY), level = Int(position.level)
        guard (0..<width).contains(tileX), (0..<height).contains(tileY), (1...Self.stories).contains(level) else {
            return 0
        }
        let index = tileX + tileY * width
        let entry = roomMaps[level - 1].map[index]
        let first = UInt16(truncatingIfNeeded: entry), second = UInt16(truncatingIfNeeded: (entry >> 16) & 0x7FFF)
        guard first != second else { return first }
        let segments = walls[level - 1][index].segments
        // Tiles are in range, so the positions aren't negative.
        let inX = Int(position.x) % 16, inY = Int(position.y) % 16
        if segments.contains(.verticalDiagonal) {
            return inX - inY > 0 ? first : second
        } else if segments.contains(.horizontalDiagonal) {
            return inX + inY > 15 ? second : first
        }
        return first
    }

    private func offset(_ tileX: Int, _ tileY: Int) throws(SimAnticsError) -> Int {
        guard (0..<width).contains(tileX), (0..<height).contains(tileY) else {
            throw .indexOutOfRange("tile (\(tileX), \(tileY)) is off a \(width)x\(height) lot")
        }
        return tileX + tileY * width
    }

    private func levelIndex(_ level: Int) throws(SimAnticsError) -> Int {
        guard (1...Self.stories).contains(level) else {
            throw .indexOutOfRange("level \(level) is outside 1...\(Self.stories)")
        }
        return level - 1
    }
}
