import Foundation
import Testing
@testable import TSOFiles

struct ChunkFixture {
    var type: String
    var id: UInt16
    var label: String
    var contents: Data
    var flags: UInt16 = 0x10
    /// Overrides the size field, for testing bad sizes.
    var declaredSize: UInt32?
}

/// Builds an IFF file with the 2.5 header as Maxis wrote it (a NUL after "SIZE").
func makeIFF(_ chunks: [ChunkFixture]) -> Data {
    var writer = ByteWriter(bigEndian: true)
    writer.ascii("IFF FILE 2.5:TYPE FOLLOWED BY SIZE\0 JAMIE DOORNBOS & MAXIS 1", paddedTo: 60)
    writer.uint32(0)
    for chunk in chunks {
        writer.ascii(chunk.type, paddedTo: 4)
        writer.uint32(chunk.declaredSize ?? UInt32(chunk.contents.count + IFFFile.chunkHeaderSize))
        writer.uint16(chunk.id)
        writer.uint16(chunk.flags)
        writer.ascii(chunk.label, paddedTo: 64)
        writer.raw(chunk.contents)
    }
    return writer.bytes
}

@Suite struct IFFFileTests {
    @Test func readsChunkHeadersInBigEndian() throws {
        let iff = try IFFFile(bytes: makeIFF([
            ChunkFixture(type: "BHAV", id: 0x1000, label: "main", contents: Data([1, 2, 3])),
            ChunkFixture(type: "STR#", id: 0x0080, label: "names", contents: Data([4])),
        ]))

        #expect(iff.chunks.count == 2)
        let bhav = try #require(iff.chunk(ofType: "BHAV", id: 0x1000))
        #expect(bhav.label == "main")
        #expect(bhav.flags == 0x10)
        #expect(bhav.data == Data([1, 2, 3]))
        #expect(iff.chunks(ofType: "STR#").map(\.id) == [0x0080])
    }

    @Test func keepsChunkTypesTheOldReaderSkipped() throws {
        let iff = try IFFFile(bytes: makeIFF([ChunkFixture(type: "XYZW", id: 1, label: "", contents: Data([9]))]))
        #expect(iff.chunk(ofType: "XYZW", id: 1)?.data == Data([9]))
    }

    @Test func trimsOnlyTrailingNULsFromLabels() throws {
        let iff = try IFFFile(bytes: makeIFF([ChunkFixture(type: "OBJD", id: 1, label: "a\0b", contents: Data())]))
        #expect(iff.chunks.first?.label == "a\0b")
    }

    @Test func returnsTheFirstChunkForARepeatedID() throws {
        let iff = try IFFFile(bytes: makeIFF([
            ChunkFixture(type: "BCON", id: 4, label: "first", contents: Data()),
            ChunkFixture(type: "BCON", id: 4, label: "second", contents: Data()),
        ]))
        #expect(iff.chunk(ofType: "BCON", id: 4)?.label == "first")
    }

    @Test func acceptsTheVersionTwoHeader() throws {
        var bytes = makeIFF([])
        bytes.replaceSubrange(9..<12, with: Array("2.0".utf8))
        #expect(try IFFFile(bytes: bytes).chunks.isEmpty)
    }

    @Test func ignoresASingleTrailingByte() throws {
        let bytes = makeIFF([ChunkFixture(type: "BHAV", id: 1, label: "", contents: Data([1]))]) + [0x00]
        #expect(try IFFFile(bytes: bytes).chunks.count == 1)
    }

    @Test func keepsWhatExistsOfAFinalChunkThatRunsPastTheEnd() throws {
        let bytes = makeIFF([ChunkFixture(type: "BHAV", id: 1, label: "", contents: Data([1, 2]), declaredSize: 76 + 10)])
        #expect(try IFFFile(bytes: bytes).chunks.first?.data == Data([1, 2]))
    }

    @Test func rejectsAChunkSmallerThanItsHeader() {
        let bytes = makeIFF([ChunkFixture(type: "BHAV", id: 2, label: "", contents: Data(), declaredSize: 10)])
        #expect(throws: IFFError.invalidChunkSize(typeCode: "BHAV", id: 2, size: 10, offset: 64)) {
            try IFFFile(bytes: bytes)
        }
    }

    @Test func rejectsATruncatedChunkHeader() {
        let bytes = makeIFF([]) + Data(repeating: 0x41, count: 10)
        #expect(throws: IFFError.self) { try IFFFile(bytes: bytes) }
    }

    @Test func rejectsOtherFiles() {
        #expect(throws: IFFError.notAnIFFFile) { try IFFFile(bytes: Data("not an iff".utf8)) }
        #expect(throws: IFFError.notAnIFFFile) { try IFFFile(bytes: Data(repeating: 0x20, count: 80)) }
    }
}
