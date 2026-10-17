import TSOContent
import TSOFiles

/// One running lot.
///
/// Ports the core of FreeSO's `VM` and `VMContext`: entities, the global state, the
/// random generator, the primitive table, routine assembly, and the lot's architecture and
/// rooms. Networking comes in a later pass.
public final class VM {
    /// Global state values, the `Global` scope.
    public var globalState: [Int16]
    public var random: VMRandom
    public var clock = VMClock()
    /// The lot's category (`VMTSOLotState.PropertyCategory`), which some objects require.
    public var propertyCategory: UInt8 = 0
    public let content: GameContent
    /// The global every object can call.
    public let global: GlobalResource
    public let primitives: PrimitiveTable
    public let scheduler = VMScheduler()
    /// Entities in the order they were added.
    public private(set) var entities: [Entity] = []

    /// Errors FreeSO would show in a "SimAntics Exception" dialog, oldest first.
    public private(set) var reportedErrors: [ReportedError] = []

    /// An error a thread hit, and which entity and tick it was on.
    public struct ReportedError: Sendable, Equatable {
        public var objectID: Int16
        public var tick: UInt32
        public var error: SimAnticsError
    }

    private var entitiesByID: [Int16: Entity] = [:]
    /// Where the search for a free object ID starts (`VM.ObjectId`).
    private var lowestFreeObjectID: Int16 = 1
    /// The lot's walls, floors, and rooms. Changes take effect on the next tick, when rooms are
    /// regenerated and every entity's room is updated. Replacing the architecture doesn't
    /// re-index entities already on the lot.
    public var architecture: Architecture
    /// The lot's size in tiles; the tile index numbers tiles by it.
    public var lotSize: (width: Int, height: Int) { (architecture.width, architecture.height) }
    /// Objects by tile, in object ID order (`VMObjectQueries.TileToObjects`), keyed as FreeSO does.
    private var tileIndex: [Int: [Entity]] = [:]
    /// Objects by category, in object ID order (`VMObjectQueries.ObjectsByCategory`). A created
    /// object is listed under its category at once (usually 0) and moves when object data sets it;
    /// one added with ``addObject(guid:id:)`` is listed only once its category is set.
    private var categoryIndex: [Int16: [Entity]] = [:]
    /// Each room's entities, in object ID order (`VMRoomInfo.Entities`), for the rooms of
    /// `roomListsGeneration`.
    private var roomEntitiesStorage: [[Entity]] = []
    private var roomListsGeneration: Architecture.Generation?
    private var roomEntities: [[Entity]] {
        get {
            if roomListsGeneration !== architecture.generation { rebuildRoomLists() }
            return roomEntitiesStorage
        }
        set {
            if roomListsGeneration !== architecture.generation { rebuildRoomLists() }
            roomEntitiesStorage = newValue
        }
    }
    private var nextTickID: UInt32 = 1
    private var routines: [RoutineKey: Routine] = [:]

    private struct RoutineKey: Hashable {
        var file: String
        var id: UInt16
    }

    /// A lot with no entities.
    ///
    /// - Throws: ``SimAnticsError/content(_:)`` if the global can't be loaded.
    public init(content: GameContent, seed: UInt64, primitives: PrimitiveTable = .standard) throws(SimAnticsError) {
        self.content = content
        self.primitives = primitives
        random = VMRandom(seed: seed)
        do {
            global = try content.global()
        } catch {
            throw .content(error)
        }
        architecture = try Architecture(width: 64, height: 64)
        globalState = [Int16](repeating: 0, count: 38)
        globalState[20] = 255 // game edition: every expansion
        globalState[25] = 4   // needed for Sims' idle interactions, as in EA-Land's globals
        globalState[17] = 4   // runtime code version
    }

    /// A blueprint object ``load(_:)`` left out, and why.
    public struct LeftOut: Sendable, Equatable {
        public var object: Blueprint.Object
        public var reason: String
    }

