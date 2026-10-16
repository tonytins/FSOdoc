import Foundation

/// The type of a DBPF entry. TSO's audio type IDs come from `sys/tsoaudio.ini`.
///
/// A struct rather than an enum, because archives can hold types not listed here.
public struct DBPFTypeID: RawRepresentable, Hashable, Sendable {
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let xa = Self(rawValue: 0x1D07_EB4B)
    public static let utk = Self(rawValue: 0x1B6B_9806)
    public static let wav = Self(rawValue: 0xBB70_51F5)
    public static let mp3 = Self(rawValue: 0x3CEC_2B47)
    public static let track = Self(rawValue: 0x5D73_A611)
    public static let hit = Self(rawValue: 0x7B1A_CFCD)
    public static let soundEffect = Self(rawValue: 0x2026_960B)
}

/// The resource group of a DBPF entry. TSO's groups come from `sys/tsosounddata.ini`.
public struct DBPFGroupID: RawRepresentable, Hashable, Sendable {
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let multiplayer = Self(rawValue: 0x29DD_0888)
    public static let custom = Self(rawValue: 0x29DA_A4A6)
    public static let customTracks = Self(rawValue: 0x29D9_359D)
    public static let tracks = Self(rawValue: 0xA9C6_C89A)
    public static let trackDefinitions = Self(rawValue: 0xFDBD_BF87)
    public static let tsov2 = Self(rawValue: 0x69C6_C943)
    public static let samples = Self(rawValue: 0x9DBD_BF89)
    public static let hitLists = Self(rawValue: 0x9DBD_BF74)
    public static let hitListsTemp = Self(rawValue: 0xC9C6_C9B3)
    public static let stings = Self(rawValue: 0xDDBD_BF8C)
    public static let hitLabUI = Self(rawValue: 0x1D69_62CF)
    public static let hitLabTestSamples = Self(rawValue: 0x1D8A_8B4F)
    public static let hitLabTest = Self(rawValue: 0xBD6E_5937)
    public static let expansionPack2 = Self(rawValue: 0xDDE8_F5C6)
    public static let expansionPack5Samples = Self(rawValue: 0x8A6F_CC30)
}

/// A database-packed file (DBPF), which TSO uses for audio.
///
/// Matches FreeSO's `DBPFFile`, including its version handling: version 1.0
/// has creation and modification dates, versions below 2.0 use the 1.x index
/// header, and version 2.0 stores the index offset later in the header.
public struct DBPFArchive: Sendable {
    /// One file in the archive.
    public struct Entry: Sendable, Equatable {
        public var typeID: DBPFTypeID
        public var groupID: DBPFGroupID
        public var instanceID: UInt32
        /// The offset of the entry's data from the start of the archive.
        public var fileOffset: UInt32
        /// The size of the entry's data.
        public var fileSize: UInt32

        /// The ID FreeSO looks entries up by: `(instanceID << 32) + typeID`.
        public var lookupID: UInt64 { UInt64(instanceID) << 32 + UInt64(typeID.rawValue) }
    }

    public let majorVersion: UInt32
    public let minorVersion: UInt32
    /// Only present in version 1.0 archives.
    public let dateCreated: Int32?
    /// Only present in version 1.0 archives.
    public let dateModified: Int32?

    /// The archive's files in index order.
    public let entries: [Entry]

    private let bytes: Data
    private let entryIndexByLookupID: [UInt64: Int]

    /// Reads an archive from memory.
    public init(bytes: Data) throws(DBPFError) {
        let header: Header?
        do {
            header = try Self.readHeader(bytes)
        } catch {
            throw .truncated(error)
        }
        guard let header else { throw .notADBPFArchive }

        var byLookupID: [UInt64: Int] = [:]
        for (index, entry) in header.entries.enumerated() where byLookupID[entry.lookupID] == nil {
            byLookupID[entry.lookupID] = index // FreeSO's reader keeps the first entry for an ID
        }

        majorVersion = header.majorVersion
        minorVersion = header.minorVersion
        dateCreated = header.dateCreated
        dateModified = header.dateModified
        entries = header.entries
        self.bytes = bytes
        entryIndexByLookupID = byLookupID
    }

