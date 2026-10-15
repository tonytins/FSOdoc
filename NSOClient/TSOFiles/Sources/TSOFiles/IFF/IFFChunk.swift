import Foundation

/// A typed IFF chunk, parsed from an ``IFFChunkRecord``.
///
/// Each conforming type ports one of FreeSO's `IffChunk` subclasses and keeps
/// its parsing behavior. Chunks are values: parse one with
/// ``IFFFile/chunk(_:id:)`` or ``IFFFile/chunks(_:)``.
public protocol IFFChunk: Sendable {
    /// The four-character type code this type parses, such as `BHAV`.
    static var typeCode: String { get }

    /// The chunk ID from the IFF header.
    var id: UInt16 { get }

    /// The chunk label from the IFF header.
    var label: String { get }

    /// Parses a chunk record.
    init(record: IFFChunkRecord) throws(IFFChunkError)
}

/// An error from parsing a chunk's contents.
public enum IFFChunkError: Error, Equatable, Sendable {
    /// The chunk data ends early.
    case truncated(typeCode: String, id: UInt16, EndOfDataError)
    /// The chunk data is malformed in a way the 2017 reader would also reject.
    case invalid(typeCode: String, id: UInt16, reason: String)
}

/// A malformed value inside a chunk, mapped to ``IFFChunkError/invalid(typeCode:id:reason:)``.
struct ChunkFormatError: Error {
    var reason: String
}

extension IFFChunkRecord {
    /// Runs a parser over the chunk's data and maps its errors to ``IFFChunkError``.
    ///
    /// The parser may throw ``EndOfDataError`` or ``ChunkFormatError``.
    func parse<Result>(
        byteOrder: ByteOrder, _ parser: (inout ByteReader) throws -> Result
    ) throws(IFFChunkError) -> Result {
        var reader = ByteReader(data, byteOrder: byteOrder)
        do {
            return try parser(&reader)
        } catch let error as EndOfDataError {
            throw .truncated(typeCode: typeCode, id: id, error)
        } catch let error as ChunkFormatError {
            throw .invalid(typeCode: typeCode, id: id, reason: error.reason)
        } catch {
            throw .invalid(typeCode: typeCode, id: id, reason: String(describing: error))
        }
    }
}

extension IFFFile {
    /// Parses the first chunk of a type with the given ID, or returns `nil` if there's none.
    public func chunk<Chunk: IFFChunk>(_ type: Chunk.Type, id: UInt16) throws(IFFChunkError) -> Chunk? {
        guard let record = chunk(ofType: Chunk.typeCode, id: id) else { return nil }
        return try Chunk(record: record)
    }

    /// Parses every chunk of a type, in file order.
    public func chunks<Chunk: IFFChunk>(_ type: Chunk.Type) throws(IFFChunkError) -> [Chunk] {
        var parsed: [Chunk] = []
        for record in chunks(ofType: Chunk.typeCode) {
            parsed.append(try Chunk(record: record))
        }
        return parsed
    }
}

extension ByteReader {
    /// Reads a 32-bit count and checks that it isn't negative, as .NET's array allocation does.
    mutating func readCount32() throws -> Int {
        let count = Int(try readInt32())
        guard count >= 0 else { throw ChunkFormatError(reason: "negative count \(count)") }
        return count
    }
}
