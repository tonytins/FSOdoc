/// A balloon over an entity (`VMRuntimeHeadline`): which picture, from which group, for how long.
///
/// NSOClient doesn't draw it; it keeps what a renderer would need, and the countdown, which
/// affects scheduling.
public struct Headline: Sendable, Equatable {
    /// The picture group (`VMSetBalloonHeadlineOperandGroup`), such as 1 for balloons or 7 for algorithmic.
    public var group: UInt8
    /// The picture in the group, after Set Balloon Headline adds temp 0 for an indexed one.
    public var index: Int8
    /// Ticks left, or a negative value to stay up until replaced.
    public var duration: Int
    public var type: UInt8
    /// Set Balloon Headline's flags: inactive, crossed out, backwards, duration in loops, indexed.
    public var flags: UInt8
    /// For the algorithmic group, the object whose picture is shown, if any.
    public var iconObjectID: Int16?

    public init(group: UInt8, index: Int8, duration: Int, type: UInt8 = 0, flags: UInt8 = 0, iconObjectID: Int16? = nil) {
        self.group = group
        self.index = index
        self.duration = duration
        self.type = type
        self.flags = flags
        self.iconObjectID = iconObjectID
    }
}
