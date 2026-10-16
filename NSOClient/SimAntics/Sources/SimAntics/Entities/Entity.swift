import TSOContent
import TSOFiles

/// An object on the lot.
///
/// Ports the parts of FreeSO's `VMEntity` and `VMGameObject` that SimAntics variables
/// read and write, and the entity's place in its ``MultitileGroup``. Sims (`VMAvatar`),
/// containers and slots, and interactions aren't ported yet; reading values that need them
/// throws ``SimAnticsError/unsupported(_:)``.
///
/// A known gap in writes, which stores the value but skips a FreeSO side effect: `flags`
/// doesn't recompute the footprint (no routing yet).
public final class Entity {
    public let objectID: Int16
    public let object: GameObject
    public unowned let vm: VM
    /// The 80 object data values (see ``ObjectVariable``).
    public var objectData = [Int16](repeating: 0, count: ObjectVariable.count)
    /// Attributes, grown with zeros whenever an index past the end is read or written, as in FreeSO.
    public private(set) var attributes: [Int16] = []
    /// The entity's list (`MyList`), front first.
    public var list: [Int16] = []
    /// Where the entity is; set it with ``VM/move(_:to:)`` so the tile index follows.
    public internal(set) var position = LotPosition.outOfWorld
    public var direction = Direction.north

    /// What main gets on its first run, set by whoever created the entity: argument 0, when not
    /// 0 (`MainParam`), and the stack object's ID, when not 0 (`MainStackOBJ`). Both are used once.
    public var mainParameter: Int16 = 0
    public var mainStackObjectID: Int16 = 0

    /// Whether the entity was deleted (`Dead`).
    public internal(set) var isDead = false

    /// The object the entity is part of: itself alone, or every part of a multi-tile object.
    public internal(set) var group: MultitileGroup

    /// The lead object of the entity's group (`MultitileGroup.BaseObject`); a lone object leads itself.
    public var leadObject: Entity { group.leadObject ?? self }

    /// For a part of a multi-tile object, the master definition it was created from, which
    /// lot category checks and definition reads through the master scope use.
    public internal(set) var masterDefinition: OBJD?
    /// Which dynamic sprites show: bits 0 to 63, then 64 to 127.
    public var dynamicSpriteFlags: (UInt64, UInt64) = (0, 0)

    /// The routines the entity runs for each entry point (init, main, load, and so on),
    /// or `nil` if its definition uses a function table it doesn't have.
    public let entryPoints: [EntryPoint]?

    private var lockoutTimestamp: UInt32 = 0

    /// The entity's interpreter.
    public private(set) lazy var thread = VMThread(entity: self)

    /// A new entity, as the `VMEntity` constructor builds it: zeroed object data except the
    /// chair-facing flag, and the entry point table.
    /// The entity joins `group`, or a new group of one.
    init(objectID: Int16, object: GameObject, vm: VM, group: MultitileGroup? = nil) throws(SimAnticsError) {
        self.objectID = objectID
        self.object = object
        self.vm = vm
        self.group = group ?? MultitileGroup(isMultiTile: false)
        entryPoints = try Self.entryPoints(of: object)
        objectData[Int(ObjectVariable.flags.rawValue)] |= Self.chairFacingFlag
        self.group.add(self)
    }

    /// `VMEntityFlags.ChairFacing`.
    static let chairFacingFlag: Int16 = 1 << 8

    // MARK: Entry points

    /// An entry in an object's function table.
    public struct EntryPoint: Sendable, Equatable {
        /// The routine that decides whether the entry point may run, or 0.
        public var conditionFunction: UInt16
        /// The routine to run, or 0 for none.
        public var actionFunction: UInt16
    }

    /// The entry points with their indexes in the table.
    public enum EntryPointIndex: Int, Sendable {
        case initialize = 0, main, load, cleanup, queueSkipped, allowIntersection, wallAdjacencyChanged
        case roomChanged, dynamicMultiTileUpdate, place, pickup, userPlace, userPickup, levelInfo
        case servingSurface, portal, gardening, washHands, prepareFood, cookFood, placeOnSurface, dispose
        case eat, pickupFromSlot, washDish, eatingSurface, sit, stand, clean, repair, clientHouseJoin
        case prepareForSale, houseUnload
    }

