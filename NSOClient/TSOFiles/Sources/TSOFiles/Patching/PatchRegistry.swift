import Foundation

/// The PIFF patches and OTF replacements found under a patch folder.
///
/// Ports FreeSO's `PIFFRegistry`. Every `.piff` file is filed under the IFF it
/// patches. Patches under a `User/` folder win: once one exists for an IFF, the
/// shipped patches for that IFF are dropped. Every `.otf` file replaces the OTF
/// with the same file name. Differences from 2017, all for reliable results:
///
/// - Files are read in sorted path order, where .NET's order was undefined.
/// - `User/` is matched in the path relative to the patch folder, not the full path.
/// - A patch file that fails to load is recorded in ``failures`` instead of
///   being skipped silently.
///
/// PIFF is FreeSO's own format: ad hoc fixes for objects its engine didn't run
/// correctly, written against TSO's 2003 production files. Other versions of
/// the game (such as the 2002 beta) may not match them, so
/// ``applyingPatches(to:fileName:)`` applies each patch only if it fits; see there.
public struct PatchRegistry: Sendable {
    /// A patch file that couldn't be loaded.
    public struct Failure: Sendable, Equatable {
        /// The path relative to the patch folder.
        public var path: String
        public var message: String
    }

    /// A patch file and the name it was registered under.
    public struct RegisteredPatch: Sendable {
        public var name: String
        public var file: IFFFile
    }

    /// A patch that was left out because it didn't fit the file.
    public struct SkippedPatch: Sendable, Equatable {
        public var name: String
        public var reason: String
    }

    /// The result of applying the registered patches to one file.
    public struct Outcome: Sendable {
        /// The file with every fitting patch applied.
        public var file: IFFFile
        /// The patches applied, in order.
        public var applied: [String]
        /// The patches left out, in order, with why.
        public var skipped: [SkippedPatch]
    }

    private var patchesBySource: [String: [RegisteredPatch]] = [:]
    private var isUserPatchBySource: [String: Bool] = [:]
    private var tuningReplacements: [String: URL] = [:]

    /// Patch files that couldn't be loaded, in path order.
    public private(set) var failures: [Failure] = []

    /// An empty registry, with no patches.
    public init() {}

    /// Loads every `.piff` and `.otf` file under a folder.
    ///
    /// - Throws: An error if the folder can't be listed. Individual bad files are in ``failures``.
    public init(directory: URL) throws {
        for url in try DirectoryListing.regularFiles(under: directory) {
            let relativePath = DirectoryListing.relativePath(of: url, under: directory)
            switch url.pathExtension.lowercased() {
            case "piff":
                do {
                    try register(IFFFile(contentsOf: url), named: relativePath, isUserPatch: relativePath.contains("User/"))
                } catch {
                    failures.append(Failure(path: relativePath, message: String(describing: error)))
                }
            case "otf":
                tuningReplacements[url.lastPathComponent] = url
            default:
                continue
            }
        }
    }

    /// Adds a patch file, following the 2017 precedence for user patches.
    public mutating func register(_ patchFile: IFFFile, named name: String, isUserPatch: Bool) throws(PIFFError) {
        guard let record = patchFile.chunk(ofType: PIFF.typeCode) else { throw .missingPatchChunk }
        let source: String
        do {
            source = try PIFF(record: record).sourceFileName
        } catch {
            throw .invalidPatchChunk(error)
        }

        if let wasUserPatch = isUserPatchBySource[source], wasUserPatch != isUserPatch {
            guard isUserPatch else { return } // a user patch already replaced the shipped ones
            patchesBySource[source] = []
            isUserPatchBySource[source] = true
        } else {
            isUserPatchBySource[source] = isUserPatch
        }
        patchesBySource[source, default: []].append(RegisteredPatch(name: name, file: patchFile))
    }

    /// The patches for an IFF file name, such as `chairs.iff`, in the order they apply.
    public func patches(for fileName: String) -> [RegisteredPatch] {
        patchesBySource[fileName] ?? []
    }

    /// The replacement for an OTF file name, such as `chairs.otf`, if one was found.
    public func tuningReplacement(for fileName: String) -> URL? {
        tuningReplacements[fileName]
    }

    /// Applies the registered patches for a file name, in order, as `IffFile.SetFilename` does,
    /// keeping only the ones that fit.
    ///
    /// Each patch is applied as a whole or not at all. It's kept only if it applies
    /// cleanly and every chunk it changes or adds, of a type this package can
    /// parse, still parses. On the files a patch was written for, every patch fits
    /// and the result matches 2017. On other versions of the game (such as the
    /// 2002 beta) a patch that doesn't fit is skipped and reported, where 2017
    /// would fail to load the object.
    public func applyingPatches(to iff: IFFFile, fileName: String) -> Outcome {
        var outcome = Outcome(file: iff, applied: [], skipped: [])
        for patch in patches(for: fileName) {
            do {
                let patched = try outcome.file.applying(patch.file)
                if let problem = Self.firstUnparsableChunk(in: patched, touchedBy: patch.file) {
                    outcome.skipped.append(SkippedPatch(name: patch.name, reason: problem))
                    continue
                }
                outcome.file = patched
                outcome.applied.append(patch.name)
            } catch {
                outcome.skipped.append(SkippedPatch(name: patch.name, reason: String(describing: error)))
            }
        }
        return outcome
    }

    /// Parses the chunks a patch changed or added, and describes the first that fails.
    private static func firstUnparsableChunk(in patched: IFFFile, touchedBy patchFile: IFFFile) -> String? {
        var touched: [(typeCode: String, id: UInt16)] = []
        if let record = patchFile.chunk(ofType: PIFF.typeCode), let piff = try? PIFF(record: record) {
            for entry in piff.entries where !entry.isDeletion {
                touched.append((entry.typeCode, entry.newChunkID))
                if entry.newChunkID != entry.chunkID { touched.append((entry.typeCode, entry.chunkID)) }
            }
        }
        for record in patchFile.chunks where record.typeCode != PIFF.typeCode {
            touched.append((record.typeCode, record.id))
        }
        for (typeCode, id) in touched {
            guard let chunkType = IFFChunkTypes.type(forCode: typeCode),
                  let record = patched.chunk(ofType: typeCode, id: id) else { continue }
            do {
                _ = try chunkType.init(record: record)
            } catch {
                return "patched \(typeCode) #\(id) doesn't parse: \(error)"
            }
        }
        return nil
    }
}
