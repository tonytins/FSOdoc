import Foundation

/// An object definition: the first chunk the VM reads for an object.
///
/// Ports FreeSO's `OBJD`. The chunk is a list of 16-bit words whose length
/// depends on the version (78 words for version 136 and unknown versions, 93
/// for 138, 94 for 139, 95 for 140 and 141, 103 for 142). Every named field is
/// a fixed word position in that list, so this type keeps the words and reads
/// the fields from them. A field beyond a version's words reads as zero, as the
/// FreeSO defaults did. Property names follow FreeSO's field names, which the
/// VM and editors refer to.
public struct OBJD: IFFChunk {
    public static let typeCode = "OBJD"

    /// The kinds of object the game distinguishes, from `objectType`.
    public enum ObjectType: UInt16, Sendable {
        case unknown = 0
        case person = 2
        case normal = 4
        case simType = 7
        case portal = 8
        case cursor = 9
        case prizeToken = 10
        case `internal` = 11
        case food = 34
    }

    public let id: UInt16
    public let label: String
    /// The format version.
    public let version: UInt32
    /// The raw fields, as 16-bit words.
    public let words: [UInt16]

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (version, words) = try record.parse(byteOrder: .littleEndian) { reader in
            let version = try reader.readUInt32()
            let wordCount = Self.wordCount(forVersion: version)
            var words: [UInt16] = []
            for _ in 0..<wordCount {
                words.append(try reader.readUInt16())
            }
            return (version, words)
        }
    }

    /// The number of words a version stores: FreeSO's field count minus two.
    static func wordCount(forVersion version: UInt32) -> Int {
        let fieldCount = switch version {
        case 138: 95
        case 139: 96
        case 140, 141: 97
        case 142: 105
        default: 80
        }
        return fieldCount - 2
    }

    /// The object type, if it's one the game names.
    public var knownObjectType: ObjectType? { ObjectType(rawValue: objectType) }

    private func word(at index: Int) -> UInt16 {
        words.indices.contains(index) ? words[index] : 0
    }

    /// Two words, low word first, as .NET's little-endian `ReadUInt32` reads them.
    private func doubleWord(at index: Int) -> UInt32 {
        UInt32(word(at: index)) | UInt32(word(at: index + 1)) << 16
    }

    // MARK: Fields

    /// `StackSize`, word 0.
    public var stackSize: UInt16 { word(at: 0) }

    /// `BaseGraphicID`, word 1.
    public var baseGraphicID: UInt16 { word(at: 1) }

    /// `NumGraphics`, word 2.
    public var numGraphics: UInt16 { word(at: 2) }

    /// `BHAV_MainID`, word 3.
    public var bhavMainID: UInt16 { word(at: 3) }

    /// `BHAV_GardeningID`, word 4.
    public var bhavGardeningID: UInt16 { word(at: 4) }

    /// `TreeTableID`, word 5.
    public var treeTableID: UInt16 { word(at: 5) }

    /// `InteractionGroupID`, word 6.
    public var interactionGroupID: Int16 { Int16(bitPattern: word(at: 6)) }

    /// `ObjectType`, word 7.
    public var objectType: UInt16 { word(at: 7) }

    /// `MasterID`, word 8.
    public var masterID: UInt16 { word(at: 8) }

    /// `SubIndex`, word 9.
    public var subIndex: Int16 { Int16(bitPattern: word(at: 9)) }

    /// `BHAV_WashHandsID`, word 10.
    public var bhavWashHandsID: UInt16 { word(at: 10) }

    /// `AnimationTableID`, word 11.
    public var animationTableID: UInt16 { word(at: 11) }

    /// `GUID`, words 12 and 13.
    public var guid: UInt32 { doubleWord(at: 12) }

    /// `Disabled`, word 14.
    public var disabled: UInt16 { word(at: 14) }

    /// `BHAV_Portal`, word 15.
    public var bhavPortal: UInt16 { word(at: 15) }

    /// `Price`, word 16.
    public var price: UInt16 { word(at: 16) }

    /// `BodyStringID`, word 17.
    public var bodyStringID: UInt16 { word(at: 17) }

    /// `SlotID`, word 18.
    public var slotID: UInt16 { word(at: 18) }

    /// `BHAV_AllowIntersectionID`, word 19.
    public var bhavAllowIntersectionID: UInt16 { word(at: 19) }

    /// `UsesFnTable`, word 20.
    public var usesFnTable: UInt16 { word(at: 20) }

    /// `BitField1`, word 21.
    public var bitField1: UInt16 { word(at: 21) }

    /// `BHAV_PrepareFoodID`, word 22.
    public var bhavPrepareFoodID: UInt16 { word(at: 22) }

    /// `BHAV_CookFoodID`, word 23.
    public var bhavCookFoodID: UInt16 { word(at: 23) }

    /// `BHAV_PlaceSurfaceID`, word 24.
    public var bhavPlaceSurfaceID: UInt16 { word(at: 24) }

    /// `BHAV_DisposeID`, word 25.
    public var bhavDisposeID: UInt16 { word(at: 25) }

    /// `BHAV_EatID`, word 26.
    public var bhavEatID: UInt16 { word(at: 26) }

    /// `BHAV_PickupFromSlotID`, word 27.
    public var bhavPickupFromSlotID: UInt16 { word(at: 27) }

    /// `BHAV_WashDishID`, word 28.
    public var bhavWashDishID: UInt16 { word(at: 28) }

    /// `BHAV_EatSurfaceID`, word 29.
    public var bhavEatSurfaceID: UInt16 { word(at: 29) }

    /// `BHAV_SitID`, word 30.
    public var bhavSitID: UInt16 { word(at: 30) }

    /// `BHAV_StandID`, word 31.
    public var bhavStandID: UInt16 { word(at: 31) }

    /// `SalePrice`, word 32.
    public var salePrice: UInt16 { word(at: 32) }

    /// `InitialDepreciation`, word 33.
    public var initialDepreciation: UInt16 { word(at: 33) }

    /// `DailyDepreciation`, word 34.
    public var dailyDepreciation: UInt16 { word(at: 34) }

    /// `SelfDepreciating`, word 35.
    public var selfDepreciating: UInt16 { word(at: 35) }

    /// `DepreciationLimit`, word 36.
    public var depreciationLimit: UInt16 { word(at: 36) }

    /// `RoomFlags`, word 37.
    public var roomFlags: UInt16 { word(at: 37) }

    /// `FunctionFlags`, word 38.
    public var functionFlags: UInt16 { word(at: 38) }

    /// `CatalogStringsID`, word 39.
    public var catalogStringsID: UInt16 { word(at: 39) }

    /// `Global`, word 40.
    public var global: UInt16 { word(at: 40) }

    /// `BHAV_Init`, word 41.
    public var bhavInit: UInt16 { word(at: 41) }

    /// `BHAV_Place`, word 42.
    public var bhavPlace: UInt16 { word(at: 42) }

    /// `BHAV_UserPickup`, word 43.
    public var bhavUserPickup: UInt16 { word(at: 43) }

    /// `WallStyle`, word 44.
    public var wallStyle: UInt16 { word(at: 44) }

    /// `BHAV_Load`, word 45.
    public var bhavLoad: UInt16 { word(at: 45) }

    /// `BHAV_UserPlace`, word 46.
    public var bhavUserPlace: UInt16 { word(at: 46) }

    /// `ObjectVersion`, word 47.
    public var objectVersion: UInt16 { word(at: 47) }

    /// `BHAV_RoomChange`, word 48.
    public var bhavRoomChange: UInt16 { word(at: 48) }

    /// `MotiveEffectsID`, word 49.
    public var motiveEffectsID: UInt16 { word(at: 49) }

    /// `BHAV_Cleanup`, word 50.
    public var bhavCleanup: UInt16 { word(at: 50) }

    /// `BHAV_LevelInfo`, word 51.
    public var bhavLevelInfo: UInt16 { word(at: 51) }

    /// `CatalogID`, word 52.
    public var catalogID: UInt16 { word(at: 52) }

    /// `BHAV_ServingSurface`, word 53.
    public var bhavServingSurface: UInt16 { word(at: 53) }

    /// `LevelOffset`, word 54.
    public var levelOffset: UInt16 { word(at: 54) }

    /// `Shadow`, word 55.
    public var shadow: UInt16 { word(at: 55) }

    /// `NumAttributes`, word 56.
    public var numAttributes: UInt16 { word(at: 56) }

    /// `BHAV_Clean`, word 57.
    public var bhavClean: UInt16 { word(at: 57) }

    /// `BHAV_QueueSkipped`, word 58.
    public var bhavQueueSkipped: UInt16 { word(at: 58) }

    /// `FrontDirection`, word 59.
    public var frontDirection: UInt16 { word(at: 59) }

    /// `BHAV_WallAdjacencyChanged`, word 60.
    public var bhavWallAdjacencyChanged: UInt16 { word(at: 60) }

    /// `MyLeadObject`, word 61.
    public var myLeadObject: UInt16 { word(at: 61) }

    /// `DynamicSpriteBaseId`, word 62.
    public var dynamicSpriteBaseId: UInt16 { word(at: 62) }

    /// `NumDynamicSprites`, word 63.
    public var numDynamicSprites: UInt16 { word(at: 63) }

    /// `ChairEntryFlags`, word 64.
    public var chairEntryFlags: UInt16 { word(at: 64) }

    /// `TileWidth`, word 65.
    public var tileWidth: UInt16 { word(at: 65) }

    /// `LotCategories`, word 66.
    public var lotCategories: UInt16 { word(at: 66) }

    /// `BuildModeType`, word 67.
    public var buildModeType: UInt16 { word(at: 67) }

    /// `OriginalGUID1`, word 68.
    public var originalGUID1: UInt16 { word(at: 68) }

    /// `OriginalGUID2`, word 69.
    public var originalGUID2: UInt16 { word(at: 69) }

    /// `SuitGUID1`, word 70.
    public var suitGUID1: UInt16 { word(at: 70) }

    /// `SuitGUID2`, word 71.
    public var suitGUID2: UInt16 { word(at: 71) }

    /// `BHAV_Pickup`, word 72.
    public var bhavPickup: UInt16 { word(at: 72) }

    /// `ThumbnailGraphic`, word 73.
    public var thumbnailGraphic: UInt16 { word(at: 73) }

    /// `ShadowFlags`, word 74.
    public var shadowFlags: UInt16 { word(at: 74) }

    /// `FootprintMask`, word 75.
    public var footprintMask: UInt16 { word(at: 75) }

    /// `BHAV_DynamicMultiTileUpdate`, word 76.
    public var bhavDynamicMultiTileUpdate: UInt16 { word(at: 76) }

    /// `ShadowBrightness`, word 77.
    public var shadowBrightness: UInt16 { word(at: 77) }

    /// `BHAV_Repair`, word 78.
    public var bhavRepair: UInt16 { word(at: 78) }

    /// `WallStyleSpriteID`, word 79.
    public var wallStyleSpriteID: UInt16 { word(at: 79) }

    /// `RatingHunger`, word 80.
    public var ratingHunger: UInt16 { word(at: 80) }

    /// `RatingComfort`, word 81.
    public var ratingComfort: UInt16 { word(at: 81) }

    /// `RatingHygiene`, word 82.
    public var ratingHygiene: UInt16 { word(at: 82) }

    /// `RatingBladder`, word 83.
    public var ratingBladder: UInt16 { word(at: 83) }

    /// `RatingEnergy`, word 84.
    public var ratingEnergy: UInt16 { word(at: 84) }

    /// `RatingFun`, word 85.
    public var ratingFun: UInt16 { word(at: 85) }

    /// `RatingRoom`, word 86.
    public var ratingRoom: UInt16 { word(at: 86) }

    /// `RatingSkillFlags`, word 87.
    public var ratingSkillFlags: UInt16 { word(at: 87) }

    /// `NumTypeAttributes`, word 88.
    public var numTypeAttributes: UInt16 { word(at: 88) }

    /// `MiscFlags`, word 89.
    public var miscFlags: UInt16 { word(at: 89) }

    /// `TypeAttrGUID`, words 90 and 91. In layouts longer than 80 words, 0 means the object's own GUID.
    public var typeAttributeGUID: UInt32 {
        let stored = doubleWord(at: 90)
        return stored == 0 && words.count > 80 ? guid : stored
    }

}