    /// The table FreeSO builds: from the definition's tree IDs when it doesn't use a function
    /// table, else from the `OBJf` with the definition's chunk ID, if there is one.
    static func entryPoints(of object: GameObject) throws(SimAnticsError) -> [EntryPoint]? {
        let definition = object.definition
        var table: [EntryPoint]?
        if definition.usesFnTable == 0 {
            table = [
                definition.bhavInit, definition.bhavMainID, definition.bhavLoad, definition.bhavCleanup,
                definition.bhavQueueSkipped, definition.bhavAllowIntersectionID, definition.bhavWallAdjacencyChanged,
                definition.bhavRoomChange, definition.bhavDynamicMultiTileUpdate, definition.bhavPlace,
                definition.bhavPickup, definition.bhavUserPlace, definition.bhavUserPickup, definition.bhavLevelInfo,
                definition.bhavServingSurface, definition.bhavPortal, definition.bhavGardeningID,
                definition.bhavWashHandsID, definition.bhavPrepareFoodID, definition.bhavCookFoodID,
                definition.bhavPlaceSurfaceID, definition.bhavDisposeID, definition.bhavEatID,
                definition.bhavPickupFromSlotID, definition.bhavWashDishID, definition.bhavEatSurfaceID,
                definition.bhavSitID, definition.bhavStandID, definition.bhavClean, definition.bhavRepair, 0, 0, 0,
            ].map { EntryPoint(conditionFunction: 0, actionFunction: $0) }
        } else {
            let functionTable: OBJf?
            do {
                functionTable = try object.resource.chunk(OBJf.self, id: definition.id)
            } catch {
                throw .simantics("OBJf \(definition.id) doesn't parse: \(error)")
            }
            table = functionTable?.functions.map { EntryPoint(conditionFunction: $0.conditionFunction, actionFunction: $0.actionFunction) }
        }
        // FreeSO clears entry point 17 of one object by GUID.
        if object.guid == 0xA9BB_3A76 {
            guard var entries = table else { throw .nullReference("no entry point table") }
            guard entries.count > 17 else { throw .indexOutOfRange("entry point 17") }
            entries[17] = EntryPoint(conditionFunction: 0, actionFunction: 0)
            table = entries
        }
        return table
    }

    /// Records the room the entity is in (`SetRoom`), as object data 29.
    func setRoom(_ room: UInt16) {
        objectData[Int(ObjectVariable.room.rawValue)] = Int16(truncatingIfNeeded: room)
    }

    // MARK: Attributes

    public func attribute(at index: UInt16) -> Int16 {
        growAttributes(toInclude: index)
        return attributes[Int(index)]
    }

    public func setAttribute(_ value: Int16, at index: UInt16) {
        growAttributes(toInclude: index)
        attributes[Int(index)] = value
    }

    private func growAttributes(toInclude index: UInt16) {
        if Int(index) >= attributes.count {
            attributes.append(contentsOf: repeatElement(0, count: Int(index) + 1 - attributes.count))
        }
    }

    // MARK: Running

    /// Why the object is disabled (`VMGameObjectDisableFlags`), or 0.
    public var disabledFlags: UInt8 = 0
    /// `VMGameObjectDisableFlags.LotCategoryWrong`: the lot's category isn't one the object allows.
    public static let lotCategoryWrong: UInt8 = 1 << 2

    /// Whether the entity runs every tick however long it idles: Sims, objects with a headline
    /// or a sound (neither ported yet), and disabled objects.
    public var runsEveryTick: Bool { disabledFlags != 0 }

    private var isResetting = false

    /// Runs an entry point, as `VMEntity.ExecuteEntryPoint` does.
    ///
    /// Run immediately, the routine runs to completion on a check thread and this returns
    /// whether it returned true. Otherwise it's pushed onto the entity's thread and this
    /// returns false. An entry point with no routine (an action of 255 or less) does nothing.
    @discardableResult
    public func executeEntryPoint(_ entry: EntryPointIndex, runImmediately: Bool, stackObject: Entity? = nil,
                                  arguments: [Int16]? = nil) throws(SimAnticsError) -> Bool {
        try executeEntryPoint(at: entry.rawValue, runImmediately: runImmediately, stackObject: stackObject,
                              arguments: arguments)
    }

    @discardableResult
    public func executeEntryPoint(at index: Int, runImmediately: Bool, stackObject: Entity? = nil,
                                  arguments: [Int16]? = nil) throws(SimAnticsError) -> Bool {
        // Entry point 11 (user placement) also fixes floors under stairs in FreeSO; entities have
        // no position yet, which skips that in FreeSO too.
        guard let table = entryPoints else { throw .nullReference("no entry point table") }
        guard index < table.count, table[index].actionFunction > 255,
              let routine = try vm.routine(opcode: table[index].actionFunction, codeOwner: object) else { return false }
        let frame = StackFrame(thread: thread, routine: routine, caller: self, callee: self, codeOwner: object)
        frame.stackObject = stackObject
        frame.arguments = arguments ?? [0, 0, 0, 0]
        if runImmediately {
            return VMThread.evaluateCheck(entity: self, frame: frame) == .returnTrue
        }
        thread.push(frame)
        return false
    }

    /// Starts the entity, as `VMGameObject.Init` does: schedules it, runs init to completion,
    /// pushes main (with ``mainParameter`` and ``mainStackObjectID``), then disables it if the lot's category isn't one its definition allows.
    public func initialize() throws(SimAnticsError) {
        vm.scheduler.scheduleTick(for: self, in: 1)
        try executeEntryPoint(.initialize, runImmediately: true)
        var arguments: [Int16]?
        if mainParameter != 0 {
            arguments = [mainParameter, 0, 0, 0]
            mainParameter = 0
        }
        var stackObject: Entity?
        if mainStackObjectID != 0 {
            stackObject = vm.entity(id: mainStackObjectID)
            mainStackObjectID = 0
        }
        try executeEntryPoint(.main, runImmediately: false, stackObject: stackObject, arguments: arguments)
        let categories = (masterDefinition ?? object.definition).lotCategories
        if categories > 0 && Int(categories) & (1 << (Int(vm.propertyCategory) & 31)) == 0 {
            disabledFlags |= Self.lotCategoryWrong
        } else {
            disabledFlags &= ~Self.lotCategoryWrong
        }
    }