    /// Loads a lot as the lot server does (`VMBlueprintRestoreCmd`, then
    /// `VMWorldActivator.LoadFromXML`).
    ///
    /// The job level (global 11) is set to -1, then come the walls and floors, with rooms, and
    /// every entity already on the lot goes in its room. Each of the blueprint's objects follows, in
    /// order: created out of the world, which runs its init; placed on its tile if its level isn't
    /// 0, accepting slots (a placement that fails leaves it out of the world, since FreeSO ignores
    /// the result); given the blueprint's group ID, if any, on every part; and every part runs its
    /// user placement entry point at once. Last, rooms are regenerated if the objects changed them.
    ///
    /// The lot server loads in the tick the command arrives in, so that tick runs next: call
    /// ``tick()`` once to be where FreeSO is after loading.
    ///
    /// Differences from FreeSO, to keep loading: FreeSO starts the lot over with no entities, where
    /// this keeps the ones already added. And an object the content doesn't have, or can't load, is
    /// left out and returned, where FreeSO fails.
    ///
    /// - Throws: ``SimAnticsError/simantics(_:)`` if the blueprint is off the lot, and any error
    ///   an object's init or entry point throws.
    @discardableResult
    public func load(_ blueprint: Blueprint) throws(SimAnticsError) -> [LeftOut] {
        globalState[11] = -1
        do {
            architecture = try blueprint.architecture()
        } catch {
            throw .simantics("can't load the blueprint: \(error)")
        }
        updateRooms()

        var leftOut: [LeftOut] = []
        for object in blueprint.objects {
            let group: MultitileGroup?
            do {
                group = try createObject(guid: object.guid, facing: object.direction)
            } catch .content(let error) {
                leftOut.append(LeftOut(object: object, reason: "can't load it: \(error)"))
                continue
            }
            guard let group, !group.objects.isEmpty else {
                leftOut.append(LeftOut(object: object, reason: "the content has no such object"))
                continue
            }
            if object.level != 0 {
                let tile = LotPosition.center(ofTileX: Int16(truncatingIfNeeded: object.x), y: Int16(truncatingIfNeeded: object.y),
                                              level: Int8(truncatingIfNeeded: object.level))
                try place(group, at: tile, facing: object.direction, flags: .acceptSlots)
            }
            if object.group != 0 {
                for part in group.objects {
                    _ = try part.setValue(Int16(truncatingIfNeeded: object.group), of: Int16(ObjectVariable.groupID.rawValue))
                }
            }
            for part in group.objects { try part.executeEntryPoint(.userPlace, runImmediately: true) }
        }
        if architecture.isDirty {
            architecture.regenerateRooms()
            updateRooms()
        }
        return leftOut
    }

    deinit {
        // Frames hold entities and entities hold their threads; break the cycles.
        for entity in entities {
            entity.thread.stack.removeAll()
            entity.group.removeAll()
        }
    }

    public func entity(id: Int16) -> Entity? {
        entitiesByID[id]
    }

    /// Adds an object with a given ID.
    ///
    /// A first step toward FreeSO's object creation: the entity is built as the `VMEntity`
    /// constructor builds it, out of the world, and runs nothing until ``Entity/initialize()``.
    /// Placement, multi-tile groups, and catalog prices come later.
    ///
    /// - Throws: ``SimAnticsError/nullReference(_:)`` if the content has no object with
    ///   the GUID, ``SimAnticsError/simantics(_:)`` if the ID is taken or 0.
    @discardableResult
    public func addObject(guid: UInt32, id: Int16) throws(SimAnticsError) -> Entity {
        guard id != 0, entitiesByID[id] == nil else { throw .simantics("object ID \(id) is not free") }
        guard let object = try gameObject(guid: guid) else {
            throw .nullReference("no object with GUID \(String(guid, radix: 16))")
        }
        let entity = try Entity(objectID: id, object: object, vm: self)
        register(entity)
        return entity
    }

