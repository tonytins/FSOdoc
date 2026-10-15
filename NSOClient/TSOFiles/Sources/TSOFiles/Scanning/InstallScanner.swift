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
    /// IFF files found inside FAR1 archives and parsed.
    public var nestedIFFCount = 0
    /// Files that aren't a recognized container.
    public var otherFileCount = 0
    /// Everything that failed to read, in path order.
    public var failures: [ScanFailure] = []

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

    public init(far1Variant: FAR1Archive.Variant = .b, readsEntries: Bool = true) {
        self.far1Variant = far1Variant
        self.readsEntries = readsEntries
    }

    /// Scans every regular file under `root`, in sorted path order.
    ///
    /// - Throws: An error only if `root` can't be listed. Problems with
    ///   individual files are collected in the report.
    public func scan(directory root: URL) throws -> ScanReport {
        var report = ScanReport()
        for url in try regularFiles(under: root) {
            let path = relativePath(of: url, under: root)
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

    private static func containerKind(of url: URL) throws -> ContainerKind? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return ContainerKind(header: try handle.read(upToCount: 12) ?? Data())
    }

    private func scanContainer(_ kind: ContainerKind, at url: URL, path: String, into report: inout ScanReport) {
        do {
            switch kind {
            case .far1:
                let archive = try FAR1Archive(contentsOf: url, variant: far1Variant)
                guard readsEntries else { return }
                for entry in archive.entries {
                    let wasIFF = check(path: path, entry: entry.fileName, into: &report) {
                        let data = try archive.data(for: entry)
                        guard ContainerKind(header: data) == .iff else { return false }
                        _ = try IFFFile(bytes: data)
                        return true
                    }
                    if wasIFF == true { report.nestedIFFCount += 1 }
                }
            case .far3:
                let archive = try FAR3Archive(contentsOf: url)
                guard readsEntries else { return }
                for entry in archive.entries {
                    check(path: path, entry: "\(entry.fileName) [\(entry.assetID)]", into: &report) {
                        _ = try archive.data(for: entry)
                    }
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
                _ = try IFFFile(contentsOf: url)
            }
        } catch {
            report.failures.append(ScanFailure(path: path, entry: nil, message: String(describing: error)))
        }
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

    private func regularFiles(under root: URL) throws -> [URL] {
        // On Linux the enumerator silently yields nothing for a missing directory, so check first.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: root.path])
        }
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: root.path])
        }
        var files: [URL] = []
        for case let url as URL in enumerator where (try? url.resourceValues(forKeys: Set(keys)))?.isRegularFile == true {
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }

    private func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return filePath }
        return String(filePath.dropFirst(rootPath.count).drop { $0 == "/" })
    }
}
