import Foundation

/// One chunk in an IFF file, before its contents are parsed.
public struct IFFChunkRecord: Sendable, Equatable {
    /// The four-character type code, such as `BHAV`, `STR#`, or `OBJD`.
    public var typeCode: String
    /// The chunk ID. Chunks of one type are looked up by it.
    public var id: UInt16
    /// The chunk flags.
    public var flags: UInt16
    /// The chunk label, with trailing NUL characters removed.
    public var label: String
    /// The chunk's data, without its 76-byte header.
    public var data: Data
}

/// A Maxis IFF file: the container for objects, behavior, sprites, and strings.
///
/// Matches the container parsing in FreeSO's `IffFile.Read`. One difference:
/// the 2017 reader drops chunk types it has no class for, while this keeps every
/// chunk as an ``IFFChunkRecord``, so nothing is lost before typed parsing.
public struct IFFFile: Sendable {
    /// The headers the 2017 reader accepts, after removing NUL characters.
    static let acceptedSignatures: Set<String> = [
        "IFF FILE 2.5:TYPE FOLLOWED BY SIZE JAMIE DOORNBOS & MAXIS 1",
        "IFF FILE 2.0:TYPE FOLLOWED BY SIZE JAMIE DOORNBOS & MAXIS 1",
    ]

    /// The size of each chunk's header, which the size field includes.
    static let chunkHeaderSize = 76

    /// The offset of the resource map (`rsmp`) chunk, read but unused.
    public let resourceMapOffset: UInt32

    /// Every chunk in file order.
    public let chunks: [IFFChunkRecord]

    /// Reads an IFF file from memory.
    public init(bytes: Data) throws(IFFError) {
        var reader = ByteReader(bytes, byteOrder: .bigEndian)
        let signature: String
        do {
            signature = try reader.readASCII(length: 60).replacingOccurrences(of: "\0", with: "")
        } catch {
            throw .notAnIFFFile // fewer than 60 bytes
        }
        guard Self.acceptedSignatures.contains(signature) else { throw .notAnIFFFile }
        do {
            resourceMapOffset = try reader.readUInt32()
        } catch {
            throw .truncated(error)
        }
        chunks = try Self.readChunks(&reader)
    }

    /// Reads an IFF file from disk.
    public init(contentsOf url: URL) throws {
        try self.init(bytes: Data(contentsOf: url))
    }

    /// Builds a file from chunk records, as a patch result does.
    init(resourceMapOffset: UInt32, chunks: [IFFChunkRecord]) {
        self.resourceMapOffset = resourceMapOffset
        self.chunks = chunks
    }

    // MARK: Patching

    /// Returns this file with a PIFF patch applied.
    ///
    /// Matches `IffFile.Patch`: each entry patches or deletes the first chunk
    /// with its type and ID; ID changes are applied afterwards as swaps, which
    /// move both chunks to the end; then the patch file's other chunks are added
    /// where no chunk with their type and ID exists. Unlike 2017, entries and added
    /// chunks of types the 2017 reader didn't know are applied too.
    public func applying(_ patchFile: IFFFile) throws(PIFFError) -> IFFFile {
        guard let patchRecord = patchFile.chunk(ofType: PIFF.typeCode) else { throw .missingPatchChunk }
        let piff: PIFF
        do {
            piff = try PIFF(record: patchRecord)
        } catch {
            throw .invalidPatchChunk(error)
        }

        var patched = PatchedChunks(chunks)
        var moves: [(identity: Int, newID: UInt16)] = []
        for entry in piff.entries {
            guard let identity = patched.identity(typeCode: entry.typeCode, id: entry.chunkID) else { continue }
            if entry.isDeletion {
                patched.remove(identity)
                continue
            }
            try patched.update(identity) { record throws(PIFFError) in
                record.data = try entry.apply(to: record.data)
                if !entry.label.isEmpty { record.label = entry.label }
            }
            if entry.chunkID != entry.newChunkID { moves.append((identity, entry.newChunkID)) }
        }
        for move in moves {
            try patched.moveAndSwap(move.identity, to: move.newID)
        }

        // Added chunks go in groups by type, in the order each type first appears in the patch file.
        var typeOrder: [String] = []
        for record in patchFile.chunks where record.typeCode != PIFF.typeCode && !typeOrder.contains(record.typeCode) {
            typeOrder.append(record.typeCode)
        }
        for typeCode in typeOrder {
            for record in patchFile.chunks(ofType: typeCode)
            where patched.identity(typeCode: record.typeCode, id: record.id) == nil {
                patched.append(record)
            }
        }
        return IFFFile(resourceMapOffset: resourceMapOffset, chunks: patched.records)
    }

    /// The chunk list during patching, with the 2017 "first chunk for each type and ID" index.
    private struct PatchedChunks {
        private struct Key: Hashable {
            var typeCode: String
            var id: UInt16
        }

        private var items: [(identity: Int, record: IFFChunkRecord)] = []
        private var index: [Key: Int] = [:]
        private var nextIdentity = 0

        init(_ records: [IFFChunkRecord]) {
            for record in records {
                let identity = nextIdentity
                nextIdentity += 1
                items.append((identity, record))
                let key = Key(typeCode: record.typeCode, id: record.id)
                if index[key] == nil { index[key] = identity }
            }
        }