    /// Creates an object, as `VMContext.CreateObjectInstance` does, and returns its group, or `nil`
    /// if the content has no object with the GUID.
    ///
    /// A multi-tile master definition creates one entity per part (each definition in the
    /// master's file with the same master ID and a sub-index), in file order; anything else creates
    /// one entity. Every entity gets the lowest free object ID, then each is initialized in turn
    /// (``Entity/initialize()``, with the main parameter and stack object given), then the group
    /// is placed (``place(_:at:facing:flags:)``). If it doesn't fit, it stays out of the world.
    ///
    /// - Throws: ``SimAnticsError/unsupported(_:)`` for a Sim; any error an entry point throws.
    @discardableResult
    public func createObject(guid: UInt32, at position: LotPosition = .outOfWorld, facing direction: Direction = .north,
                             mainStackObjectID: Int16 = 0, mainParameter: Int16 = 0) throws(SimAnticsError) -> MultitileGroup? {
        guard let object = try gameObject(guid: guid) else { return nil }
        let definition = object.definition
        guard definition.knownObjectType != .person else { throw .unsupported("creating a Sim needs Sims") }

        let group: MultitileGroup
        if definition.masterID != 0 && definition.subIndex == -1 {
            group = MultitileGroup(isMultiTile: true)
            let parts: [OBJD]
            do {
                parts = try object.resource.chunks(OBJD.self)
            } catch {
                throw .simantics("the object's definitions don't parse: \(error)")
            }
            for part in parts where part.masterID == definition.masterID && part.subIndex != -1 {
                guard let partObject = try gameObject(guid: part.guid) else { continue }
                let entity = try Entity(objectID: freeObjectID(), object: partObject, vm: self, group: group)
                entity.masterDefinition = definition
                register(entity)
                listUnderCategory(entity)
            }
        } else {
            group = MultitileGroup(isMultiTile: false)
            let entity = try Entity(objectID: freeObjectID(), object: object, vm: self, group: group)
            register(entity)
            listUnderCategory(entity)
        }

        for entity in group.objects {
            entity.mainStackObjectID = mainStackObjectID
            entity.mainParameter = mainParameter
        }
        for entity in group.objects { try entity.initialize() }
        // FreeSO ignores whether this worked; an object that didn't fit stays out of the world.
        try place(group, at: position, facing: direction)
        return group
    }

    /// Deletes an entity, or with `wholeGroup`, every part of its object (`VMEntity.Delete`).
    ///
    /// While entities are running, deletion waits until the tick ends, after the random seed
    /// advances. A deleted entity leaves the entity list, the queries, the schedule, and its group,
    /// and its object ID becomes free again. Deleting one twice does nothing. What it held leaves
    /// its slots and is placed nearby, or out of the world if it was out of the world.
    ///
    /// - Throws: any error an entry point throws while placing what it held.
    public func delete(_ entity: Entity, wholeGroup: Bool = false) throws(SimAnticsError) {
        if wholeGroup {
            for part in entity.group.objects { try delete(part) }
            return
        }
        guard !entity.isDead else { return }
        if scheduler.isRunning {
            scheduler.deleteAtEndOfTick(entity)
            return
        }
        entity.isDead = true
        leavePosition(entity)
        removeFromCategoryIndex(entity)
        if let index = entities.firstIndex(where: { $0 === entity }) {
            entities.remove(at: index)
            entitiesByID[entity.objectID] = nil
            scheduler.descheduleTick(for: entity)
            lowestFreeObjectID = min(lowestFreeObjectID, entity.objectID)
        }
        entity.group.remove(entity)
        // What it held goes out of the world, then, if the deleted object was on the lot, to the
        // nearest spot that fits (FreeSO moves the deleted object to each one's position first).
        for index in 0..<entity.totalSlots {
            guard let held = entity.slot(index) else { continue }
            entity.position = held.position
            try place(held.group, at: .outOfWorld, facing: held.direction)
            if !entity.position.isOutOfWorld { _ = try findLocation(for: held, near: entity, flags: []) }
        }
        // A deleted entity never runs again; dropping its stack breaks the frames' references to it.
        entity.thread.stack.removeAll()
    }

