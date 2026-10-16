import TSOContent
import TSOFiles

/// Reads and writes SimAntics variables by scope and index.
///
/// Ports FreeSO's `VMMemory`. Scopes take a raw byte, as operands store them; a byte
/// with no ``VariableScope`` fails as it does in 2017. Each scope either behaves as
/// in 2017, fails as 2017 does (``SimAnticsError/simantics(_:)`` and the other
/// 2017 failures), or throws ``SimAnticsError/unsupported(_:)`` because what it
/// reads (Sims, slots, rooms, the clock, object definitions) isn't ported yet.
public enum VMMemory {
    // MARK: 16-bit variables

    /// A variable's value, as `VMMemory.GetVariable` reads it.
    public static func value(scope rawScope: UInt8, data: Int16, in frame: StackFrame) throws(SimAnticsError) -> Int16 {
        guard let scope = VariableScope(rawValue: rawScope) else { throw .simantics("Unknown get variable") }
        let thread = frame.thread
        switch scope {
        case .myObjectAttributes:
            return try caller(of: frame).attribute(at: UInt16(bitPattern: data))
        case .stackObjectAttributes:
            return try stackObject(of: frame).attribute(at: UInt16(bitPattern: data))
        case .targetObjectAttributes, .targetObject:
            throw .simantics("Target Object is Deprecated!")
        case .myObject:
            return try caller(of: frame).value(of: data)
        case .stackObject:
            return try stackObject(of: frame).value(of: data)
        case .global:
            return try frame.vm.globalValue(at: UInt16(bitPattern: data))
        case .literal:
            return data
        case .temps:
            return try element(thread.tempRegisters, data, "temp")
        case .parameters:
            return try element(frame.arguments, data, "parameter")
        case .stackObjectID:
            return frame.stackObjectID
        case .tempByTemp:
            return try element(thread.tempRegisters, try element(thread.tempRegisters, data, "temp"), "temp")
        case .treeAdRange, .tsoStandardTime, .moneyOverHead32Bit, .myAvatarID, .neighborhoodData,
             .myTypeAttribute, .stackObjectTypeAttribute:
            return 0 // type attributes are The Sims 1 only
        case .featureEnableLevel:
            return 1
        case .stackObjectTemp, .treeAdPersonalityVariable, .treeAdMinimum, .myLeadTile, .stackObjectLeadTile:
            throw .simantics("Not implemented...")
        case .neighborInStackObject, .neighborPersonData, .jobData, .neighborsObjectDefinition:
            throw .simantics("Only valid in TS1.")
        case .myMotives, .myPersonData:
            try simOnly(frame.caller) { data }
        case .stackObjectMotives, .stackObjectPersonData:
            try simOnly(frame.stackObject) { data }
        case .stackObjectMotiveByTemp, .stackObjectPersonDataByTemp:
            try simOnly(frame.stackObject) { () throws(SimAnticsError) in try element(thread.tempRegisters, data, "temp") }
        case .myPersonDataByTemp:
            try simOnly(frame.caller) { () throws(SimAnticsError) in try element(thread.tempRegisters, data, "temp") }
        case .roomByTemp0:
            switch data {
            case 0: return 100 // ambient light
            case 2: return 0   // level
            case 1, 3, 4: throw .unsupported("room data \(data) needs rooms")
            default: throw .simantics("Invalid room data!")
            }
        case .dynamicSpriteFlagForTempOfStackObject:
            let target = frame.stackObject
            let index = try element(thread.tempRegisters, data, "temp")
            guard let target else { throw .nullReference("no stack object") }
            return target.isDynamicSpriteFlagSet(UInt16(bitPattern: index)) ? 1 : 0
        case .cityTime, .gameTime:
            let clock = frame.vm.clock
            switch data {
            case 0: return Int16(truncatingIfNeeded: clock.seconds)
            case 1: return Int16(truncatingIfNeeded: clock.minutes)
            case 2: return Int16(truncatingIfNeeded: clock.hours)
            case 3: return Int16(truncatingIfNeeded: clock.timeOfDay)
            default: throw .simantics("Unknown get variable")
            }
        case .stackObjectDefinition:
            return try DefinitionVariable.value(data, of: try stackObject(of: frame).object.definition)
        case .stackObjectMasterDefinition:
            let target = try stackObject(of: frame)
            return try DefinitionVariable.value(data, of: target.masterDefinition ?? target.object.definition)
        case .stackObjectFunction:
            guard let entryPoints = try stackObject(of: frame).entryPoints else { throw .nullReference("no entry point table") }
            guard data >= 0, Int(data) < entryPoints.count else { throw .indexOutOfRange("entry point \(data)") }
            return Int16(bitPattern: entryPoints[Int(data)].actionFunction)
        case .stackObjectSlot, .stackObjectLeadTileAttribute:
            _ = try stackObject(of: frame)
            throw .unsupported("reading scope \(scope) needs slots or multi-tile groups")
        case .stackObjectAttributeByParameter:
            let index = try element(frame.arguments, data, "parameter")
            return try stackObject(of: frame).attribute(at: UInt16(bitPattern: index))
        case .local:
            return try element(frame.locals, data, "local")
        case .tuning:
            return try tuningValue(UInt16(bitPattern: data), in: frame)
        case .localByTemp:
            return try element(frame.locals, try element(thread.tempRegisters, data, "temp"), "local")
        case .stackObjectAttributeByTemp:
            let index = try element(thread.tempRegisters, data, "temp")
            return try stackObject(of: frame).attribute(at: UInt16(bitPattern: index))
        case .tempXL:
            throw .simantics("Caller function does not support TempXL!")
        case .myList:
            return try listValue(of: try caller(of: frame), data: data)
        case .stackObjectList:
            guard let entity = frame.stackObject else { return 0 }
            return try listValue(of: entity, data: data)
        default:
            throw .unsupported("reading scope \(scope)")
        }
    }

