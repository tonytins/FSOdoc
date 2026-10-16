/// The lot's game clock.
///
/// Ports FreeSO's `VMClock`. TSO runs 150 ticks per game minute (a minute every five
/// seconds). Time of day is always 0, as in 2017, where it's fixed to keep windows lit.
public struct VMClock: Sendable, Equatable {
    public var ticks: Int64 = 0
    public var minuteFractions: Int32 = 0
    public var ticksPerMinute: Int32 = 150
    public var minutes: Int32 = 0
    public var hours: Int32 = 0
    /// Rises by one a tick up to 20,000; fire spreading reads it.
    public var firePercent: Int32 = 0

    public init() {}

    public var seconds: Int32 { minuteFractions &* 60 / ticksPerMinute }
    public var timeOfDay: Int32 { 0 }

    /// Advances one tick.
    public mutating func tick() {
        if firePercent < 20_000 { firePercent += 1 }
        minuteFractions += 1
        if minuteFractions >= ticksPerMinute {
            minuteFractions = 0
            minutes += 1
            if minutes >= 60 {
                minutes = 0
                hours += 1
                if hours >= 24 { hours = 0 }
            }
        }
        ticks += 1
    }
}
