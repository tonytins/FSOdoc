/// Which entities run on which tick.
///
/// A first part of FreeSO's `VMScheduler`: the tick counter and wake-up requests.
/// Running the scheduled entities each tick comes with `VM.tick()` in a later pass.
public final class VMScheduler {
    /// The current tick (2017's `CurrentTickID`).
    public internal(set) var currentTick: UInt32 = 0
    /// Entities waiting to run, by the tick they wake on.
    public private(set) var wakeTicks: [UInt32: [Int16]] = [:]

    public init() {}

    /// Asks for an entity to run again `delay` ticks from now.
    public func scheduleTick(for entity: Entity, in delay: UInt32) {
        wakeTicks[currentTick &+ delay, default: []].append(entity.objectID)
    }
}
