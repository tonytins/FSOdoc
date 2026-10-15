import Foundation

/// A FAR version 1 archive, used for object, floor, wall, and semi-global files.
///
/// Matches FreeSO's `FAR1Archive`. The archive keeps its bytes in memory;
/// ``init(contentsOf:variant:)`` maps the file instead of copying it.
public struct FAR1Archive: Sendable {
    /// The two layouts of version 1, which differ only in the file name length field.
    public enum Variant: Sendable {
        /// FAR 1a: a 32-bit file name length. The Sims 1 uses this.
        case a
        /// FAR 1b: a 16-bit file name length. TSO uses this.
        case b
    }

    /// One file in the archive.
    public struct Entry: Sendable, Equatable {
        /// The stored file name.
        public var fileName: String
        /// The uncompressed size, which is the number of bytes read.
        public var dataLength: Int
        /// The compressed size. FAR1 files are never compressed in practice.
        public var compressedLength: Int
        /// The offset of the file data from the start of the archive.
        public var dataOffset: Int
    }

    /// The archive's files in manifest order.
    public let entries: [Entry]

    private let bytes: Data

    /// Reads an archive from memory.
    public init(bytes: Data, variant: Variant) throws(FAR1Error) {
        let manifest: [Entry]?
        do {
            manifest = try Self.readManifest(bytes, variant: variant)
        } catch {
            throw .truncated(error)
        }
        guard let manifest else { throw .notAFAR1Archive }
        self.entries = manifest
        self.bytes = bytes
    }

    /// Reads an archive from a file, memory-mapping it.
    public init(contentsOf url: URL, variant: Variant) throws {
        try self.init(bytes: Data(contentsOf: url, options: .alwaysMapped), variant: variant)
    }

    /// The first entry with the given file name, matched exactly.
    public func entry(named fileName: String) -> Entry? {
        entries.first { $0.fileName == fileName }
    }

    /// The data of an entry.
    public func data(for entry: Entry) throws(FAR1Error) -> Data {
        guard entry.dataOffset >= 0, entry.dataLength >= 0,
              entry.dataOffset + entry.dataLength <= bytes.count else {
            throw .entryOutOfBounds(fileName: entry.fileName)
        }
        let start = bytes.startIndex + entry.dataOffset
        return bytes.subdata(in: start..<(start + entry.dataLength))
    }

    /// Reads the header and manifest, or returns `nil` if the header isn't FAR 1.
    private static func readManifest(_ bytes: Data, variant: Variant) throws(EndOfDataError) -> [Entry]? {
        var reader = ByteReader(bytes, byteOrder: .littleEndian)
        let magic = try reader.readASCII(length: 8)
        let version = try reader.readUInt32()
        guard magic == "FAR!byAZ", version == 1 else { return nil }

        let manifestOffset = Int(try reader.readUInt32())
        try reader.seek(to: manifestOffset)
        let fileCount = try reader.readUInt32()

        var entries: [Entry] = []
        for _ in 0..<fileCount {
            let dataLength = Int(try reader.readInt32())
            let compressedLength = Int(try reader.readInt32())
            let dataOffset = Int(try reader.readInt32())
            let nameLength = switch variant {
            case .a: Int(Int16(truncatingIfNeeded: try reader.readInt32())) // the 2017 reader casts to short
            case .b: Int(try reader.readInt16())
            }
            let fileName = try reader.readASCII(length: nameLength)
            entries.append(Entry(fileName: fileName, dataLength: dataLength,
                                 compressedLength: compressedLength, dataOffset: dataOffset))
        }
        return entries
    }
}

/// An error from reading a FAR1 archive.
public enum FAR1Error: Error, Equatable, Sendable {
    /// The header isn't `FAR!byAZ` with version 1.
    case notAFAR1Archive
    /// The header or manifest ends early.
    case truncated(EndOfDataError)
    /// An entry's data lies outside the archive.
    case entryOutOfBounds(fileName: String)
}
