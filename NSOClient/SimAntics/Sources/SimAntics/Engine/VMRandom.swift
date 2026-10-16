/// The lot's deterministic random number generator.
///
/// Ports `VMContext.NextRandom`: xorshift64* with FreeSO's shifts and multiplier,
/// reduced with `%`. Every client must draw the same numbers in the same order.
public struct VMRandom: Sendable, Equatable {
    public var seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed
    }

    /// A number from 0 up to, not including, `limit`. A limit of 0 returns 0 without advancing.
    public mutating func next(below limit: UInt64) -> UInt64 {
        guard limit != 0 else { return 0 }
        seed ^= seed >> 12
        seed ^= seed << 25
        seed ^= seed >> 27
        return (seed &* 2_685_821_657_736_338_717) % limit
    }
}
