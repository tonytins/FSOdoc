/// Which entities run on which tick.
///
/// Ports FreeSO's `VMScheduler`. Each tick runs the entities scheduled for it, in object ID
/// order; an entity that doesn't schedule itself while running is scheduled for the next
/// tick. After each tick the random seed advances by the number of entities, as FreeSO does
/// to make clients desync quickly when their entity counts differ.
public final class VMScheduler {
    /// The current tick (`CurrentTickID`).
    public internal(set) var currentTick: UInt32 = 0
    /// Whether entities are being run (`RunningNow`); check threads then share their entity's temps.
    public private(set) var isRunning = false
    /// The entity being run, or `Int16.max` between runs (`CurrentObjectID`).
    public private(set) var currentObjectID = Int16.max

    private var schedule: [UInt32: [Entity]] = [:]
    /// Entities deleted while entities were running, deleted once the tick ends (`PendingDeletion`).
    private var pendingDeletion: [Entity] = []

    public init() {}

    /// The IDs of the entities scheduled for a tick, in run order.
    public func scheduledObjectIDs(on tick: UInt32) -> [Int16] {
        (schedule[tick] ?? []).map(\.objectID)
    }

    /// Schedules an entity `delay` ticks from now; entities that run every frame wait at most one.
    public func scheduleTick(for entity: Entity, in delay: UInt32) {
        let delay = delay > 1 && entity.runsEveryTick ? 1 : delay
        scheduleTick(for: entity, on: currentTick &+ delay)
    }

    public func scheduleTick(for entity: Entity, on tick: UInt32) {
        entity.thread.scheduledTick = tick
        Self.insertInObjectIDOrder(entity, into: &schedule[tick, default: []])
    }

    /// Removes an entity's future run (`DescheduleTick`).
    public func descheduleTick(for entity: Entity) {
        let tick = entity.thread.scheduledTick
        guard tick > currentTick, let index = schedule[tick]?.firstIndex(where: { $0 === entity }) else { return }
        schedule[tick]?.remove(at: index)
    }

    /// Starts a tick. On tick 0 (a fresh VM), runs scheduled for tick 1 move to the new tick.
    func beginTick(_ tick: UInt32) {
        if currentTick == 0, let first = schedule[1] {
            schedule[tick] = first
            if tick != 1 { schedule[1] = nil }
        }
        currentTick = tick
    }

    /// Runs this tick's entities. Entities scheduled into this tick while it runs also run.
    func runTick(_ vm: VM) {
        isRunning = true
        var index = 0
        while let entities = schedule[currentTick], index < entities.count {
            let entity = entities[index]
            currentObjectID = entity.objectID
            entity.tick()
            index += 1
        }
        schedule[currentTick] = nil
        vm.random.seed &+= UInt64(vm.entities.count)
        currentObjectID = .max
        isRunning = false
        let deletions = pendingDeletion
        pendingDeletion.removeAll()
        for entity in deletions { vm.delete(entity) }
    }

    /// Queues an entity to be deleted when the tick ends (`Delete`).
    func deleteAtEndOfTick(_ entity: Entity) {
        pendingDeletion.append(entity)
    }

    /// FreeSO's `VM.AddToObjList`: a binary search for the insertion point by object ID. It keeps
    /// the list sorted and, like FreeSO, doesn't check whether the entity is already in it.
    static func insertInObjectIDOrder(_ entity: Entity, into list: inout [Entity]) {
        guard !list.isEmpty else {
            list.append(entity)
            return
        }
        let id = Int(entity.objectID) - 1
        var low = 0, high = list.count - 1
        while high - 1 > low {
            let middle = (high + low) / 2
            if id < Int(list[middle].objectID) { high = middle } else { low = middle }
        }
        let position = Int(list[low].objectID) > id ? low : (Int(list[high].objectID) > id ? high : high + 1)
        list.insert(entity, at: position)
    }
}
