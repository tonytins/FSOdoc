import Foundation

/// Labels and ranges for the constants in the ``BCON`` chunk with the same ID.
///
/// Ports FreeSO's `TRCN`. Version 0 has no range fields, and versions 0 and 1
/// store strings NUL-terminated instead of length-prefixed.
public struct TRCN: IFFChunk {
    public static let typeCode = "TRCN"

    /// The label and range of one constant.
    public struct Entry: Sendable, Equatable {
        public var flags: Int32
        public var unknown: Int32
        public var label: String
        public var comment: String
        /// Whether the editor limits the value to the range. Version 1 and up.
        public var rangeEnabled: UInt8 = 0
        public var lowRange: Int16 = 0
        public var highRange: Int16 = 100
    }

    public let id: UInt16
    public let label: String
    public let version: Int32
    public let entries: [Entry]

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (version, entries) = try record.parse(byteOrder: .littleEndian) { reader in
            _ = try reader.readInt32() // always zero
            let version = try reader.readInt32()
            _ = try reader.readInt32() // magic
            let count = try reader.readCount32()

            var entries: [Entry] = []
            for _ in 0..<count {
                var entry = Entry(
                    flags: try reader.readInt32(),
                    unknown: try reader.readInt32(),
                    label: try Self.readString(&reader, version: version),
                    comment: try Self.readString(&reader, version: version))
                if version > 0 {
                    entry.rangeEnabled = try reader.readUInt8()
                    entry.lowRange = try reader.readInt16()
                    entry.highRange = try reader.readInt16()
                }
                entries.append(entry)
            }
            return (version, entries)
        }
    }

    private static func readString(_ reader: inout ByteReader, version: Int32) throws -> String {
        guard version > 1 else { return try reader.readNullTerminatedLatin1() }
        guard let text = try reader.readDotNetString() else {
            throw ChunkFormatError(reason: "invalid string length prefix")
        }
        return text
    }
}
