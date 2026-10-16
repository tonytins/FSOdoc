import TSOFiles

/// A field of an object definition (`OBJD`) that SimAntics can read, by index.
///
/// Ports FreeSO's `VMOBJDVariable` and `VMMemory.GetEntityDefinitionVar`; the raw
/// values are the indexes (see `docs/simantics/scopes.md`, scope 21).
public enum DefinitionVariable: Int16, Sendable, CaseIterable {
    case version1 = 0, version2, initialStackSize, baseGraphic, numGraphics, mainTreeID, gardeningTreeID
    case treeTableID, interactionGroup, type, masterID, subIndex, washHandsTreeID, animTableID, guid1, guid2
    case disabled, portalTreeID, price, bodyStringsID, slotsID, allowIntersectionTreeID, usesFunctionTable
    case bitfield1, prepareFoodTreeID, cookFoodTreeID, placeOnSurfaceTreeID, disposeTreeID, eatFoodTreeID
    case pickupFromSlotTreeID, washDishTreeID, eatingSurfaceTreeID, sitTreeID, standTreeID, salePrice
    case unused35, unused36, brokenBaseGraphicOffset, unused38, hasCriticalAttributes, buyModeType
    case catalogStringsID, isGlobalSimObject, initTreeID, placeTreeID, userPickupTreeID, wallStyle, loadTreeID
    case userPlaceTreeID, objectVersion, roomChangedTreeID, motiveEffectsID, cleanupTreeID, levelInfoRequestTreeID
    case catalogPopupID, servingSurfaceTreeID, levelOffset, shadow, numAttributes, cleanTreeID, queueSkippedTreeID
    case frontDirection, wallAdjacencyChangedTreeID, myLeadObject, dynamicSpritesBaseID, numDynamicSprites
    case chairEntryFlags, tileWidth, lotCategories, buildModeType, originalGUID1, originalGUID2, suitGUID1
    case suitGUID2, pickupTreeID, thumbnailGraphic, shadowFlags, footprintMask, dynamicMultiTileUpdateTreeID
    case shadowBrightness, repairTreeID, wallStyleSpriteID, ratingHunger, ratingComfort, ratingHygiene
    case ratingBladder, ratingEnergy, ratingFun, ratingRoom, ratingSkillFlags, numTypeAttributes, miscFlags
    case typeAttributeGUID1, typeAttributeGUID2, interactionResultStrings, clientHouseJoinTreeID
    case prepareForSaleTreeID

