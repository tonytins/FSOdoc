import Foundation

/// ASCII text decoding that matches .NET's `Encoding.ASCII`.
///
/// FreeSO's readers decode names and labels with `Encoding.ASCII`, which turns
/// every byte above 0x7F into `?`. Decoding the same way keeps names, and
/// therefore lookups by name, identical.
public enum ASCII {
    /// Decodes bytes as ASCII, keeping NUL characters.
    public static func decode(_ bytes: some Sequence<UInt8>) -> String {
        String(decoding: bytes.map { $0 < 0x80 ? $0 : UInt8(ascii: "?") }, as: UTF8.self)
    }
}

extension String {
    /// The string with trailing NUL characters removed, like .NET's `TrimEnd('\0')`.
    func trimmingTrailingNULs() -> String {
        var trimmed = Substring(self)
        while trimmed.last == "\0" {
            trimmed.removeLast()
        }
        return String(trimmed)
    }
}
