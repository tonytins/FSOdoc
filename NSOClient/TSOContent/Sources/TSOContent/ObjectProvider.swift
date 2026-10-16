import Foundation
import TSOFiles

/// An object definition with the files it runs from.
///
/// Ports FreeSO's `GameObject`.
public struct GameObject: Sendable {
    public var guid: UInt32 { definition.guid }
    public let definition: OBJD
    public let resource: ObjectResource
}

/// The game's objects, by GUID.
///
/// Ports FreeSO's `WorldObjectProvider` in TSO mode. Objects come from
/// `objectdata/objects/objiff.far`, listed in `packingslips/objecttable.xml`, plus
/// standalone IFFs (FreeSO's `Content/Objects`), whose every `OBJD` is registered.
/// Each IFF loads on first use with its patches, sprites (if enabled), tuning, and
/// semi-global, and is shared by every object in it.
///
/// As in FreeSO, when patches change an archived IFF, its objects are registered
/// again from the patched file, since a patch can add, remove, or change `OBJD`s.
///
/// Differences from FreeSO, all to keep loading instead of failing:
///
/// - A GUID listed twice keeps its first registration; the rest are in ``duplicates``.
///   FreeSO fails on the second.
/// - An entry whose IFF isn't in `objiff.far` throws ``ContentError/missingFile(_:)``
///   for that object only. FreeSO fails with a null reference.
/// - A tuning file that fails to load is reported in ``ObjectResource/tuningFailure``.
///   FreeSO ignores it silently; both load the object without tuning.
public final class ObjectProvider: @unchecked Sendable {
    /// Where an object's IFF comes from.
    public enum Source: Sendable, Equatable {
        /// `objiff.far`.
        case archive
        /// A standalone IFF on disk.
        case standalone
    }

    /// A registered object, before its files are loaded.
    public struct Reference: Sendable, Equatable {
        public var guid: UInt32
        /// The IFF's name: the file name in `objiff.far` without extension, or a standalone file's path.
        public var fileName: String
        public var source: Source
        /// The display name: from the object table, or the `OBJD` label once registered from a file.
        public var name: String?
        public var group: Int16
        public var subIndex: Int16
    }

    /// A GUID registered more than once. The first registration is kept.
    public struct Duplicate: Sendable, Equatable {
        public var kept: Reference
        public var ignored: Reference
    }

    private let files: GameFileIndex
    private let patches: PatchRegistry
    private let globals: GlobalProvider
    private let iffs: FAR1Collection
    private let tunings: FAR1Collection
    private let sprites: FAR1Collection?

    private let lock = NSLock()
    private var referencesByGUID: [UInt32: Reference] = [:]
    private var resourcesByFileName: [String: ObjectResource] = [:]
    private var _duplicates: [Duplicate] = []

    /// Reads the object table and registers every object.
    ///
    /// - Parameters:
    ///   - standaloneDirectory: A folder of extra `*.iff` objects, searched recursively,
    ///     or `nil` for none. FreeSO uses `Content/Objects`.
    ///   - loadsSprites: Whether to load sprite IFFs from `objspf*.far`. Servers don't need them.
    /// - Throws: An error if the object table or an archive is missing or malformed,
    ///   or a standalone IFF doesn't parse.
    public init(files: GameFileIndex, patches: PatchRegistry, globals: GlobalProvider,
                standaloneDirectory: URL?, loadsSprites: Bool) throws(ContentError) {
        self.files = files
        self.patches = patches
        self.globals = globals
        iffs = try FAR1Collection(paths: [Self.storedPath("objectdata/objects/objiff.far", in: files)], in: files)
        tunings = try FAR1Collection(paths: files.paths(where: { Self.isArchive($0, prefix: "objotf") }), in: files)
        sprites = loadsSprites
            ? try FAR1Collection(paths: files.paths(where: { Self.isArchive($0, prefix: "objspf") }), in: files)
            : nil

        let tablePath = try Self.storedPath("packingslips/objecttable.xml", in: files)
        let table: ObjectTable
        do {
            table = try ObjectTable(bytes: Data(contentsOf: files.root.appendingPathComponent(tablePath)))
        } catch let error as ContentError {
            throw error
        } catch {
            throw .invalidFile(path: tablePath, reason: String(describing: error))
        }
        for entry in table.entries {
            register(Reference(guid: entry.guid, fileName: entry.fileName, source: .archive,
                               name: entry.name, group: entry.group, subIndex: entry.subIndex))
        }
        if let standaloneDirectory { try registerStandaloneObjects(in: standaloneDirectory) }
    }

