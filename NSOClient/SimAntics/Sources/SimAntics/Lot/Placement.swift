/// Why an object can't go where it was asked to, or `success` (FreeSO's `VMPlacementError`).
///
/// The raw values index the game's placement error strings (`placementerrs.cst`).
public enum PlacementError: Int, Sendable, Hashable {
    case success = -1
    case locationOutOfBounds = 0, levelOutOfBounds, mustBeAtTileCenter, mustBeInCorner, cantBeInCorner
    case mustBeAgainstWall, cantBeThroughWall, mustBeOnUpstairsFloorHole, mustBeOutside, mustBeInside
    case cantIntersectOtherObjects, mustBeOnGround, cantFindSlot, cantSupportWeight, cantSupportSize
    case cantPlaceOnTop, cantPlaceOnSlope, cantPlaceInAir, notAllowedOnFloor, notAllowedOnTerrain
    case cantAfford, mustBeAgainstUnusedWall, mustBeOnDiagonal, heightNotAllowed, insufficientFunds
    case specialShowMoneyError, hasWater, noWater, cantPlaceOnWater, mustPlaceOnWater, mustPlaceOnPool
    case mustBeOnFirstLevel
    case mustRemoveObjectsOnWall = 33
    case cannotDeleteObject = 35, objectNotOwnedByYou, counterHeight, cantBePickedUp, inUse
    case cantBePickedUpOutOfBounds, cantEffectFirstLevelFromSecondLevel, cantPlaceInAirOtherLevel
    case notAllowedOnFloorOtherLevel, cannotPlaceComputerOnEndTable, cannotDeletePoolWhilePeopleAreInIt
    case mustRemoveLadderOrDivingBoardBeforeDeletingPool, cannotWallpaperFence, mustHaveMoreSpaceFromCeiling
    case tooManyObjectsOnTheLot, cantPlaceOnForSaleObject
}

/// The outcome of a placement check (`VMPlacementResult`): the status, and the object it concerns,
/// such as the one in the way or the one to stack onto.
public struct PlacementResult {
    public var status: PlacementError
    public var object: Entity?

    public init(_ status: PlacementError = .success, object: Entity? = nil) {
        self.status = status
        self.object = object
    }
}

/// How a placement request bends the rules (`VMPlaceRequestFlags`).
public struct PlaceRequestFlags: OptionSet, Sendable, Hashable {
    public var rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Stack onto an object's slot when one is in the way.
    public static let acceptSlots = PlaceRequestFlags(rawValue: 1)
    /// Respect the lot's buildable area.
    public static let userBuildableLimit = PlaceRequestFlags(rawValue: 2)
    /// Skip the check for other objects.
    public static let allowIntersection = PlaceRequestFlags(rawValue: 4)

    public static let userPlacement: PlaceRequestFlags = [.acceptSlots, .userBuildableLimit]
}

/// Where an object may stand, from object data 42 (`VMPlacementFlags`).
public struct PlacementFlags: OptionSet, Sendable, Hashable {
    public var rawValue: Int16
    public init(rawValue: Int16) { self.rawValue = rawValue }

    public static let onFloor = PlacementFlags(rawValue: 1)
    public static let onTerrain = PlacementFlags(rawValue: 1 << 1)
    public static let onWater = PlacementFlags(rawValue: 1 << 2)
    public static let onSurface = PlacementFlags(rawValue: 1 << 3)
    public static let onDoor = PlacementFlags(rawValue: 1 << 4)
    public static let onWindow = PlacementFlags(rawValue: 1 << 5)
    public static let onLockedTile = PlacementFlags(rawValue: 1 << 6)
    public static let requireFirstLevel = PlacementFlags(rawValue: 1 << 7)
    public static let onSlope = PlacementFlags(rawValue: 1 << 8)
    public static let inAir = PlacementFlags(rawValue: 1 << 9)
    public static let inWall = PlacementFlags(rawValue: 1 << 10)
    public static let allowOnPool = PlacementFlags(rawValue: 1 << 11)
    public static let requirePool = PlacementFlags(rawValue: 1 << 12)
    public static let requireWater = PlacementFlags(rawValue: 1 << 13)
}

/// Which walls an object needs or can't have around it, from object data 13 (`WallPlacementFlags`).
/// The low four bits (and the four from bit 8) are the sides: front, right, behind, left.
public struct WallPlacementFlags: OptionSet, Sendable, Hashable {
    public var rawValue: Int16
    public init(rawValue: Int16) { self.rawValue = rawValue }

    public static let wallRequiredInFront = WallPlacementFlags(rawValue: 1)
    public static let wallRequiredOnRight = WallPlacementFlags(rawValue: 1 << 1)
    public static let wallRequiredBehind = WallPlacementFlags(rawValue: 1 << 2)
    public static let wallRequiredOnLeft = WallPlacementFlags(rawValue: 1 << 3)
    public static let cornerNotAllowed = WallPlacementFlags(rawValue: 1 << 4)
    public static let cornerRequired = WallPlacementFlags(rawValue: 1 << 5)
    public static let diagonalRequired = WallPlacementFlags(rawValue: 1 << 6)
    public static let diagonalAllowed = WallPlacementFlags(rawValue: 1 << 7)
    public static let wallNotAllowedInFront = WallPlacementFlags(rawValue: 1 << 8)
    public static let wallNotAllowedOnRight = WallPlacementFlags(rawValue: 1 << 9)
    public static let wallNotAllowedBehind = WallPlacementFlags(rawValue: 1 << 10)
    public static let wallNotAllowedOnLeft = WallPlacementFlags(rawValue: 1 << 11)
}

/// The rectangle an object takes up on the lot, in sixteenths of a tile (FreeSO's `VMObstacle`).
public struct Obstacle: Sendable, Hashable {
    public var x1: Int
    public var y1: Int
    public var x2: Int
    public var y2: Int

    /// The corners in either order.
    public init(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int) {
        self.x1 = min(x1, x2)
        self.y1 = min(y1, y2)
        self.x2 = max(x1, x2)
        self.y2 = max(y1, y2)
    }

    /// Whether the two overlap; touching edges don't.
    public func intersects(_ other: Obstacle) -> Bool {
        !(other.x1 >= x2 || other.x2 <= x1 || other.y1 >= y2 || other.y2 <= y1)
    }
}

/// Object flags (object data 8) and flags 2 (object data 40) that placement reads.
enum EntityFlag {
    static let disallowPersonIntersection: Int16 = 1 << 1
    static let hasZeroExtent: Int16 = 1 << 2
    static let allowPersonIntersection: Int16 = 1 << 4
    static let architecturalWindow: Int16 = 1 << 14
    static let architecturalDoor: Int16 = Int16(bitPattern: 1 << 15)
}

extension Direction {
    /// Quarter turns clockwise from north for the four compass points, 0 for the diagonals
    /// (`DirectionToWallOff`).
    var wallOffset: Int {
        switch self {
        case .east: 1
        case .south: 2
        case .west: 3
        default: 0
        }
    }
}
