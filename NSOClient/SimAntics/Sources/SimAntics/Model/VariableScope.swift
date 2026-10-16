/// Where a SimAntics variable lives: an operand pairs a scope with an index.
///
/// Ports FreeSO's `VMVariableScope`; the raw values match. Operands store scopes as
/// raw bytes, and a byte with no case here fails when read, as in FreeSO.
public enum VariableScope: UInt8, Sendable, CaseIterable {
    case myObjectAttributes = 0
    case stackObjectAttributes = 1
    case targetObjectAttributes = 2
    case myObject = 3
    case stackObject = 4
    case targetObject = 5
    case global = 6
    case literal = 7
    case temps = 8
    case parameters = 9
    case stackObjectID = 10
    case tempByTemp = 11
    case treeAdRange = 12
    case stackObjectTemp = 13
    case myMotives = 14
    case stackObjectMotives = 15
    case stackObjectSlot = 16
    case stackObjectMotiveByTemp = 17
    case myPersonData = 18
    case stackObjectPersonData = 19
    case mySlot = 20
    case stackObjectDefinition = 21
    case stackObjectAttributeByParameter = 22
    case roomByTemp0 = 23
    case neighborInStackObject = 24
    case local = 25
    case tuning = 26
    case dynamicSpriteFlagForTempOfStackObject = 27
    case treeAdPersonalityVariable = 28
    case treeAdMinimum = 29
    case myPersonDataByTemp = 30
    case stackObjectPersonDataByTemp = 31
    case neighborPersonData = 32
    case jobData = 33
    case neighborhoodData = 34
    case stackObjectFunction = 35
    case myTypeAttribute = 36
    case stackObjectTypeAttribute = 37
    case neighborsObjectDefinition = 38
    case localByTemp = 40
    case stackObjectAttributeByTemp = 41
    case tempXL = 42
    case cityTime = 43
    case tsoStandardTime = 44
    case gameTime = 45
    case myList = 46
    case stackObjectList = 47
    case moneyOverHead32Bit = 48
    case myLeadTileAttribute = 49
    case stackObjectLeadTileAttribute = 50
    case myLeadTile = 51
    case stackObjectLeadTile = 52
    case stackObjectMasterDefinition = 53
    case featureEnableLevel = 54
    case myAvatarID = 59
}
