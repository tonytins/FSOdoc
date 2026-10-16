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
    /// Objects by category, in object ID order (`VMObjectQueries.ObjectsByCategory`). An object
    /// is listed once its category is set through object data, not when it's created.
    private var categoryIndex: [Int16: [Entity]] = [:]
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

    /// Loads a lot's walls and floors and puts every entity in its room, as
    /// `VMWorldActivator.LoadFromXML` does before it creates the lot's objects.
    ///
    /// - Throws: ``SimAnticsError/simantics(_:)`` if the blueprint is off the lot.
    public func load(_ blueprint: Blueprint) throws(SimAnticsError) {
        do {
            architecture = try blueprint.architecture()
        } catch {
            throw .simantics("can't load the blueprint: \(error)")
        }
        updateRooms()
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
    /// is placed.
    ///
    /// - Throws: ``SimAnticsError/unsupported(_:)`` for a Sim, or a position in the world, which
    ///   needs placement (not ported yet); any error an entity's init entry point throws.
    @discardableResult
    public func createObject(guid: UInt32, at position: LotPosition = .outOfWorld, facing direction: Direction = .north,
                             mainStackObjectID: Int16 = 0, mainParameter: Int16 = 0) throws(SimAnticsError) -> MultitileGroup? {
        guard let object = try gameObject(guid: guid) else { return nil }
        let definition = object.definition
        guard definition.knownObjectType != .person else { throw .unsupported("creating a Sim needs Sims") }
        guard position.isOutOfWorld else { throw .unsupported("placing an object in the world needs placement") }

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
            }
        } else {
            group = MultitileGroup(isMultiTile: false)
            register(try Entity(objectID: freeObjectID(), object: object, vm: self, group: group))
        }

        for entity in group.objects {
            entity.mainStackObjectID = mainStackObjectID
            entity.mainParameter = mainParameter
        }
        for entity in group.objects { try entity.initialize() }
        moveOutOfWorld(group, facing: direction)
        return group
    }

    /// Deletes an entity, or with `wholeGroup`, every part of its object (`VMEntity.Delete`).
    ///
    /// While entities are running, deletion waits until the tick ends, after the random seed
    /// advances. A deleted entity leaves the entity list, the queries, the schedule, and its group,
    /// and its object ID becomes free again. Deleting one twice does nothing. Contained objects
    /// aren't moved out yet (containers come with slots).
    public func delete(_ entity: Entity, wholeGroup: Bool = false) {
        if wholeGroup {
            for part in entity.group.objects { delete(part) }
            return
        }
        guard !entity.isDead else { return }
        if scheduler.isRunning {
            scheduler.deleteAtEndOfTick(entity)
            return
        }
        entity.isDead = true
        removeFromTileIndex(entity)
        removeFromCategoryIndex(entity)
        if let index = entities.firstIndex(where: { $0 === entity }) {
            entities.remove(at: index)
            entitiesByID[entity.objectID] = nil
            scheduler.descheduleTick(for: entity)
            lowestFreeObjectID = min(lowestFreeObjectID, entity.objectID)
        }
        entity.group.remove(entity)
        // A deleted entity never runs again; dropping its stack breaks the frames' references to it.
        entity.thread.stack.removeAll()
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

    /// Objects whose category was set to `category`, in object ID order, or `nil` if there are none.
    public func objects(inCategory category: Int16) -> [Entity]? {
        categoryIndex[category]
    }

    /// Objects on a tile, in object ID order, or `nil` if there are none (`GetObjectsAt`).
    /// Every object out of the world shares one entry.
    public func objects(at position: LotPosition) -> [Entity]? {
        tileIndex[tileKey(position)]
    }

    /// Moves every part of a group, keeping each one's facing, as `ChangePosition` does for a
    /// position out of the world. Placing a group in the world needs placement (not ported yet).
    func moveOutOfWorld(_ group: MultitileGroup, facing direction: Direction) {
        for entity in group.objects {
            entity.direction = direction
            move(entity, to: .outOfWorld)
        }
    }

    /// Moves an entity, keeping the tile index and its room (object data 29) current, as FreeSO's
    /// position change does. Footprints, portals, lighting, and the placement entry point come
    /// with the rest of the lot model.
    public func move(_ entity: Entity, to position: LotPosition) {
        removeFromTileIndex(entity)
        entity.position = position
        entity.setRoom(architecture.room(at: position))
        var list = tileIndex[tileKey(position)] ?? []
        if !list.contains(where: { $0 === entity }) { VMScheduler.insertInObjectIDOrder(entity, into: &list) }
        tileIndex[tileKey(position)] = list
    }

    /// Puts every entity in the room at its position, in object ID order (`RegeneratePortalInfo`).
    private func updateRooms() {
        for entity in entities { entity.setRoom(architecture.room(at: entity.position)) }
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
