import Foundation

/// Finds the folder of an installed copy of The Sims Online (the one holding `objectdata`).
///
/// Ports the 2017 client's per-OS locators, checking in order:
///
/// 1. a configured folder;
/// 2. the `TSO_GAME_DIR` environment variable;
/// 3. the usual folders for this OS.
///
/// A configured folder or `TSO_GAME_DIR` that isn't an install is an error rather
/// than being skipped, so a typo doesn't silently load a different install.
/// Differences from 2017: Windows doesn't read the registry, and Linux looks under
/// `$XDG_DATA_HOME` (or `~/.local/share`) before 2017's `game/TSOClient` next to the
/// working directory.
public struct GameLocator: Sendable {
    public static let environmentVariable = "TSO_GAME_DIR"

    /// A folder chosen by the user, checked first.
    public var configuredDirectory: URL?
    public var environment: [String: String]
    public var homeDirectory: URL
    public var workingDirectory: URL

    public init(
        configuredDirectory: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    ) {
        self.configuredDirectory = configuredDirectory
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.workingDirectory = workingDirectory
    }

    /// The usual install folders for this OS, in the order they're checked.
    public var defaultDirectories: [URL] {
        #if os(Windows)
        return [URL(fileURLWithPath: #"C:\Program Files\Maxis\The Sims Online\TSOClient\"#, isDirectory: true)]
        #elseif os(macOS)
        return [homeDirectory.appendingPathComponent("Documents/The Sims Online/TSOClient", isDirectory: true)]
        #else
        let dataHome = environment["XDG_DATA_HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? homeDirectory.appendingPathComponent(".local/share", isDirectory: true)
        return [
            dataHome.appendingPathComponent("The Sims Online/TSOClient", isDirectory: true),
            workingDirectory.appendingPathComponent("game/TSOClient", isDirectory: true),
        ]
        #endif
    }

    /// The install folder.
    ///
    /// - Throws: ``ContentError/notAnInstall(path:)`` if the configured folder or
    ///   `TSO_GAME_DIR` isn't an install, or ``ContentError/gameNotFound(searched:)``
    ///   if no default folder is.
    public func locate() throws(ContentError) -> URL {
        if let configuredDirectory {
            guard Self.isInstall(configuredDirectory) else { throw .notAnInstall(path: configuredDirectory.path) }
            return configuredDirectory
        }
        if let path = environment[Self.environmentVariable], !path.isEmpty {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            guard Self.isInstall(directory) else { throw .notAnInstall(path: path) }
            return directory
        }
        let candidates = defaultDirectories
        guard let found = candidates.first(where: Self.isInstall) else {
            throw .gameNotFound(searched: candidates.map(\.path))
        }
        return found
    }

    /// Whether a folder holds an install: it has an `objectdata` folder, in any letter case.
    public static func isInstall(_ directory: URL) -> Bool {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return false }
        return names.contains { $0.lowercased() == "objectdata" }
    }
}