        var records: [IFFChunkRecord] { items.map(\.record) }

        func identity(typeCode: String, id: UInt16) -> Int? {
            index[Key(typeCode: typeCode, id: id)]
        }

        mutating func update(_ identity: Int, _ change: (inout IFFChunkRecord) throws(PIFFError) -> Void) throws(PIFFError) {
            guard let position = items.firstIndex(where: { $0.identity == identity }) else { return }
            try change(&items[position].record)
        }

        /// Removes a chunk and its index entry, like `IffFile.RemoveChunk`.
        @discardableResult
        mutating func remove(_ identity: Int) -> IFFChunkRecord? {
            guard let position = items.firstIndex(where: { $0.identity == identity }) else { return nil }
            let record = items.remove(at: position).record
            index[Key(typeCode: record.typeCode, id: record.id)] = nil
            return record
        }

        /// Adds a chunk at the end, like `IffFile.AddChunk`.
        mutating func append(_ record: IFFChunkRecord) {
            append(record, identity: nil)
        }

        /// Gives a chunk a new ID, swapping IDs with any chunk already there. Matches `MoveAndSwap`.
        mutating func moveAndSwap(_ identity: Int, to newID: UInt16) throws(PIFFError) {
            guard let position = items.firstIndex(where: { $0.identity == identity }) else { return }
            let current = items[position].record
            guard current.id != newID else { return }

            let targetIdentity = self.identity(typeCode: current.typeCode, id: newID)
            let target = targetIdentity.flatMap { remove($0) }
            guard var moved = remove(identity) else { return }
            let oldID = moved.id
            moved.id = newID
            try appendChecked(moved, identity: identity)
            if var target, let targetIdentity {
                target.id = oldID
                try appendChecked(target, identity: targetIdentity)
            }
        }

        /// `IffFile.AddChunk` throws when the type and ID are already indexed.
        private mutating func appendChecked(_ record: IFFChunkRecord, identity: Int) throws(PIFFError) {
            guard self.identity(typeCode: record.typeCode, id: record.id) == nil else {
                throw .duplicateChunk(typeCode: record.typeCode, id: record.id)
            }
            append(record, identity: identity)
        }

        private mutating func append(_ record: IFFChunkRecord, identity: Int?) {
            let identity = identity ?? {
                defer { nextIdentity += 1 }
                return nextIdentity
            }()
            items.append((identity, record))
            index[Key(typeCode: record.typeCode, id: record.id)] = identity
        }
    }

    // MARK: Lookup

    /// Every chunk of one type, in file order.
    public func chunks(ofType typeCode: String) -> [IFFChunkRecord] {
        chunks.filter { $0.typeCode == typeCode }
    }

    /// The first chunk with the given type and ID, as the 2017 lookup tables keep.
    public func chunk(ofType typeCode: String, id: UInt16) -> IFFChunkRecord? {
        chunks.first { $0.typeCode == typeCode && $0.id == id }
    }

    /// The first chunk of a type, whatever its ID.
    public func chunk(ofType typeCode: String) -> IFFChunkRecord? {
        chunks.first { $0.typeCode == typeCode }
    }

    // MARK: Private

    private struct ChunkHeader {
        var typeCode: String
        var size: Int
        var id: UInt16
        var flags: UInt16
        var label: String
    }

    private static func readChunks(_ reader: inout ByteReader) throws(IFFError) -> [IFFChunkRecord] {
        var chunks: [IFFChunkRecord] = []
        // The 2017 reader continues while at least two bytes remain.
        while reader.remaining >= 2 {
            let chunkStart = reader.offset
            let header: ChunkHeader
            do {
                header = try readChunkHeader(&reader)
            } catch {
                throw .truncated(error)
            }
            guard header.size >= chunkHeaderSize else {
                throw .invalidChunkSize(typeCode: header.typeCode, id: header.id, size: header.size, offset: chunkStart)
            }
            // Like .NET's ReadBytes, a final chunk that runs past the end keeps the bytes that exist.
            let data = reader.readBytes(upTo: header.size - chunkHeaderSize)
            chunks.append(IFFChunkRecord(typeCode: header.typeCode, id: header.id, flags: header.flags,
                                         label: header.label, data: data))
        }
        return chunks
    }

    private static func readChunkHeader(_ reader: inout ByteReader) throws(EndOfDataError) -> ChunkHeader {
        ChunkHeader(
            typeCode: try reader.readASCII(length: 4),
            size: Int(try reader.readUInt32()),
            id: try reader.readUInt16(),
            flags: try reader.readUInt16(),
            label: try reader.readASCII(length: 64).trimmingTrailingNULs())
    }
}

/// An error from reading an IFF file.
public enum IFFError: Error, Equatable, Sendable {
    /// The 60-byte header isn't one of the accepted IFF signatures.
    case notAnIFFFile
    /// The header or a chunk header ends early.
    case truncated(EndOfDataError)
    /// A chunk's size is smaller than its own header.
    case invalidChunkSize(typeCode: String, id: UInt16, size: Int, offset: Int)
}