    /// Sets a variable, as `VMMemory.SetVariable` does. Returns `false` for scopes that can't be set.
    @discardableResult
    public static func setValue(_ value: Int16, scope rawScope: UInt8, data: Int16,
                                in frame: StackFrame) throws(SimAnticsError) -> Bool {
        guard let scope = VariableScope(rawValue: rawScope) else { throw .simantics("Unknown scope for set variable!") }
        let thread = frame.thread
        switch scope {
        case .myObjectAttributes:
            try caller(of: frame).setAttribute(value, at: UInt16(bitPattern: data))
            return true
        case .stackObjectAttributes:
            try stackObject(of: frame).setAttribute(value, at: UInt16(bitPattern: data))
            return true
        case .targetObjectAttributes, .targetObject:
            throw .simantics("Target Object is Deprecated!")
        case .myObject:
            return try caller(of: frame).setValue(value, of: data)
        case .stackObject:
            return try stackObject(of: frame).setValue(value, of: data)
        case .global:
            try frame.vm.setGlobalValue(value, at: UInt16(bitPattern: data))
            return true
        case .literal, .treeAdRange, .stackObjectDefinition, .tuning, .treeAdPersonalityVariable, .treeAdMinimum,
             .stackObjectFunction, .neighborsObjectDefinition, .cityTime, .tsoStandardTime, .gameTime,
             .myLeadTile, .stackObjectLeadTile, .stackObjectMasterDefinition, .myAvatarID:
            return false
        case .temps:
            thread.tempRegisters[try index(data, in: thread.tempRegisters, "temp")] = value
            return true
        case .parameters:
            frame.arguments[try index(data, in: frame.arguments, "parameter")] = value
            return true
        case .stackObjectID:
            frame.stackObjectID = value
            return true
        case .tempByTemp:
            let target = try element(thread.tempRegisters, data, "temp")
            thread.tempRegisters[try index(target, in: thread.tempRegisters, "temp")] = value
            return true
        case .stackObjectTemp, .roomByTemp0, .neighborInStackObject, .neighborPersonData, .jobData,
             .neighborhoodData, .tempXL, .myList, .stackObjectList, .featureEnableLevel, .stackObjectSlot, .mySlot:
            throw .simantics("Not implemented...")
        case .myMotives, .myPersonData:
            try simOnly(frame.caller) { data }
        case .stackObjectMotives, .stackObjectPersonData:
            try simOnly(frame.stackObject) { data }
        case .stackObjectMotiveByTemp, .stackObjectPersonDataByTemp:
            try simOnly(frame.stackObject) { () throws(SimAnticsError) in try element(thread.tempRegisters, data, "temp") }
        case .myPersonDataByTemp:
            try simOnly(frame.caller) { () throws(SimAnticsError) in try element(thread.tempRegisters, data, "temp") }
        case .dynamicSpriteFlagForTempOfStackObject:
            let target = frame.stackObject
            let index = try element(thread.tempRegisters, data, "temp")
            guard let target else { throw .nullReference("no stack object") }
            target.setDynamicSpriteFlag(UInt16(bitPattern: index), to: value > 0)
            return true
        case .stackObjectLeadTileAttribute:
            _ = try stackObject(of: frame)
            throw .unsupported("writing scope \(scope) needs multi-tile groups")
        case .stackObjectAttributeByParameter:
            let attribute = try element(frame.arguments, data, "parameter")
            try stackObject(of: frame).setAttribute(value, at: UInt16(bitPattern: attribute))
            return true
        case .local:
            frame.locals[try index(data, in: frame.locals, "local")] = value
            return true
        case .myTypeAttribute, .stackObjectTypeAttribute, .moneyOverHead32Bit:
            return true // type attributes are The Sims 1 only; TSO ignores the write
        case .localByTemp:
            let target = try element(thread.tempRegisters, data, "temp")
            frame.locals[try index(target, in: frame.locals, "local")] = value
            return true
        case .stackObjectAttributeByTemp:
            let attribute = try element(thread.tempRegisters, data, "temp")
            try stackObject(of: frame).setAttribute(value, at: UInt16(bitPattern: attribute))
            return true
        default:
            throw .unsupported("writing scope \(scope)")
        }
    }

