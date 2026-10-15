import Foundation

/// The 64-bit ID of a TSO asset: a file ID and a type ID from a FAR3 entry.
///
/// FreeSO packs it as `(fileID << 32) | typeID`, and content files such as
/// outfits and appearances refer to each other by that packed value.
public struct AssetID: Hashable, Sendable, CustomStringConvertible {
    public var fileID: UInt32
    public var typeID: UInt32

    public init(fileID: UInt32, typeID: UInt32) {
        self.fileID = fileID
        self.typeID = typeID
    }

    /// Unpacks an ID stored as `(fileID << 32) | typeID`.
    public init(packed: UInt64) {
        self.init(fileID: UInt32(truncatingIfNeeded: packed >> 32), typeID: UInt32(truncatingIfNeeded: packed))
    }

    /// The ID packed as `(fileID << 32) | typeID`.
    public var packed: UInt64 { UInt64(fileID) << 32 | UInt64(typeID) }

    public var description: String { "0x" + String(packed, radix: 16, uppercase: true) }
}

/// A FAR version 3 archive, the TSO container for avatar, UI, and other assets.
///
/// Matches FreeSO's `FAR3Archive`. The archive is a value over its bytes, so
/// reads from several threads need no locking; ``init(contentsOf:)`` maps the
/// file instead of copying it.
public struct FAR3Archive: Sendable {
    /// One file in the archive.
    public struct Entry: Sendable, Equatable {
        public var fileName: String
        public var assetID: AssetID
        /// The size of the data after decompression.
        public var decompressedSize: UInt32
        /// The 24-bit compressed size field.
        public var compressedSize: UInt32
        /// 0x80 for a Persist container, 0x00 for raw data.
        public var dataType: UInt8
        /// The offset of the file data from the start of the archive.
        public var dataOffset: UInt32
        /// 1 if the data is RefPack-compressed.
        public var compressionFlag: UInt8
        /// An unknown byte that may count accesses.
        public var accessCount: UInt8

        /// Whether the 2017 reader treats this entry as compressed.
        public var isCompressed: Bool { compressionFlag == 0x01 }
    }

    /// The archive's files in manifest order.
    public let entries: [Entry]

    private let bytes: Data
    private let entryIndexByName: [String: Int]
    private let entryIndexByFileID: [UInt32: Int]

    /// Reads an archive from memory.
    public init(bytes: Data) throws(FAR3Error) {
        let manifest: [Entry]?
        do {
            manifest = try Self.readManifest(bytes)
        } catch {
            throw .truncated(error)
        }
        guard let manifest else { throw .notAFAR3Archive }

        var byName: [String: Int] = [:]
        var byFileID: [UInt32: Int] = [:]
        for (index, entry) in manifest.enumerated() {
            // The 2017 reader keeps the first entry for a name...
            if byName[entry.fileName] == nil { byName[entry.fileName] = index }
            // ...but fails on a repeated file ID (Dictionary.Add throws).
            guard byFileID[entry.assetID.fileID] == nil else {
                throw .duplicateFileID(entry.assetID.fileID)
            }
            byFileID[entry.assetID.fileID] = index
        }

        self.entries = manifest
        self.bytes = bytes
        self.entryIndexByName = byName
        self.entryIndexByFileID = byFileID
    }

    /// Reads an archive from a file, memory-mapping it.
    public init(contentsOf url: URL) throws {
        try self.init(bytes: Data(contentsOf: url, options: .alwaysMapped))
    }

    // MARK: Lookup

    /// The first entry with the given file name, matched exactly.
    public func entry(named fileName: String) -> Entry? {
        entryIndexByName[fileName].map { entries[$0] }
    }

    /// The entry with the given file ID.
    public func entry(fileID: UInt32) -> Entry? {
        entryIndexByFileID[fileID].map { entries[$0] }
    }

    /// The entry with the given asset ID. Both the file ID and the type ID must match.
    public func entry(id: AssetID) -> Entry? {
        guard let entry = entry(fileID: id.fileID), entry.assetID.typeID == id.typeID else { return nil }
        return entry
    }