    /// `VMFindLocationFor.FindLocationFor`: places an object at the reference's position in each
    /// compass facing, then on rings of tiles around it, out to nine tiles, and returns whether
    /// one fit.
    ///
    /// - Throws: any error an entry point throws.
    func findLocation(for object: Entity, near reference: Entity, flags: PlaceRequestFlags) throws(SimAnticsError) -> Bool {
        let base = reference.position
        for facing in [Direction.north, .east, .south, .west] {
            if try place(object.group, at: base, facing: facing, flags: flags).status == .success { return true }
        }
        for ring in 1..<10 {
            func tile(_ dx: Int, _ dy: Int) -> LotPosition {
                .center(ofTileX: Int16(truncatingIfNeeded: Int(base.tileX) + dx),
                        y: Int16(truncatingIfNeeded: Int(base.tileY) + dy), level: base.level)
            }
            for dx in -ring...ring {
                for j in 0..<8 {
                    let position = tile(dx, (j % 2 * 2 - 1) * ring)
                    if try place(object.group, at: position, facing: Direction(notch: j / 2 * 2), flags: flags).status == .success {
                        return true
                    }
                }
            }
            for dy in (1 - ring)..<ring {
                for j in 0..<8 {
                    let position = tile((j % 2 * 2 - 1) * ring, dy)
                    if try place(object.group, at: position, facing: Direction(notch: j / 2 * 2), flags: flags).status == .success {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Puts entities already on the lot into one new group, in the order given, as a saved lot
    /// or a test's rebuilt lot needs (`VMMultitileGroup.Load`). Each leaves its old group.
    func regroup(_ parts: [Entity], isMultiTile: Bool, masterDefinition: OBJD?) {
        let group = MultitileGroup(isMultiTile: isMultiTile)
        for entity in parts {
            entity.group.remove(entity)
            entity.group = group
            entity.masterDefinition = masterDefinition
            group.add(entity)
        }
    }

    private func gameObject(guid: UInt32) throws(SimAnticsError) -> GameObject? {
        do {
            return try content.objects.object(guid: guid)
        } catch {
            throw .content(error)
        }
    }

    private func register(_ entity: Entity) {
        VMScheduler.insertInObjectIDOrder(entity, into: &entities)
        entitiesByID[entity.objectID] = entity
    }

    /// The lowest free object ID from the last one given out (`VM.NextObjID`), which can't be 0.
    private func freeObjectID() throws(SimAnticsError) -> Int16 {
        var id = lowestFreeObjectID
        while entitiesByID[id] != nil {
            guard id < .max else { throw .simantics("no free object ID") }
            id += 1
        }
        lowestFreeObjectID = id
        return id
    }

    // MARK: Ticking

    /// Advances the lot one tick, as the server driver and `VM.InternalTick` do: the clock moves,
    /// the clock globals are copied, and the scheduled entities run. Tick IDs start at 1.
    public func tick() {
        let tick = nextTickID
        nextTickID &+= 1
        scheduler.beginTick(tick)
        clock.tick()
        globalState[6] = Int16(truncatingIfNeeded: clock.seconds)
        globalState[5] = Int16(truncatingIfNeeded: clock.minutes)
        globalState[0] = Int16(truncatingIfNeeded: clock.hours)
        globalState[4] = Int16(truncatingIfNeeded: clock.timeOfDay)
        if architecture.isDirty {
            // Architecture.Tick, then WallsChanged's RegeneratePortalInfo.
            architecture.regenerateRooms()
            updateRooms()
        }
        scheduler.runTick(self)
    }

    func report(_ error: SimAnticsError, by entity: Entity) {
        reportedErrors.append(ReportedError(objectID: entity.objectID, tick: scheduler.currentTick, error: error))
    }

    // MARK: Queries

    /// Objects with a GUID, in object ID order, or `nil` if there are none (`GetObjectsByGUID`).
    public func objects(withGUID guid: UInt32) -> [Entity]? {
        let matches = entities.filter { $0.object.guid == guid }
        return matches.isEmpty ? nil : matches
    }

    /// Objects listed under `category`, in object ID order, or `nil` if there are none.
    public func objects(inCategory category: Int16) -> [Entity]? {
        categoryIndex[category]
    }

    /// Objects on a tile, in object ID order, or `nil` if there are none (`GetObjectsAt`).
    /// Every object out of the world shares one entry.
    public func objects(at position: LotPosition) -> [Entity]? {
        tileIndex[tileKey(position)]
    }

    /// Moves an entity without checking whether it fits, as loading a saved lot does: it leaves its
    /// old place (footprint, room, tile, walls), then takes the new one, as FreeSO's position change
    /// does, but without running the placement entry point. To place an object as the game does,
    /// use ``place(_:at:facing:flags:)``.
    ///
    /// - Throws: any error a dynamic multi-tile entry point throws.
    public func move(_ entity: Entity, to position: LotPosition) throws(SimAnticsError) {
        leavePosition(entity)
        entity.position = position
        try takePosition(entity, runsPlacementEntryPoint: false)
    }

    /// Places every part of a group, as `VMMultitileGroup.ChangePosition` does.
    ///
    /// Each part's offset is turned to the facing (a quarter turn per compass point; the diagonals
    /// count as north) around the lead part, and each must pass ``Entity/placement(at:facing:flags:)``.
    /// If one fails, every part goes back where it was, and the failure is returned. Otherwise each
    /// moves and faces the new way, then each takes its place: room, footprint, walls, and the
    /// placement entry point.
    ///
    /// - Throws: any error an entry point throws.
    @discardableResult
    public func place(_ group: MultitileGroup, at position: LotPosition, facing direction: Direction,
                      flags: PlaceRequestFlags = []) throws(SimAnticsError) -> PlacementResult {
        guard Int(position.level) <= Architecture.stories else { return PlacementResult(.notAllowedOnFloor) }
        guard !group.objects.isEmpty, let lead = group.leadObject,
              let leadIndex = group.objects.firstIndex(where: { $0 === lead }) else { return PlacementResult() }
        let parts = group.objects
        let oldContainers = parts.map { ($0.container, Int($0.containerSlot)) }
        for part in parts { leavePosition(part) }

        let leadOffset = group.offsets[leadIndex]
        var targets: [LotPosition] = []
        var results: [PlacementResult] = []
        for (part, offset) in zip(parts, group.offsets) {
            guard !position.isOutOfWorld else {
                targets.append(.outOfWorld)
                results.append(PlacementResult())
                continue
            }
            let (dx, dy) = Self.turn(x: Int(offset.x) - Int(leadOffset.x), y: Int(offset.y) - Int(leadOffset.y),
                                     quarterTurns: direction.wallOffset)
            let target = LotPosition(x: Int16(truncatingIfNeeded: Int(position.x) + dx),
                                     y: Int16(truncatingIfNeeded: Int(position.y) + dy),
                                     level: Int8(truncatingIfNeeded: Int(position.level) + Int(offset.level)))
            let result = try part.placement(at: target, facing: direction, flags: flags)
            guard result.status == .success else {
                // Back to where they were, slots included.
                for (part, (oldContainer, oldSlot)) in zip(parts, oldContainers) {
                    if let oldContainer { try oldContainer.placeInSlot(part, slot: oldSlot, cleanOld: false) }
                    try takePosition(part, runsPlacementEntryPoint: true)
                }
                return result
            }
            targets.append(target)
            results.append(result)
        }
        for (part, (target, result)) in zip(parts, zip(targets, results)) {
            // `SetIndivPosition`: an object stacked onto another goes in its first slot.
            part.direction = direction
            part.position = target
            if let base = result.object { try base.placeInSlot(part, slot: 0, cleanOld: false) }
        }
        for part in parts { try takePosition(part, runsPlacementEntryPoint: true) }
        return PlacementResult()
    }

    /// An offset turned clockwise by quarter turns, as FreeSO's rotation matrix turns it (exactly,
    /// where FreeSO rounds a float rotation).
    private static func turn(x: Int, y: Int, quarterTurns: Int) -> (Int, Int) {
        switch quarterTurns {
        case 1: (-y, x)
        case 2: (-x, -y)
        case 3: (y, -x)
        default: (x, y)
        }
    }

    /// The entities in a room, in object ID order (`VMRoomInfo.Entities`), or none for an unknown room.
    func entities(inRoom room: UInt16) -> [Entity] {
        Int(room) < roomEntities.count ? roomEntities[Int(room)] : []
    }

    /// `VMGameObject.PrePositionChange`: the entity leaves its place. Its footprint goes, it leaves
    /// its room and tile, and its container's slot if it's in one; otherwise, in the world, a door
    /// or window takes its style off the walls and the object stops using them.
    func leavePosition(_ entity: Entity) {
        entity.footprint = nil
        unregisterPosition(entity)
        if let container = entity.container {
            container.clearSlot(Int(entity.containerSlot))
            return
        }
        guard !entity.position.isOutOfWorld, !architecture.isOutOfBounds(entity.position) else { return }
        try? entity.setArchitecturalWallStyles(to: 0)          // in range, so these can't fail
        try? entity.setWallUse(occupied: false, exclusive: entity.objectData[Int(ObjectVariable.exclusivePlacementFlags.rawValue)] & 2 != 0)
    }

    /// `VMGameObject.PositionChange`: the entity takes its place. What it holds moves with it, and
    /// it joins the room and tile; unless it's in a container, in the world a door or window puts
    /// its style on the walls, the object marks the walls it uses,
    /// a dynamic multi-tile object joins its neighbors, and it gets a footprint and (unless loading)
    /// runs the placement entry point.
    func takePosition(_ entity: Entity, runsPlacementEntryPoint: Bool) throws(SimAnticsError) {
        entity.setRoom(architecture.room(at: entity.position))
        // What it holds comes along.
        for case let held? in entity.contained {
            unregisterPosition(held)
            held.position = entity.position
            try takePosition(held, runsPlacementEntryPoint: runsPlacementEntryPoint)
        }
        registerPosition(entity)
        guard entity.container == nil else { return }
        guard !entity.position.isOutOfWorld, !architecture.isOutOfBounds(entity.position) else { return }
        try entity.setArchitecturalWallStyles(to: entity.object.definition.wallStyle)
        try entity.setWallUse(occupied: true, exclusive: entity.objectData[Int(ObjectVariable.exclusivePlacementFlags.rawValue)] & 2 != 0)
        if let table = entity.entryPoints, table.count > 8, table[8].actionFunction != 0 {
            try entity.updateDynamicMultitile()
        }
        entity.footprint = entity.obstacle(at: entity.position, facing: entity.direction)
        if runsPlacementEntryPoint { try entity.executeEntryPoint(.place, runImmediately: true) }
    }

    /// `RegisterObjectPos`: joins the room's list and the tile index, and records the room.
    private func registerPosition(_ entity: Entity) {
        guard entity.position.level >= 1 else { return }
        let room = Int(architecture.room(at: entity.position))
        if room < roomEntities.count { VMScheduler.insertInObjectIDOrder(entity, into: &roomEntities[room]) }
        entity.setRoom(UInt16(room))
        var list = tileIndex[tileKey(entity.position)] ?? []
        if !list.contains(where: { $0 === entity }) { VMScheduler.insertInObjectIDOrder(entity, into: &list) }
        tileIndex[tileKey(entity.position)] = list
    }

    /// `UnregisterObjectPos`: leaves the room's list and the tile index.
    private func unregisterPosition(_ entity: Entity) {
        let room = Int(architecture.room(at: entity.position))
        if room < roomEntities.count, let index = roomEntities[room].firstIndex(where: { $0 === entity }) {
            roomEntities[room].remove(at: index)
        }
        removeFromTileIndex(entity)
    }

    /// Puts every entity in the room at its position, in object ID order, and rebuilds each room's
    /// list (`RegeneratePortalInfo`).
    private func updateRooms() {
        rebuildRoomLists()
        for entity in entities { entity.setRoom(architecture.room(at: entity.position)) }
    }

    /// Each room's list from the entities' positions. The lists are also rebuilt when the
    /// architecture is replaced outright.
    private func rebuildRoomLists() {
        var lists = [[Entity]](repeating: [], count: architecture.rooms.count)
        for entity in entities {
            let room = Int(architecture.room(at: entity.position))
            if room < lists.count { VMScheduler.insertInObjectIDOrder(entity, into: &lists[room]) }
        }
        roomEntitiesStorage = lists
        roomListsGeneration = architecture.generation
    }

    private func removeFromTileIndex(_ entity: Entity) {
        let key = tileKey(entity.position)
        guard var list = tileIndex[key], let index = list.firstIndex(where: { $0 === entity }) else { return }
        list.remove(at: index)
        tileIndex[key] = list.isEmpty ? nil : list
    }

    /// FreeSO's tile offset: out of the world is -1; otherwise tiles are numbered across, down, then
    /// up, so a position past the lot's edge shares a key with another tile, as in FreeSO.
    private func tileKey(_ position: LotPosition) -> Int {
        guard !position.isOutOfWorld else { return -1 }
        return Int(position.tileX) + Int(position.tileY) * lotSize.width
            + (Int(position.level) - 1) * lotSize.width * lotSize.height
    }

    /// Lists a new object under its category, as `VM.AddEntity` does through
    /// `VMObjectQueries.NewObject`: before its init runs, so usually under 0.
    private func listUnderCategory(_ entity: Entity) {
        changeCategory(of: entity, from: nil, to: entity.objectData[Int(ObjectVariable.category.rawValue)])
    }

    /// Moves an object between categories, as `RemoveCategory` and `RegisterCategory` do.
    func changeCategory(of entity: Entity, from old: Int16?, to new: Int16) {
        if let old { removeFromCategory(entity, old) }
        var list = categoryIndex[new] ?? []
        if !list.contains(where: { $0 === entity }) { VMScheduler.insertInObjectIDOrder(entity, into: &list) }
        categoryIndex[new] = list
    }

    private func removeFromCategoryIndex(_ entity: Entity) {
        removeFromCategory(entity, entity.objectData[Int(ObjectVariable.category.rawValue)])
    }

    private func removeFromCategory(_ entity: Entity, _ category: Int16) {
        guard var list = categoryIndex[category], let index = list.firstIndex(where: { $0 === entity }) else { return }
        list.remove(at: index)
        categoryIndex[category] = list.isEmpty ? nil : list
    }

    // MARK: Globals

    public func globalValue(at index: UInt16) throws(SimAnticsError) -> Int16 {
        guard Int(index) < globalState.count else { throw .simantics("Global Access out of bounds!") }
        return globalState[Int(index)]
    }

    public func setGlobalValue(_ value: Int16, at index: UInt16) throws(SimAnticsError) {
        guard Int(index) < globalState.count else { throw .simantics("Global Access out of bounds!") }
        globalState[Int(index)] = value
    }

    // MARK: Routines

    /// The routine a subroutine call runs, assembled once per BHAV, or `nil` if the file has no such BHAV.
    /// The routine an object's file or semi-global names `name` (`TreeByName`: labels up to the
    /// first NUL, the object's own first), assembled once, or `nil` if there's none.
    func routine(named name: String, in object: GameObject) -> Routine? {
        guard let bhav = object.resource.treesByName[name] else { return nil }
        let key = RoutineKey(file: "tree \(object.resource.name) \(name)", id: bhav.id)
        if let cached = routines[key] { return cached }
        let routine = Routine(bhav, primitives: primitives)
        routines[key] = routine
        return routine
    }

    func routine(opcode: UInt16, codeOwner: GameObject) throws(SimAnticsError) -> Routine? {
        let resource: any IFFResource
        let file: String
        if opcode >= 8192 {
            guard let semiGlobal = codeOwner.resource.semiGlobal else {
                throw .nullReference("\(codeOwner.resource.name) has no semi-global")
            }
            resource = semiGlobal
            file = "semi-global \(semiGlobal.name)"
        } else if opcode >= 4096 {
            resource = codeOwner.resource
            file = "object \(codeOwner.resource.name)"
        } else {
            resource = global
            file = "global"
        }
        let key = RoutineKey(file: file, id: opcode)
        if let cached = routines[key] { return cached }
        let bhav: BHAV?
        do {
            bhav = try resource.chunk(BHAV.self, id: opcode)
        } catch {
            throw .simantics("BHAV \(opcode) in \(file) doesn't parse: \(error)")
        }
        guard let bhav else { return nil }
        let routine = Routine(bhav, primitives: primitives)
        routines[key] = routine
        return routine
    }
}
