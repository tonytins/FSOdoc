import Foundation

/// A container format the scanner recognizes by its first bytes.
public enum ContainerKind: String, CaseIterable, Sendable {
    case far1 = "FAR1"
    case far3 = "FAR3"
    case dbpf = "DBPF"
    case iff = "IFF"

    /// Identifies a container from the start of a file, or returns `nil`.
    public init?(header: Data) {
        let bytes = [UInt8](header.prefix(12))
        if bytes.starts(with: Array("DBPF".utf8)) {
            self = .dbpf
        } else if bytes.starts(with: Array("IFF FILE".utf8)) {
            self = .iff
        } else if bytes.count == 12, bytes.starts(with: Array("FAR!byAZ".utf8)) {
            let version = UInt32(bytes[8]) | UInt32(bytes[9]) << 8 | UInt32(bytes[10]) << 16 | UInt32(bytes[11]) << 24
            switch version {
            case 1: self = .far1
            case 3: self = .far3
            default: return nil
            }
        } else {
            return nil
        }
    }
}

/// A file or archive entry that failed to read.
public struct ScanFailure: Sendable, Equatable {
    /// The file's path, relative to the scanned directory.
    public var path: String
    /// The archive entry, if the failure was inside one.
    public var entry: String?
    /// A description of the error.
    public var message: String
}

/// The result of scanning a directory.
public struct ScanReport: Sendable {
    /// Containers opened, by kind.
    public var containerCounts: [ContainerKind: Int] = [:]
    /// Archive entries whose data was read (and decompressed, for FAR3).
    public var entriesRead = 0
    /// IFF files found inside archives and parsed.
    public var nestedIFFCount = 0
    /// Typed chunks parsed, by type code.
    public var chunkCounts: [String: Int] = [:]
    /// Files that aren't a recognized container.
    public var otherFileCount = 0
    /// Everything that failed to read, in path order.
    public var failures: [ScanFailure] = []
    /// Chunks that failed to parse but that nothing in their file refers to, so the
    /// game never loads them (for example, an old `TTAB` no `OBJD` points at).
    /// FreeSO's reader parses chunks only on demand, so it never meets these.
    public var unreferencedChunkFailures: [ScanFailure] = []

    /// Whether every recognized file read without error.
    public var isClean: Bool { failures.isEmpty }
}

/// Opens every FAR1, FAR3, DBPF, and IFF file under a directory and reports what fails.
///
/// This is the first check against a real TSO install: it proves the readers
/// handle the original files, without needing to know what any file contains.
public struct InstallScanner: Sendable {
    /// The FAR1 layout to assume. TSO installs use 1b; The Sims 1 uses 1a.
    public var far1Variant: FAR1Archive.Variant
    /// Whether to read every archive entry's data, or only the archive headers.
    public var readsEntries: Bool
    /// Whether to parse every chunk of a supported type inside each IFF.
    public var parsesChunks: Bool

    public init(far1Variant: FAR1Archive.Variant = .b, readsEntries: Bool = true, parsesChunks: Bool = true) {
        self.far1Variant = far1Variant
        self.readsEntries = readsEntries
        self.parsesChunks = parsesChunks
    }

    /// Scans every regular file under `root`, in sorted path order.
    ///
    /// - Throws: An error only if `root` can't be listed. Problems with
    ///   individual files are collected in the report.
    public func scan(directory root: URL) throws -> ScanReport {
        var report = ScanReport()
        for url in try DirectoryListing.regularFiles(under: root) {
            let path = DirectoryListing.relativePath(of: url, under: root)
            guard let kind = try? Self.containerKind(of: url) else {
                report.otherFileCount += 1
                continue
            }
            report.containerCounts[kind, default: 0] += 1
            scanContainer(kind, at: url, path: path, into: &report)
        }
        return report
    }

    // MARK: Private

    /// Mapping the file reads only the pages touched, so this costs about the same as
    /// reading 12 bytes, and unlike `FileHandle.read(upToCount:)` it needs no macOS 10.15.
    private static func containerKind(of url: URL) throws -> ContainerKind? {
        ContainerKind(header: try Data(contentsOf: url, options: .alwaysMapped).prefix(12))
    }