    /// Reads an archive from a file, memory-mapping it.
    public init(contentsOf url: URL) throws {
        try self.init(bytes: Data(contentsOf: url, options: .alwaysMapped))
    }

    // MARK: Lookup

    /// The first entry with the given instance and type.
    public func entry(instanceID: UInt32, typeID: DBPFTypeID) -> Entry? {
        let lookupID = UInt64(instanceID) << 32 + UInt64(typeID.rawValue)
        return entryIndexByLookupID[lookupID].map { entries[$0] }
    }

    /// Every entry of one type, in index order.
    ///
    /// FreeSO's reader throws when the archive has no entry of the type; this
    /// returns an empty array.
    public func entries(ofType typeID: DBPFTypeID) -> [Entry] {
        entries.filter { $0.typeID == typeID }
    }

    /// The data of an entry.
    public func data(for entry: Entry) throws(DBPFError) -> Data {
        let start = Int(entry.fileOffset)
        let end = start + Int(entry.fileSize)
        guard end <= bytes.count else { throw .entryOutOfBounds(entry) }
        return bytes.subdata(in: (bytes.startIndex + start)..<(bytes.startIndex + end))
    }

    // MARK: Private

    private struct Header {
        var majorVersion: UInt32
        var minorVersion: UInt32
        var dateCreated: Int32?
        var dateModified: Int32?
        var entries: [Entry]
    }

    /// Reads the header and index, or returns `nil` if the magic isn't `DBPF`.
    private static func readHeader(_ bytes: Data) throws(EndOfDataError) -> Header? {
        var reader = ByteReader(bytes, byteOrder: .littleEndian)
        guard try reader.readASCII(length: 4) == "DBPF" else { return nil }

        let majorVersion = try reader.readUInt32()
        let minorVersion = try reader.readUInt32()
        // Computed as in FreeSO, so the version comparisons below behave the same.
        let version = Double(majorVersion) + Double(minorVersion) / 10.0
        try reader.skip(12)

        var dateCreated: Int32?
        var dateModified: Int32?
        if version == 1.0 {
            dateCreated = try reader.readInt32()
            dateModified = try reader.readInt32()
        }
        if version < 2.0 {
            _ = try reader.readUInt32() // index major version
        }
        let entryCount = try reader.readUInt32()
        var indexOffset: UInt32 = 0
        if version < 2.0 {
            indexOffset = try reader.readUInt32()
        }
        _ = try reader.readUInt32() // index size
        if version == 2.0 {
            _ = try reader.readUInt32() // index minor version
            indexOffset = try reader.readUInt32()
        }
        // FreeSO's reader then skips padding, but seeks to the index right after, so the skip has no effect.
        try reader.seek(to: Int(indexOffset))

        var entries: [Entry] = []
        for _ in 0..<entryCount {
            entries.append(Entry(
                typeID: DBPFTypeID(rawValue: try reader.readUInt32()),
                groupID: DBPFGroupID(rawValue: try reader.readUInt32()),
                instanceID: try reader.readUInt32(),
                fileOffset: try reader.readUInt32(),
                fileSize: try reader.readUInt32()))
        }
        return Header(majorVersion: majorVersion, minorVersion: minorVersion,
                      dateCreated: dateCreated, dateModified: dateModified, entries: entries)
    }
}

/// An error from reading a DBPF archive.
public enum DBPFError: Error, Equatable, Sendable {
    /// The file doesn't start with `DBPF`.
    case notADBPFArchive
    /// The header or index ends early.
    case truncated(EndOfDataError)
    /// An entry's data lies outside the archive.
    case entryOutOfBounds(DBPFArchive.Entry)
}