    // MARK: Data

    /// The data of an entry, decompressed if needed.
    ///
    /// For a compressed entry, the 2017 reader skips 9 bytes, reads the
    /// compressed length and a compression ID, and decompresses only if the ID is
    /// RefPack (`0xFB10`). Otherwise it returns the raw bytes from the entry's start.
    public func data(for entry: Entry) throws(FAR3Error) -> Data {
        let payload: Payload
        do {
            payload = try readPayload(of: entry)
        } catch {
            throw .truncated(error)
        }

        switch payload {
        case .raw(let data):
            return data
        case .refPack(let compressed, let decompressedSize):
            do {
                return try RefPack.decompress(compressed, decompressedSize: decompressedSize)
            } catch {
                throw .decompressionFailed(fileName: entry.fileName, error)
            }
        }
    }

    /// The data of the entry with the given asset ID.
    public func data(for id: AssetID) throws(FAR3Error) -> Data {
        guard let entry = entry(id: id) else { throw .entryNotFound(id) }
        return try data(for: entry)
    }

    // MARK: Private

    private enum Payload {
        case raw(Data)
        case refPack(Data, decompressedSize: Int)
    }

    private func readPayload(of entry: Entry) throws(EndOfDataError) -> Payload {
        var reader = ByteReader(bytes, byteOrder: .littleEndian)
        try reader.seek(to: Int(entry.dataOffset))
        guard entry.isCompressed else {
            return .raw(reader.readBytes(upTo: Int(entry.decompressedSize)))
        }

        try reader.skip(9)
        let compressedLength = Int(try reader.readUInt32())
        let compressionID = try reader.readUInt16()
        guard compressionID == 0xFB10 else {
            try reader.seek(to: Int(entry.dataOffset))
            return .raw(reader.readBytes(upTo: Int(entry.decompressedSize)))
        }

        reader.byteOrder = .bigEndian
        let decompressedSize = Int(try reader.readUInt24())
        return .refPack(reader.readBytes(upTo: compressedLength), decompressedSize: decompressedSize)
    }

    /// Reads the header and manifest, or returns `nil` if the header isn't FAR 3.
    private static func readManifest(_ bytes: Data) throws(EndOfDataError) -> [Entry]? {
        var reader = ByteReader(bytes, byteOrder: .littleEndian)
        let magic = try reader.readASCII(length: 8)
        let version = try reader.readUInt32()
        guard magic == "FAR!byAZ", version == 3 else { return nil }

        let manifestOffset = Int(try reader.readUInt32())
        try reader.seek(to: manifestOffset)
        let fileCount = try reader.readUInt32()

        var entries: [Entry] = []
        for _ in 0..<fileCount {
            let decompressedSize = try reader.readUInt32()
            let compressedSize = try reader.readUInt24()
            let dataType = try reader.readUInt8()
            let dataOffset = try reader.readUInt32()
            let compressionFlag = try reader.readUInt8()
            let accessCount = try reader.readUInt8()
            let nameLength = Int(try reader.readUInt16())
            let typeID = try reader.readUInt32()
            let fileID = try reader.readUInt32()
            let fileName = try reader.readASCII(length: nameLength)
            entries.append(Entry(
                fileName: fileName,
                assetID: AssetID(fileID: fileID, typeID: typeID),
                decompressedSize: decompressedSize,
                compressedSize: compressedSize,
                dataType: dataType,
                dataOffset: dataOffset,
                compressionFlag: compressionFlag,
                accessCount: accessCount))
        }
        return entries
    }
}

/// An error from reading a FAR3 archive.
public enum FAR3Error: Error, Equatable, Sendable {
    /// The header isn't `FAR!byAZ` with version 3.
    case notAFAR3Archive
    /// The header, manifest, or an entry ends early.
    case truncated(EndOfDataError)
    /// Two entries share a file ID. The 2017 reader fails on this too.
    case duplicateFileID(UInt32)
    /// No entry has the requested ID.
    case entryNotFound(AssetID)
    /// An entry's RefPack data is corrupt.
    case decompressionFailed(fileName: String, RefPackError)
}