    // MARK: 32-bit variables

    /// A variable as a 32-bit value; only `TempXL` holds more than 16 bits (`GetBigVariable`).
    public static func bigValue(scope rawScope: UInt8, data: Int16, in frame: StackFrame) throws(SimAnticsError) -> Int32 {
        if rawScope == VariableScope.tempXL.rawValue {
            return try element(frame.thread.tempXL, data, "TempXL")
        }
        return Int32(try value(scope: rawScope, data: data, in: frame))
    }

    /// Sets a variable from a 32-bit value, truncating it for 16-bit scopes (`SetBigVariable`).
    @discardableResult
    public static func setBigValue(_ value: Int32, scope rawScope: UInt8, data: Int16,
                                   in frame: StackFrame) throws(SimAnticsError) -> Bool {
        switch VariableScope(rawValue: rawScope) {
        case .tempXL:
            frame.thread.tempXL[try index(data, in: frame.thread.tempXL, "TempXL")] = value
            return true
        case .moneyOverHead32Bit:
            // 2017 casts the caller to a Sim to show the headline; no Sims are ported yet.
            _ = try caller(of: frame)
            throw .invalidCast("the caller isn't a Sim")
        default:
            return try setValue(Int16(truncatingIfNeeded: value), scope: rawScope, data: data, in: frame)
        }
    }

    // MARK: Lists

    /// The entity whose list a scope names (`GetList`).
    public static func listOwner(scope rawScope: UInt8, in frame: StackFrame) throws(SimAnticsError) -> Entity {
        switch VariableScope(rawValue: rawScope) {
        case .myList: return try caller(of: frame)
        case .stackObjectList: return try stackObject(of: frame)
        default: throw .simantics("Cannot get specified variable scope as a list.")
        }
    }

