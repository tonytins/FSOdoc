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

    // MARK: Lookup

    /// Every chunk of one type, in file order.
    public func chunks(ofType typeCode: String) -> [IFFChunkRecord] {
        chunks.filter { $0.typeCode == typeCode }
    }

    /// The first chunk with the given type and ID, as the 2017 lookup tables keep.
    public func chunk(ofType typeCode: String, id: UInt16) -> IFFChunkRecord? {
        chunks.first { $0.typeCode == typeCode && $0.id == id }
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