    /// A definition field as FreeSO reads it, quirks included.
    ///
    /// Version 1 and GUID 1 are the value modulo 0xFFFF, not its low 16 bits.
    /// Serving Surface Tree and Rating Comfort both read the catalog popup ID, and
    /// Lot Categories always reads 0. Several fields fail with "Not Implemented!", and
    /// an index outside the table reads 0.
    public static func value(_ index: Int16, of definition: OBJD) throws(SimAnticsError) -> Int16 {
        func short(_ value: UInt16) -> Int16 { Int16(bitPattern: value) }
        guard let variable = DefinitionVariable(rawValue: index) else { return 0 }
        switch variable {
        case .version1: return Int16(truncatingIfNeeded: definition.version % 0xFFFF)
        case .version2: return Int16(truncatingIfNeeded: definition.version >> 16)
        case .initialStackSize: return short(definition.stackSize)
        case .baseGraphic: return short(definition.baseGraphicID)
        case .numGraphics: return short(definition.numGraphics)
        case .mainTreeID: return short(definition.bhavMainID)
        case .gardeningTreeID: return short(definition.bhavGardeningID)
        case .treeTableID: return short(definition.treeTableID)
        case .interactionGroup: return definition.interactionGroupID
        case .type: return short(definition.objectType)
        case .masterID: return short(definition.masterID)
        case .subIndex: return definition.subIndex
        case .washHandsTreeID: return short(definition.bhavWashHandsID)
        case .animTableID: return short(definition.animationTableID)
        case .guid1: return Int16(truncatingIfNeeded: definition.guid % 0xFFFF)
        case .guid2: return Int16(truncatingIfNeeded: definition.guid >> 16)
        case .disabled: return short(definition.disabled)
        case .price: return short(definition.price)
        case .bodyStringsID: return short(definition.bodyStringID)
        case .slotsID: return short(definition.slotID)
        case .allowIntersectionTreeID: return short(definition.bhavAllowIntersectionID)
        case .usesFunctionTable: return short(definition.usesFnTable)
        case .bitfield1: return short(definition.bitField1)
        case .prepareFoodTreeID: return short(definition.bhavPrepareFoodID)
        case .cookFoodTreeID: return short(definition.bhavCookFoodID)
        case .placeOnSurfaceTreeID: return short(definition.bhavPlaceSurfaceID)
        case .disposeTreeID: return short(definition.bhavDisposeID)
        case .eatFoodTreeID: return short(definition.bhavEatID)
        case .pickupFromSlotTreeID: return short(definition.bhavPickupFromSlotID)
        case .washDishTreeID: return short(definition.bhavWashDishID)
        case .eatingSurfaceTreeID: return short(definition.bhavEatSurfaceID)
        case .sitTreeID: return short(definition.bhavSitID)
        case .standTreeID: return short(definition.bhavStandID)
        case .salePrice: return short(definition.salePrice)
        case .buyModeType: return short(definition.functionFlags)
        case .catalogStringsID: return short(definition.catalogStringsID)
        case .isGlobalSimObject: return short(definition.global)
        case .initTreeID: return short(definition.bhavInit)
        case .placeTreeID: return short(definition.bhavPlace)
        case .userPickupTreeID: return short(definition.bhavUserPickup)
        case .wallStyle: return short(definition.wallStyle)
        case .loadTreeID: return short(definition.bhavLoad)
        case .userPlaceTreeID: return short(definition.bhavUserPlace)
        case .objectVersion: return short(definition.objectVersion)
        case .roomChangedTreeID: return short(definition.bhavRoomChange)
        case .motiveEffectsID: return short(definition.motiveEffectsID)
        case .cleanupTreeID: return short(definition.bhavCleanup)
        case .levelInfoRequestTreeID: return short(definition.bhavLevelInfo)
        case .catalogPopupID, .servingSurfaceTreeID, .ratingComfort: return short(definition.catalogID)
        case .levelOffset: return short(definition.levelOffset)
        case .shadow: return short(definition.shadow)
        case .numAttributes: return short(definition.numAttributes)
        case .cleanTreeID: return short(definition.bhavClean)
        case .queueSkippedTreeID: return short(definition.bhavQueueSkipped)
        case .frontDirection: return short(definition.frontDirection)
        case .wallAdjacencyChangedTreeID: return short(definition.bhavWallAdjacencyChanged)
        case .myLeadObject: return short(definition.myLeadObject)
        case .dynamicSpritesBaseID: return short(definition.dynamicSpriteBaseId)
        case .numDynamicSprites: return short(definition.numDynamicSprites)
        case .chairEntryFlags: return short(definition.chairEntryFlags)
        case .tileWidth: return short(definition.tileWidth)
        case .lotCategories: return 0
        case .buildModeType: return short(definition.buildModeType)
        case .originalGUID1: return short(definition.originalGUID1)
        case .originalGUID2: return short(definition.originalGUID2)
        case .suitGUID1: return short(definition.suitGUID1)
        case .suitGUID2: return short(definition.suitGUID2)
        case .pickupTreeID: return short(definition.bhavPickup)
        case .thumbnailGraphic: return short(definition.thumbnailGraphic)
        case .shadowFlags: return short(definition.shadowFlags)
        case .footprintMask: return short(definition.footprintMask)
        case .dynamicMultiTileUpdateTreeID: return short(definition.bhavDynamicMultiTileUpdate)
        case .shadowBrightness: return short(definition.shadowBrightness)
        case .repairTreeID: return short(definition.bhavRepair)
        case .wallStyleSpriteID: return short(definition.wallStyleSpriteID)
        case .ratingHunger: return short(definition.ratingHunger)
        case .ratingHygiene: return short(definition.ratingHygiene)
        case .ratingBladder: return short(definition.ratingBladder)
        case .ratingEnergy: return short(definition.ratingEnergy)
        case .ratingFun: return short(definition.ratingFun)
        case .ratingRoom: return short(definition.ratingRoom)
        case .ratingSkillFlags: return short(definition.ratingSkillFlags)
        case .portalTreeID, .unused35, .unused36, .brokenBaseGraphicOffset, .unused38, .hasCriticalAttributes,
             .numTypeAttributes, .miscFlags, .typeAttributeGUID1, .typeAttributeGUID2, .interactionResultStrings,
             .clientHouseJoinTreeID, .prepareForSaleTreeID:
            throw .simantics("Not Implemented!")
        }
    }
}
