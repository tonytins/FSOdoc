import TSOContent
import TSOFiles

/// One running lot.
///
/// Ports the core of FreeSO's `VM` and `VMContext`: entities, the global state, the
/// random generator, the primitive table, and routine assembly. Ticking the lot, the
/// architecture, and networking come in later passes.
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

    /// Errors 2017 would show in a "SimAntics Exception" dialog, oldest first.
    public private(set) var reportedErrors: [ReportedError] = []

    /// An error a thread hit, and which entity and tick it was on.
    public struct ReportedError: Sendable, Equatable {
        public var objectID: Int16
        public var tick: UInt32
        public var error: SimAnticsError
    }

    private var entitiesByID: [Int16: Entity] = [:]
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
        globalState = [Int16](repeating: 0, count: 38)
        globalState[20] = 255 // game edition: every expansion
        globalState[25] = 4   // needed for Sims' idle interactions, as in EA-Land's globals
        globalState[17] = 4   // runtime code version
    }

    deinit {
        // Frames hold entities and entities hold their threads; break the cycles.
        for entity in entities { entity.thread.stack.removeAll() }
    }

    public func entity(id: Int16) -> Entity? {
        entitiesByID[id]
    }

    /// Adds an object with a given ID.
    ///
    /// A first step toward 2017's object creation: the entity is built as the `VMEntity`
    /// constructor builds it, out of the world, and runs nothing until ``Entity/initialize()``.
    /// Placement, multi-tile groups, and catalog prices come later.
    ///
    /// - Throws: ``SimAnticsError/nullReference(_:)`` if the content has no object with
    ///   the GUID, ``SimAnticsError/simantics(_:)`` if the ID is taken or 0.
    @discardableResult
    public func addObject(guid: UInt32, id: Int16) throws(SimAnticsError) -> Entity {
        guard id != 0, entitiesByID[id] == nil else { throw .simantics("object ID \(id) is not free") }
        let object: GameObject?
        do {
            object = try content.objects.object(guid: guid)
        } catch {
            throw .content(error)
        }
        guard let object else { throw .nullReference("no object with GUID \(String(guid, radix: 16))") }
        let entity = try Entity(objectID: id, object: object, vm: self)
        VMScheduler.insertInObjectIDOrder(entity, into: &entities)
        entitiesByID[id] = entity
        return entity
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
        scheduler.runTick(self)
    }

    func report(_ error: SimAnticsError, by entity: Entity) {
        reportedErrors.append(ReportedError(objectID: entity.objectID, tick: scheduler.currentTick, error: error))
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