    private func scanContainer(_ kind: ContainerKind, at url: URL, path: String, into report: inout ScanReport) {
        do {
            switch kind {
            case .far1:
                let archive = try FAR1Archive(contentsOf: url, variant: far1Variant)
                guard readsEntries else { return }
                for entry in archive.entries {
                    let data = check(path: path, entry: entry.fileName, into: &report) { try archive.data(for: entry) }
                    if let data { scanNestedIFF(data, path: path, entry: entry.fileName, into: &report) }
                }
            case .far3:
                let archive = try FAR3Archive(contentsOf: url)
                guard readsEntries else { return }
                for entry in archive.entries {
                    let name = "\(entry.fileName) [\(entry.assetID)]"
                    let data = check(path: path, entry: name, into: &report) { try archive.data(for: entry) }
                    if let data { scanNestedIFF(data, path: path, entry: name, into: &report) }
                }
            case .dbpf:
                let archive = try DBPFArchive(contentsOf: url)
                guard readsEntries else { return }
                for entry in archive.entries {
                    let name = String(format: "type %08X instance %08X", entry.typeID.rawValue, entry.instanceID)
                    check(path: path, entry: name, into: &report) {
                        _ = try archive.data(for: entry)
                    }
                }
            case .iff:
                let iff = try IFFFile(contentsOf: url)
                scanChunks(of: iff, path: path, entryPrefix: nil, into: &report)
            }
        } catch {
            report.failures.append(ScanFailure(path: path, entry: nil, message: String(describing: error)))
        }
    }

    /// Parses archive entry data that is an IFF file, then its chunks.
    private func scanNestedIFF(_ data: Data, path: String, entry: String, into report: inout ScanReport) {
        guard ContainerKind(header: data) == .iff else { return }
        do {
            let iff = try IFFFile(bytes: data)
            report.nestedIFFCount += 1
            scanChunks(of: iff, path: path, entryPrefix: entry, into: &report)
        } catch {
            report.failures.append(ScanFailure(path: path, entry: entry, message: String(describing: error)))
        }
    }

    /// Parses every chunk of a supported type, recording each failure against its chunk.
    private func scanChunks(of iff: IFFFile, path: String, entryPrefix: String?, into report: inout ScanReport) {
        guard parsesChunks else { return }
        let referencedTables = Self.referencedTreeTables(in: iff)
        for record in iff.chunks {
            guard let chunkType = IFFChunkTypes.type(forCode: record.typeCode) else { continue }
            do {
                _ = try chunkType.init(record: record)
                report.chunkCounts[record.typeCode, default: 0] += 1
            } catch {
                let chunk = "\(record.typeCode) #\(record.id)"
                let entry = entryPrefix.map { "\($0): \(chunk)" } ?? chunk
                let failure = ScanFailure(path: path, entry: entry, message: String(describing: error))
                if record.typeCode == TTAB.typeCode, !referencedTables.contains(record.id) {
                    report.unreferencedChunkFailures.append(failure)
                } else {
                    report.failures.append(failure)
                }
            }
        }
    }

    /// The `TTAB` IDs that the file's objects point at through `treeTableID`.
    private static func referencedTreeTables(in iff: IFFFile) -> Set<UInt16> {
        var tables = Set<UInt16>()
        for record in iff.chunks(ofType: OBJD.typeCode) {
            if let object = try? OBJD(record: record) { tables.insert(object.treeTableID) }
        }
        return tables
    }

    /// Runs one entry check, counting it, or recording its error against the entry.
    @discardableResult
    private func check<Result>(
        path: String, entry: String, into report: inout ScanReport, _ body: () throws -> Result
    ) -> Result? {
        do {
            let result = try body()
            report.entriesRead += 1
            return result
        } catch {
            report.failures.append(ScanFailure(path: path, entry: entry, message: String(describing: error)))
            return nil
        }
    }
}
