import Foundation
import TSOFiles

/// Globals and semi-globals from `objectdata/globals`, by name.
///
/// Ports FreeSO's `WorldGlobalProvider` in TSO mode. `global` is the global every
/// object can call; the others are semi-globals, named by an object's `GLOB` chunk.
/// Each loads once and is kept.
public final class GlobalProvider: @unchecked Sendable {
    private let files: GameFileIndex
    private let patches: PatchRegistry
    private let lock = NSLock()
    private var cache: [String: GlobalResource] = [:]

    public init(files: GameFileIndex, patches: PatchRegistry) {
        self.files = files
        self.patches = patches
    }

    /// A global or semi-global by file name without extension, in any letter case.
    ///
    /// Applies the patches registered for `<name>.iff`, and reads `<name>.otf` from the
    /// patches or beside the IFF if either has it. As in 2017, a missing OTF is
    /// fine, and a missing IFF is an error. Failures aren't kept, so a later call tries again.
    ///
    /// - Throws: ``ContentError/missingFile(_:)`` if the IFF doesn't exist, or
    ///   ``ContentError/invalidFile(path:reason:)`` if it or the OTF doesn't parse.
    public func resource(named name: String) throws(ContentError) -> GlobalResource {
        let name = name.lowercased()
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[name] { return cached }

        let iffPath = "objectdata/globals/\(name).iff"
        guard let url = files.url(for: iffPath) else { throw .missingFile(iffPath) }
        let original: IFFFile
        do {
            original = try IFFFile(contentsOf: url)
        } catch {
            throw .invalidFile(path: iffPath, reason: String(describing: error))
        }
        let outcome = patches.applyingPatches(to: original, fileName: "\(name).iff")
        let resource = GlobalResource(name: name, mainFile: outcome.file, tuning: try tuning(named: name),
                                      patches: PatchReport(applied: outcome.applied, skipped: outcome.skipped))
        cache[name] = resource
        return resource
    }

    private func tuning(named name: String) throws(ContentError) -> OTFFile? {
        let otfPath = "objectdata/globals/\(name).otf"
        guard let url = patches.tuningReplacement(for: "\(name).otf") ?? files.url(for: otfPath) else { return nil }
        do {
            return try OTFFile(contentsOf: url)
        } catch {
            throw .invalidFile(path: url.path, reason: String(describing: error))
        }
    }
}