    /// GUIDs that were registered more than once, in the order found.
    public var duplicates: [Duplicate] {
        lock.lock()
        defer { lock.unlock() }
        return _duplicates
    }

    /// Every registered object, sorted by GUID. O(n log n).
    public var references: [Reference] {
        lock.lock()
        defer { lock.unlock() }
        return referencesByGUID.values.sorted { $0.guid < $1.guid }
    }

    /// The registration for a GUID, or `nil` if there isn't one.
    public func reference(guid: UInt32) -> Reference? {
        lock.lock()
        defer { lock.unlock() }
        return referencesByGUID[guid]
    }

    /// An object by GUID, loading its IFF if needed.
    ///
    /// - Returns: The object, or `nil` if the GUID isn't registered or its IFF has no
    ///   `OBJD` with that GUID (as FreeSO returns null).
    /// - Throws: An error if the object's files are missing or don't parse, or its semi-global can't load.
    public func object(guid: UInt32) throws(ContentError) -> GameObject? {
        lock.lock()
        defer { lock.unlock() }
        guard let reference = referencesByGUID[guid] else { return nil }
        let resource = try resource(for: reference)
        let definitions: [OBJD]
        do {
            definitions = try resource.mainFile.chunks(OBJD.self)
        } catch {
            throw .invalidFile(path: reference.fileName, reason: String(describing: error))
        }
        guard let definition = definitions.first(where: { $0.guid == guid }) else { return nil }
        return GameObject(definition: definition, resource: resource)
    }

    // MARK: Private

    private static func storedPath(_ path: String, in files: GameFileIndex) throws(ContentError) -> String {
        guard let stored = files.storedPath(for: path) else { throw .missingFile(path) }
        return stored
    }

    /// Matches FreeSO's unanchored `.*/objotf.*\.far` and `.*/objspf.*\.far`, ignoring letter case.
    private static func isArchive(_ lowerCasePath: String, prefix: String) -> Bool {
        guard let match = lowerCasePath.range(of: "/\(prefix)") else { return false }
        return lowerCasePath[match.upperBound...].contains(".far")
    }

    private func register(_ reference: Reference) {
        if let kept = referencesByGUID[reference.guid] {
            _duplicates.append(Duplicate(kept: kept, ignored: reference))
            return
        }
        referencesByGUID[reference.guid] = reference
    }

    private func registerStandaloneObjects(in directory: URL) throws(ContentError) {
        let urls: [URL]
        do {
            urls = try DirectoryListing.regularFiles(under: directory)
        } catch {
            throw .invalidFile(path: directory.path, reason: String(describing: error))
        }
        for url in urls where url.pathExtension.lowercased() == "iff" {
            let file = try Self.readIFF(at: url, path: url.path)
            for definition in try Self.definitions(in: file, path: url.path) {
                register(Reference(guid: definition.guid, fileName: url.path, source: .standalone,
                                   name: definition.label, group: Int16(bitPattern: definition.masterID),
                                   subIndex: definition.subIndex))
            }
        }
    }

    /// The resource for a registration's IFF, loading it on first use. Call with the lock held.
    private func resource(for reference: Reference) throws(ContentError) -> ObjectResource {
        if let cached = resourcesByFileName[reference.fileName] { return cached }
        let resource = switch reference.source {
        case .archive: try loadArchivedResource(named: reference.fileName)
        case .standalone: try loadStandaloneResource(at: reference.fileName)
        }
        resourcesByFileName[reference.fileName] = resource
        return resource
    }

