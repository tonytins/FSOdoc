import Foundation

/// An error from finding or loading game content.
public enum ContentError: Error, Equatable, Sendable {
    /// No TSO install was found. Lists every folder that was tried, in order.
    case gameNotFound(searched: [String])
    /// A folder was given (configured or through `TSO_GAME_DIR`) but isn't a TSO install.
    case notAnInstall(path: String)
    /// A file the content system needs doesn't exist. The path is relative to its folder.
    case missingFile(String)
    /// A file exists but couldn't be read or parsed.
    case invalidFile(path: String, reason: String)
    /// An entry in `packingslips/objecttable.xml` is malformed.
    case invalidObjectTable(String)
}