    /// Restarts the entity, as `VMEntity.Reset` does: clears its stack, runs its reset entry point
    /// (cleanup) to completion if it has one, pushes main, and schedules it for the next tick.
    ///
    /// FreeSO treats an error here as fatal; this reports it and carries on.
    public func reset() {
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }
        thread.stack.removeAll()
        do throws(SimAnticsError) {
            guard let table = entryPoints else { throw .nullReference("no entry point table") }
            guard table.count > EntryPointIndex.cleanup.rawValue else { throw .indexOutOfRange("entry point 3") }
            if table[EntryPointIndex.cleanup.rawValue].actionFunction != 0 {
                try executeEntryPoint(.cleanup, runImmediately: true)
            }
            try executeEntryPoint(.main, runImmediately: false)
        } catch {
            vm.report(error, by: self)
        }
        vm.scheduler.descheduleTick(for: self)
        vm.scheduler.scheduleTick(for: self, in: 1)
    }

    /// Runs one scheduled tick, as `VMEntity.Tick` does; an entity that didn't schedule itself runs next tick.
    func tick() {
        thread.scheduledTick = 0
        thread.instructionsThisTick = 0
        thread.tick()
        if thread.scheduledTick == 0 { vm.scheduler.scheduleTick(for: self, in: 1) }
    }

    // MARK: Dynamic sprites

    /// Shifts are C#'s for `ulong`: the count is masked to 6 bits.
    public func isDynamicSpriteFlagSet(_ index: UInt16) -> Bool {
        index > 63 ? dynamicSpriteFlags.1 & Self.bit(Int(index) - 64) != 0 : dynamicSpriteFlags.0 & Self.bit(Int(index)) != 0
    }

    public func setDynamicSpriteFlag(_ index: UInt16, to isSet: Bool) {
        if index > 63 {
            dynamicSpriteFlags.1 = isSet ? dynamicSpriteFlags.1 | Self.bit(Int(index) - 64) : dynamicSpriteFlags.1 & ~Self.bit(Int(index) - 64)
        } else {
            dynamicSpriteFlags.0 = isSet ? dynamicSpriteFlags.0 | Self.bit(Int(index)) : dynamicSpriteFlags.0 & ~Self.bit(Int(index))
        }
    }

    private static func bit(_ shift: Int) -> UInt64 {
        1 << UInt64(shift & 63)
    }

    // MARK: Object data

    /// An object data value, as `VMEntity.GetValue` reads it.
    public func value(of variable: Int16) throws(SimAnticsError) -> Int16 {
        switch ObjectVariable(rawValue: variable) {
        case .objectID:
            return objectID
        case .direction:
            return Int16(direction.notch)
        case .containerID, .parentID, .slotNumber, .slotCount:
            throw .unsupported("object data \(variable) needs containers and slots")
        case .useCount:
            throw .unsupported("object data \(variable) needs interactions")
        case .lockoutCount:
            let currentTick = vm.scheduler.currentTick
            if lockoutTimestamp > currentTick { lockoutTimestamp = 0 } // lockouts in the future are invalid
            let remaining = Int64(objectData[Int(variable)]) - Int64(currentTick - lockoutTimestamp)
            return Int16(truncatingIfNeeded: max(remaining, 0))
        default:
            return objectData[try Self.storageIndex(variable)]
        }
    }

    /// Sets an object data value, as `VMEntity.SetValue` does. Always returns `true`, as in FreeSO.
    @discardableResult
    public func setValue(_ value: Int16, of variable: Int16) throws(SimAnticsError) -> Bool {
        var value = value
        switch ObjectVariable(rawValue: variable) {
        case .direction:
            // The stored value is the notch; the facing snaps to the object's rotation step.
            value = Int16((Int(value) + 65536) % 8)
            let step = objectData[Int(ObjectVariable.rotationNotches.rawValue)]
            direction = Direction(notch: Int(step > 1 ? value - value % step : value))
        case .lockoutCount:
            lockoutTimestamp = vm.scheduler.currentTick
        case .fsoEngineQuery where value == 1:
            throw .unsupported("the safe-to-delete query needs interactions")
        case .category:
            vm.changeCategory(of: self, from: objectData[Int(ObjectVariable.category.rawValue)], to: value)
        default:
            break
        }
        objectData[try Self.storageIndex(variable)] = value
        return true
    }

    private static func storageIndex(_ variable: Int16) throws(SimAnticsError) -> Int {
        if variable > 79 { throw .simantics("Object Data out of range!") }
        if variable < 0 { throw .indexOutOfRange("object data \(variable)") }
        return Int(variable)
    }
}
