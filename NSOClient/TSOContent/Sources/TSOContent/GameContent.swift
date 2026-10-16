import Foundation
import TSOFiles

/// The content of one TSO install: its files, patches, globals, and objects.
///
/// Replaces FreeSO's `Content` singleton for the parts SimAntics needs. Create one
/// per install; nothing is global, so tests and tools can load several side by side.
public final class GameContent: Sendable {
    /// Where to find the game and FreeSO's additions.
    public struct Configuration: Sendable {
        /// The install folder; see ``GameLocator``.
        public var gameDirectory: URL
        /// A folder of PIFF and OTF patches (FreeSO's `Content/Patch`), or `nil` for none.
        public var patchDirectory: URL?
        /// A folder of standalone object IFFs (FreeSO's `Content/Objects`), or `nil` for none.
        public var standaloneObjectDirectory: URL?
        /// Whether to load object sprites. Servers don't need them.
        public var loadsSprites: Bool

        public init(gameDirectory: URL, patchDirectory: URL? = nil, standaloneObjectDirectory: URL? = nil,
                    loadsSprites: Bool = false) {
            self.gameDirectory = gameDirectory
            self.patchDirectory = patchDirectory
            self.standaloneObjectDirectory = standaloneObjectDirectory
            self.loadsSprites = loadsSprites
        }

        /// FreeSO's layout: `Patch` and `Objects` inside its `Content` folder.
        public init(gameDirectory: URL, freeSOContentDirectory: URL, loadsSprites: Bool = false) {
            self.init(gameDirectory: gameDirectory,
                      patchDirectory: freeSOContentDirectory.appendingPathComponent("Patch", isDirectory: true),
                      standaloneObjectDirectory: freeSOContentDirectory.appendingPathComponent("Objects", isDirectory: true),
                      loadsSprites: loadsSprites)
        }
    }

    public let files: GameFileIndex
    public let patches: PatchRegistry
    public let globals: GlobalProvider
    public let objects: ObjectProvider

    /// Indexes the install, loads the patches, and registers every object.
    ///
    /// Objects, globals, and their files load later, on first use.
    public init(_ configuration: Configuration) throws(ContentError) {
        files = try GameFileIndex(root: configuration.gameDirectory)
        if let patchDirectory = configuration.patchDirectory {
            do {
                patches = try PatchRegistry(directory: patchDirectory)
            } catch {
                throw .invalidFile(path: patchDirectory.path, reason: String(describing: error))
            }
        } else {
            patches = PatchRegistry()
        }
        globals = GlobalProvider(files: files, patches: patches)
        objects = try ObjectProvider(files: files, patches: patches, globals: globals,
                                     standaloneDirectory: configuration.standaloneObjectDirectory,
                                     loadsSprites: configuration.loadsSprites)
    }

    /// The global every object can call (`objectdata/globals/global.iff`).
    public func global() throws(ContentError) -> GlobalResource {
        try globals.resource(named: "global")
    }
}
