import Foundation

/// A patch to another IFF file: chunk edits, deletions, and ID changes.
///
/// Ports FreeSO's `PIFF` chunk. A `.piff` file is an IFF holding one `PIFF`
/// chunk, which names the IFF it patches, plus any whole chunks to add to it.
/// ``IFFFile/applying(_:)`` applies one.
public struct PIFF: IFFChunk {
    public static let typeCode = "PIFF"

    /// Whether a patch inserts bytes or skips bytes of the original.
    public enum PatchMode: UInt8, Sendable {
        case remove = 0
        case add = 1
    }

    /// One edit to a chunk's data.
    public struct Patch: Sendable, Equatable {
        /// Where the edit starts in the patched data.
        public var offset: UInt32
        /// How many bytes to add, or to skip in the original.
        public var size: UInt32
        public var mode: PatchMode
        /// The bytes to add. Empty for a removal.
        public var data: Data
    }

    /// The edits to one chunk.
    public struct Entry: Sendable, Equatable {
        public var typeCode: String
        public var chunkID: UInt16
        /// Whether to delete the chunk instead of patching it.
        public var isDeletion: Bool
        /// The new label, or an empty string to keep the old one.
        public var label: String = ""
        public var flags: UInt16 = 0
        /// The ID to move the chunk to. Version 0 can't move chunks.
        public var newChunkID: UInt16
        /// The size of the chunk data after patching.
        public var newDataSize: UInt32 = 0
        public var patches: [Patch] = []

        /// Applies the edits to a chunk's original data.
        ///
        /// Matches `PIFFEntry.Apply`: it copies original bytes up to each patch,
        /// then inserts or skips, then copies the rest. Where FreeSO's copy would
        /// run out of bounds, this throws instead.
        public func apply(to original: Data) throws(PIFFError) -> Data {
            let source = [UInt8](original)
            let addedBytes = patches.reduce(0) { $0 + ($1.mode == .add ? Int($1.size) : 0) }
            // Every output byte comes from the original or an added patch, so this bounds the size.
            guard Int(newDataSize) <= source.count + addedBytes else {
                throw .invalidSize(typeCode: typeCode, chunkID: chunkID)
            }

            var result = [UInt8]()
            result.reserveCapacity(Int(newDataSize))
            var sourceIndex = 0
            for patch in patches {
                let copyCount = Int(patch.offset) - result.count
                guard copyCount >= 0, sourceIndex + copyCount <= source.count else {
                    throw .patchOutOfBounds(typeCode: typeCode, chunkID: chunkID)
                }
                result.append(contentsOf: source[sourceIndex..<(sourceIndex + copyCount)])
                sourceIndex += copyCount
                switch patch.mode {
                case .add:
                    result.append(contentsOf: patch.data)
                case .remove:
                    sourceIndex += Int(patch.size)
                }
            }
            let remainder = Int(newDataSize) - result.count
            guard remainder >= 0 else { throw .patchOutOfBounds(typeCode: typeCode, chunkID: chunkID) }
            // FreeSO copies the remainder only when there is one, so a final removal may
            // skip past the end of the original. Shipped FreeSO patches rely on that.
            guard remainder > 0 else { return Data(result) }
            guard sourceIndex + remainder <= source.count else {
                throw .patchOutOfBounds(typeCode: typeCode, chunkID: chunkID)
            }
            result.append(contentsOf: source[sourceIndex..<(sourceIndex + remainder)])
            return Data(result)
        }
    }

    public let id: UInt16
    public let label: String
    public let version: UInt16
    /// The name of the IFF this patches, such as `chairs.iff`.
    public let sourceFileName: String
    public let entries: [Entry]

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (version, sourceFileName, entries) = try record.parse(byteOrder: .littleEndian) { reader in
            let version = try reader.readUInt16()
            let sourceFileName = try Self.readString(&reader)
            let count = Int(try reader.readUInt16())

            var entries: [Entry] = []
            for _ in 0..<count {
                let typeCode = try reader.readASCII(length: 4)
                let chunkID = try reader.readUInt16()
                let isDeletion = try reader.readUInt8() > 0
                var entry = Entry(typeCode: typeCode, chunkID: chunkID, isDeletion: isDeletion, newChunkID: chunkID)
                if !isDeletion {
                    entry.label = try Self.readString(&reader)
                    entry.flags = try reader.readUInt16()
                    if version > 0 { entry.newChunkID = try reader.readUInt16() }
                    entry.newDataSize = try reader.readUInt32()
                    let patchCount = try reader.readUInt32()
                    var lastOffset: UInt32 = 0
                    for _ in 0..<patchCount {
                        let (offset, overflow) = lastOffset.addingReportingOverflow(try Self.readVariableLength(&reader))
                        guard !overflow else { throw ChunkFormatError(reason: "patch offset overflows") }
                        lastOffset = offset
                        let size = try Self.readVariableLength(&reader)
                        let modeValue = try reader.readUInt8()
                        let mode: PatchMode = modeValue == PatchMode.add.rawValue ? .add : .remove
                        let data = mode == .add ? try reader.readBytes(Int(size)) : Data()
                        entry.patches.append(Patch(offset: offset, size: size, mode: mode, data: data))
                    }
                }
                entries.append(entry)
            }
            return (version, sourceFileName, entries)
        }
    }

    private static func readString(_ reader: inout ByteReader) throws -> String {
        guard let text = try reader.readDotNetString() else {
            throw ChunkFormatError(reason: "invalid string length prefix")
        }
        return text
    }

    /// Reads `IoBuffer.ReadVarLen`: 7 bits per byte, least significant group first.
    private static func readVariableLength(_ reader: inout ByteReader) throws -> UInt32 {
        var result: UInt32 = 0
        var shift: UInt32 = 0
        while true {
            guard shift < 35 else { throw ChunkFormatError(reason: "variable-length number runs past five bytes") }
            let byte = try reader.readUInt8()
            result |= UInt32(byte & 0x7F) << shift
            shift += 7
            if byte & 0x80 == 0 { return result }
        }
    }
}

/// An error from applying a PIFF.
public enum PIFFError: Error, Equatable, Sendable {
    /// The patch file has no `PIFF` chunk.
    case missingPatchChunk
    /// The patch chunk itself doesn't parse.
    case invalidPatchChunk(IFFChunkError)
    /// A patched size is larger than the original and added bytes could produce.
    case invalidSize(typeCode: String, chunkID: UInt16)
    /// A patch reaches outside the original data.
    case patchOutOfBounds(typeCode: String, chunkID: UInt16)
    /// Moving a chunk would give two chunks the same type and ID (FreeSO's `AddChunk` throws).
    case duplicateChunk(typeCode: String, id: UInt16)
}
