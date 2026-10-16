/// An entity's object data: 80 values each object and Sim carries, by index.
///
/// Ports FreeSO's `VMStackObjectVariable`; the raw values are the indexes. Most are
/// plain storage; a few read or write other state (see ``Entity/value(of:)``).
public enum ObjectVariable: Int16, Sendable, CaseIterable {
    case graphic = 0, direction, containerID, slotNumber, allowedHeightFlags, wallAdjacencyFlags, routeID
    case roomImpact, flags, routePreference, routePenalty, objectID, targetID, wallPlacementFlags
    case slotHierarchyNumber, repairState, lightSource, walkStyle, simAge, unusedGender, treeTableEntry
    case birthMinutes, speed, rotationNotches, birthHour, lockoutCount, parentID, weight, supportStrength
    case room, roomPlacement, prepValue, cookValue, surfaceValue, hidden, temperature, disposeValue
    case washDishValue, eatingSurfaceValue, dirtyLevel, flagField2, unused41, placementFlags
    case movementFlags, maximumGrade, birthYear, birthMonth, birthDay, ageInMonths, size, hideInteraction
    case lightingContribution, primitiveResult, wallBlockFlags, primitiveResultID, globalWearRepairState
    case ageInventoryQuarterDaysStart, ageQuarterDays, objectVersion, category, simIndependent
    case servingSurfaceValue, useCount, exclusivePlacementFlags, gardeningValue, washHandsValue
    case functionScore, slotCount, persistedFlags, unusedRandomSeedLow, salePriceHigh, salePriceLow
    case groupID, reserved73, reserved74, reserved75, reserved76, reserved77, reserved78, fsoEngineQuery

    /// The number of object data values each entity has.
    public static let count = 80
}