    private static func listValue(of entity: Entity, data: Int16) throws(SimAnticsError) -> Int16 {
        switch data {
        case 0:
            guard let first = entity.list.first else { throw .nullReference("the list is empty") }
            return first
        case 1:
            guard let last = entity.list.last else { throw .nullReference("the list is empty") }
            return last
        case 2:
            return Int16(truncatingIfNeeded: entity.list.count)
        default:
            throw .simantics("Unknown List Accessor")
        }
    }

    // MARK: Tuning

    /// A tuning constant, as `VMMemory.GetTuningVariable` finds it.
    ///
    /// The top 9 bits pick a table, the low 7 a key. Tables 0 to 63 are the code owner's
    /// (ID + 4096), 64 to 127 its semi-global's (ID + 8192, looked up in the owner's file
    /// first), and 128 to 191 the global's (ID + 256); 192 and up are read like the
    /// owner's, unchanged. Each looks for a BCON, then an OTF table. Nothing found is 0.
    public static func tuningValue(_ data: UInt16, in frame: StackFrame) throws(SimAnticsError) -> Int16 {
        var tableID = data >> 7
        let keyID = data & 0x7F
        let owner = frame.codeOwner.resource
        switch tableID {
        case 64..<128:
            tableID -= 64
            if let value = try constant(in: owner, table: tableID + 8192, key: keyID, checked: true) { return value }
            if let semiGlobal = owner.semiGlobal,
               let value = try constant(in: semiGlobal, table: tableID + 8192, key: keyID, checked: true) { return value }
        case 128..<192:
            tableID -= 128
            if let value = try constant(in: frame.vm.global, table: tableID + 256, key: keyID, checked: true) { return value }
        default:
            // The owner's BCONs aren't bounds-checked in 2017.
            if let value = try constant(in: owner, table: tableID &+ 4096, key: keyID, checked: false) { return value }
        }
        return 0
    }

    /// A constant from a BCON, else an OTF table. `checked` skips a BCON too short for the key.
    private static func constant(in resource: some IFFResource, table: UInt16, key: UInt16,
                                 checked: Bool) throws(SimAnticsError) -> Int16? {
        let bcon: BCON?
        do {
            bcon = try resource.chunk(BCON.self, id: table)
        } catch {
            throw .simantics("BCON \(table) doesn't parse: \(error)")
        }
        if let bcon {
            if Int(key) < bcon.constants.count { return Int16(bitPattern: bcon.constants[Int(key)]) }
            if !checked { throw .indexOutOfRange("constant \(key) of BCON \(table)") }
        }
        guard let otfTable = resource.tuningTable(id: table) else { return nil }
        guard let entry = otfTable.key(id: Int32(key)) else { throw .nullReference("key \(key) of tuning table \(table)") }
        return Int16(truncatingIfNeeded: entry.value)
    }

    // MARK: Helpers

    /// A scope only Sims have. 2017 casts the entity to a Sim first, which fails for an
    /// object, then evaluates the index, then calls into the Sim, which fails for none.
    /// No Sims are ported yet, so this always fails.
    private static func simOnly(_ entity: Entity?, index: () throws(SimAnticsError) -> Int16) throws(SimAnticsError) -> Never {
        if entity != nil { throw .invalidCast("the entity isn't a Sim") }
        _ = try index()
        throw .nullReference("no entity")
    }

    private static func caller(of frame: StackFrame) throws(SimAnticsError) -> Entity {
        guard let caller = frame.caller else { throw .nullReference("no caller") }
        return caller
    }

    private static func stackObject(of frame: StackFrame) throws(SimAnticsError) -> Entity {
        guard let stackObject = frame.stackObject else { throw .nullReference("no stack object") }
        return stackObject
    }

    private static func index<Element>(_ position: Int16, in array: [Element], _ name: String) throws(SimAnticsError) -> Int {
        guard position >= 0, Int(position) < array.count else { throw .indexOutOfRange("\(name) \(position)") }
        return Int(position)
    }

    private static func element<Element>(_ array: [Element], _ position: Int16, _ name: String) throws(SimAnticsError) -> Element {
        array[try index(position, in: array, name)]
    }
}