    private func loadArchivedResource(named fileName: String) throws(ContentError) -> ObjectResource {
        let iffName = "\(fileName).iff"
        guard let data = try iffs.data(named: iffName) else { throw .missingFile("objectdata/objects/objiff.far/\(iffName)") }
        let outcome = patches.applyingPatches(to: try Self.parseIFF(data, path: iffName), fileName: iffName)

        var spriteFile: IFFFile?
        if let spriteData = try sprites?.data(named: "\(fileName).spf") {
            spriteFile = try Self.parseIFF(spriteData, path: "\(fileName).spf")
        }
        let (tuning, tuningFailure) = loadTuning(named: "\(fileName).otf")

        if !outcome.applied.isEmpty { try reregisterObjects(in: outcome.file, fileName: fileName) }
        return try makeResource(name: fileName, file: outcome.file, sprites: spriteFile, tuning: tuning,
                                patches: PatchReport(applied: outcome.applied, skipped: outcome.skipped),
                                tuningFailure: tuningFailure)
    }

    /// Standalone files are patched by file name too, but their objects aren't registered again (as in FreeSO).
    private func loadStandaloneResource(at path: String) throws(ContentError) -> ObjectResource {
        let url = URL(fileURLWithPath: path)
        let outcome = patches.applyingPatches(to: try Self.readIFF(at: url, path: path), fileName: url.lastPathComponent)
        return try makeResource(name: path, file: outcome.file, sprites: nil, tuning: nil,
                                patches: PatchReport(applied: outcome.applied, skipped: outcome.skipped),
                                tuningFailure: nil)
    }

    /// FreeSO loads tuning from a patch replacement or `objotf*.far`, and ignores any failure.
    private func loadTuning(named otfName: String) -> (OTFFile?, String?) {
        do {
            if let replacement = patches.tuningReplacement(for: otfName) {
                return (try OTFFile(contentsOf: replacement), nil)
            }
            guard let data = try tunings.data(named: otfName) else { return (nil, nil) }
            return (try OTFFile(bytes: data), nil)
        } catch {
            return (nil, "\(otfName): \(error)")
        }
    }

    /// Replaces the registrations for an archived IFF with the `OBJD`s now in it (FreeSO's `ResetFile`).
    private func reregisterObjects(in file: IFFFile, fileName: String) throws(ContentError) {
        referencesByGUID = referencesByGUID.filter { $0.value.fileName != fileName }
        for definition in try Self.definitions(in: file, path: fileName) {
            register(Reference(guid: definition.guid, fileName: fileName, source: .archive,
                               name: definition.label, group: Int16(bitPattern: definition.masterID),
                               subIndex: definition.subIndex))
        }
    }

    /// The semi-global is named by the file's first `GLOB`; an empty name means none.
    private func makeResource(name: String, file: IFFFile, sprites: IFFFile?, tuning: OTFFile?,
                              patches: PatchReport, tuningFailure: String?) throws(ContentError) -> ObjectResource {
        let semiGlobalName: String?
        do {
            semiGlobalName = try file.chunks(GLOB.self).first.map(\.name)
        } catch {
            throw .invalidFile(path: name, reason: String(describing: error))
        }
        var semiGlobal: GlobalResource?
        if let semiGlobalName, !semiGlobalName.isEmpty {
            semiGlobal = try globals.resource(named: semiGlobalName)
        }
        do {
            return try ObjectResource(name: name, mainFile: file, sprites: sprites, tuning: tuning,
                                      semiGlobal: semiGlobal, patches: patches, tuningFailure: tuningFailure)
        } catch {
            throw .invalidFile(path: name, reason: String(describing: error))
        }
    }

    private static func definitions(in file: IFFFile, path: String) throws(ContentError) -> [OBJD] {
        do {
            return try file.chunks(OBJD.self)
        } catch {
            throw .invalidFile(path: path, reason: String(describing: error))
        }
    }

    private static func parseIFF(_ data: Data, path: String) throws(ContentError) -> IFFFile {
        do {
            return try IFFFile(bytes: data)
        } catch {
            throw .invalidFile(path: path, reason: String(describing: error))
        }
    }

    private static func readIFF(at url: URL, path: String) throws(ContentError) -> IFFFile {
        do {
            return try IFFFile(contentsOf: url)
        } catch {
            throw .invalidFile(path: path, reason: String(describing: error))
        }
    }
}
