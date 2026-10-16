/// Where something is on a lot: a point in sixteenths of a tile, and a level.
///
/// Corresponds to FreeSO's `LotTilePos`. Level 1 is the ground floor. Objects that aren't on
/// the lot (in an inventory, or not placed yet) are at ``outOfWorld``.
public struct LotPosition: Sendable, Hashable, CustomStringConvertible {
    /// Sixteenths of a tile.
    public var x: Int16
    public var y: Int16
    public var level: Int8

    public init(x: Int16, y: Int16, level: Int8) {
        self.x = x
        self.y = y
        self.level = level
    }

    /// Off the lot.
    public static let outOfWorld = LotPosition(x: .min, y: .min, level: 1)

    /// The center of a tile (`LotTilePos.FromBigTile`), wrapping like a C# `short`.
    public static func center(ofTileX tileX: Int16, y tileY: Int16, level: Int8) -> LotPosition {
        LotPosition(x: Int16(truncatingIfNeeded: Int(tileX) << 4 + 8),
                    y: Int16(truncatingIfNeeded: Int(tileY) << 4 + 8), level: level)
    }

    public var tileX: Int16 { x >> 4 }
    public var tileY: Int16 { y >> 4 }
    public var isOutOfWorld: Bool { self == .outOfWorld }

    /// The distance in sixteenths of a tile, rounded down, ignoring levels (`LotTilePos.Distance`).
    public func distance(to other: LotPosition) -> Int {
        let dx = Double(Int(x) - Int(other.x)), dy = Double(Int(y) - Int(other.y))
        return Int((dx * dx + dy * dy).squareRoot())
    }

    public var description: String {
        isOutOfWorld ? "out of the world" : "(\(x), \(y)) level \(level)"
    }
}

/// The eight compass facings, as 2017 stores them: one bit each, north first, clockwise.
public enum Direction: UInt8, Sendable, CaseIterable {
    case north = 0x01, northEast = 0x02, east = 0x04, southEast = 0x08
    case south = 0x10, southWest = 0x20, west = 0x40, northWest = 0x80

    /// The facing for a notch from 0 (north) to 7, clockwise.
    public init(notch: Int) {
        self = Direction.allCases[((notch % 8) + 8) % 8]
    }

    /// 0 (north) to 7, clockwise, as object data 1 holds it.
    public var notch: Int {
        Direction.allCases.firstIndex(of: self) ?? 0
    }
}
