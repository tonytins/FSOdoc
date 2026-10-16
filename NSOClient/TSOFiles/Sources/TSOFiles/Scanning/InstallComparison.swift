import Foundation

/// How two installs differ: which files each has, and inside files that differ, which
/// archive entries and IFF chunks were added, removed, or changed.
///
/// Records names, sizes, chunk IDs, and object GUIDs only, never file contents, so a
/// report can be kept where game data can't.
public struct InstallDifferences: Sendable, Equatable {
    /// Paths only the first install has, relative to its root, in sorted order.
    public var onlyInFirst: [String] = []
    /// Paths only the second install has.
    public var onlyInSecond: [String] = []
    /// Files both have whose bytes differ, in path order.
    public var changedFiles: [FileDifference] = []
    /// Files both have with the same bytes.
    public var identicalFileCount = 0

    public init() {}

    public var isEmpty: Bool { onlyInFirst.isEmpty && onlyInSecond.isEmpty && changedFiles.isEmpty }
}

/// One file both installs have, with different bytes.
public struct FileDifference: Sendable, Equatable {
    /// The path in the first install (paths are matched in any letter case).
    public var path: String
    public var firstSize: Int
    public var secondSize: Int
    /// The container both copies open as, or `nil` if either isn't a container or doesn't open.
    public var kind: ContainerKind?
    /// For a container, its entries that differ, in name order; IFFs inside archives are
    /// compared chunk by chunk, named `entry: TYPE #id`.
    public var entries: [EntryDifference] = []

    public init(path: String, firstSize: Int, secondSize: Int, kind: ContainerKind? = nil, entries: [EntryDifference] = []) {
        self.path = path
        self.firstSize = firstSize
        self.secondSize = secondSize
        self.kind = kind
        self.entries = entries
    }
}

/// An archive entry or IFF chunk that differs between two copies of a file.
public struct EntryDifference: Sendable, Equatable {
    public enum Change: String, Sendable, Equatable {
        case onlyInFirst, onlyInSecond, changed
    }

    public var name: String
    public var change: Change
    /// For an `OBJD` chunk: the object's GUID, in hexadecimal (the second copy's if it changed).
    public var guid: String?

    public init(name: String, change: Change, guid: String? = nil) {
        self.name = name
        self.change = change
        self.guid = guid
    }
}

/// Compares two installs file by file (`tsofiles-check` with both `TSO_GAME_DIR` and
/// `TSO_BETA_DIR` set).
public struct InstallComparison: Sendable {
    /// The FAR1 layout to assume. TSO installs use 1b.
    public var far1Variant: FAR1Archive.Variant

    public init(far1Variant: FAR1Archive.Variant = .b) {
        self.far1Variant = far1Variant
    }

    /// Compares every regular file under the two roots, matching paths in any letter case.
    ///
    /// - Throws: An error only if a root or a file can't be read.
    public func compare(_ first: URL, _ second: URL) throws -> InstallDifferences {
        let firstFiles = try Self.files(under: first), secondFiles = try Self.files(under: second)
        var differences = InstallDifferences()
        differences.onlyInFirst = firstFiles.filter { secondFiles[$0.key] == nil }.map(\.value.path).sorted()
        differences.onlyInSecond = secondFiles.filter { firstFiles[$0.key] == nil }.map(\.value.path).sorted()
        for key in firstFiles.keys.sorted() {
            guard let a = firstFiles[key], let b = secondFiles[key] else { continue }
            let firstData = try Data(contentsOf: a.url, options: .alwaysMapped)
            let secondData = try Data(contentsOf: b.url, options: .alwaysMapped)
            if firstData == secondData {
                differences.identicalFileCount += 1
                continue
            }
            var difference = FileDifference(path: a.path, firstSize: firstData.count, secondSize: secondData.count)
            if let kind = ContainerKind(header: firstData), ContainerKind(header: secondData) == kind,
               let firstEntries = entries(of: firstData, kind: kind), let secondEntries = entries(of: secondData, kind: kind) {
                difference.kind = kind
                difference.entries = Self.differences(firstEntries, secondEntries, prefix: nil)
            }
            differences.changedFiles.append(difference)
        }
        return differences
    }

