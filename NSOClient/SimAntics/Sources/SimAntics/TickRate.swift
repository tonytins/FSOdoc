/// How often the SimAntics virtual machine advances.
///
/// The rate is part of lockstep compatibility: every client and the lot server
/// must tick at the same rate, whatever their frame rate.
public enum TickRate {
    /// Simulation ticks per second.
    public static let perSecond = 30
}
