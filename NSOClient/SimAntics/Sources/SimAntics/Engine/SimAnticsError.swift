import TSOContent

/// An error from running SimAntics code.
///
/// The cases follow what FreeSO throws, so differential tests can tell a matching
/// failure from a port gap. In FreeSO any of these thrown inside a thread resets the
/// entity; ``VMThread`` does the same.
public enum SimAnticsError: Error, Equatable, Sendable {
    /// What FreeSO throws as a `VMSimanticsException` or a plain `Exception`.
    case simantics(String)
    /// An array index out of range, which .NET throws as `IndexOutOfRangeException`.
    case indexOutOfRange(String)
    /// A missing object or entry, which FreeSO hits as a `NullReferenceException`.
    case nullReference(String)
    /// A cast to the wrong entity type, such as treating an object as a Sim (`InvalidCastException`).
    case invalidCast(String)
    /// 32-bit division overflow (`int.MinValue / -1`), which .NET throws as `OverflowException`.
    case overflow(String)
    /// More than ``VMThread/maximumInstructionsPerTick`` instructions in one tick.
    case infiniteLoop
    /// Content the code needs couldn't be loaded.
    case content(ContentError)
    /// Behavior this port doesn't support yet. Never a FreeSO failure.
    case unsupported(String)
}