    // MARK: Private

    private struct File {
        var url: URL
        var path: String
    }

    /// Regular files by lower-cased relative path.
    private static func files(under root: URL) throws -> [String: File] {
        var files: [String: File] = [:]
        for url in try DirectoryListing.regularFiles(under: root) {
            let path = DirectoryListing.relativePath(of: url, under: root)
            files[path.lowercased()] = File(url: url, path: path)
        }
        return files
    }

    /// An archive entry or chunk: its name, the bytes that make it what it is, and for an
    /// `OBJD`, its GUID.
    private struct Entry {
        var name: String
        var data: Data
        var guid: String?
    }

    /// A container's entries, or `nil` if it doesn't open.
    private func entries(of data: Data, kind: ContainerKind) -> [Entry]? {
        do {
            switch kind {
            case .far1:
                let archive = try FAR1Archive(bytes: data, variant: far1Variant)
                return try archive.entries.map { Entry(name: $0.fileName, data: try archive.data(for: $0)) }
            case .far3:
                let archive = try FAR3Archive(bytes: data)
                return try archive.entries.map { Entry(name: "\($0.fileName) [\($0.assetID)]", data: try archive.data(for: $0)) }
            case .dbpf:
                let archive = try DBPFArchive(bytes: data)
                return try archive.entries.map {
                    Entry(name: String(format: "type %08X group %08X instance %08X", $0.typeID.rawValue, $0.groupID.rawValue,
                                       $0.instanceID), data: try archive.data(for: $0))
                }
            case .iff:
                return Self.chunks(of: try IFFFile(bytes: data))
            }
        } catch {
            return nil
        }
    }

    /// An IFF's chunks as entries; a changed label or flag counts as a change.
    private static func chunks(of iff: IFFFile) -> [Entry] {
        iff.chunks.map { record in
            let guid = record.typeCode == OBJD.typeCode ? (try? OBJD(record: record)).map { String(format: "%08x", $0.guid) } : nil
            return Entry(name: "\(record.typeCode) #\(record.id)",
                         data: Data("\(record.flags)\u{0}\(record.label)\u{0}".utf8) + record.data, guid: guid)
        }
    }

    private static func differences(_ first: [Entry], _ second: [Entry], prefix: String?) -> [EntryDifference] {
        // Duplicate names keep their first entry, as lookups by name do.
        var firstByName: [String: Entry] = [:], secondByName: [String: Entry] = [:]
        for entry in first where firstByName[entry.name] == nil { firstByName[entry.name] = entry }
        for entry in second where secondByName[entry.name] == nil { secondByName[entry.name] = entry }
        func named(_ name: String) -> String { prefix.map { "\($0): \(name)" } ?? name }

        var result: [EntryDifference] = []
        for name in Set(firstByName.keys).union(secondByName.keys).sorted() {
            switch (firstByName[name], secondByName[name]) {
            case (let a?, nil):
                result.append(EntryDifference(name: named(name), change: .onlyInFirst, guid: a.guid))
            case (nil, let b?):
                result.append(EntryDifference(name: named(name), change: .onlyInSecond, guid: b.guid))
            case (let a?, let b?) where a.data != b.data:
                // An IFF inside an archive: compare its chunks.
                if prefix == nil, ContainerKind(header: a.data) == .iff, ContainerKind(header: b.data) == .iff,
                   let firstIFF = try? IFFFile(bytes: a.data), let secondIFF = try? IFFFile(bytes: b.data) {
                    result += differences(chunks(of: firstIFF), chunks(of: secondIFF), prefix: name)
                } else {
                    result.append(EntryDifference(name: named(name), change: .changed, guid: b.guid ?? a.guid))
                }
            default:
                continue
            }
        }
        return result
    }
}
