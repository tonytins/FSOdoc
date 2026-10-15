import Foundation
import Testing
@testable import TSOFiles

// MARK: - Fixtures

struct FAR1Fixture {
    var name: String
    var contents: Data
}

/// Builds a FAR1 archive: header, file data, then the manifest.
func makeFAR1(_ files: [FAR1Fixture], variant: FAR1Archive.Variant) -> Data {
    var writer = ByteWriter()
    writer.ascii("FAR!byAZ")
    writer.uint32(1)
    writer.uint32(0) // manifest offset, patched below

    var offsets: [Int] = []
    for file in files {
        offsets.append(writer.count)
        writer.raw(file.contents)
    }

    writer.patchUInt32(UInt32(writer.count), at: 12)
    writer.uint32(UInt32(files.count))
    for (file, offset) in zip(files, offsets) {
        writer.int32(Int32(file.contents.count))
        writer.int32(Int32(file.contents.count))
        writer.int32(Int32(offset))
        switch variant {
        case .a: writer.int32(Int32(file.name.utf8.count))
        case .b: writer.int16(Int16(file.name.utf8.count))
        }
        writer.ascii(file.name)
    }
    return writer.bytes
}

struct FAR3Fixture {
    var name: String
    var id: AssetID
    var stored: Data
    var decompressedSize: UInt32
    var compressionFlag: UInt8 = 0
}

/// Builds a FAR3 archive: header, stored file data, then the manifest.
func makeFAR3(_ files: [FAR3Fixture]) -> Data {
    var writer = ByteWriter()
    writer.ascii("FAR!byAZ")
    writer.uint32(3)
    writer.uint32(0)

    var offsets: [Int] = []
    for file in files {
        offsets.append(writer.count)
        writer.raw(file.stored)
    }

    writer.patchUInt32(UInt32(writer.count), at: 12)
    writer.uint32(UInt32(files.count))
    for (file, offset) in zip(files, offsets) {
        writer.uint32(file.decompressedSize)
        writer.uint24(UInt32(file.stored.count))
        writer.uint8(file.compressionFlag == 1 ? 0x80 : 0x00)
        writer.uint32(UInt32(offset))
        writer.uint8(file.compressionFlag)
        writer.uint8(0)
        writer.uint16(UInt16(file.name.utf8.count))
        writer.uint32(file.id.typeID)
        writer.uint32(file.id.fileID)
        writer.ascii(file.name)
    }
    return writer.bytes
}

/// Wraps a RefPack stream in the Persist header layout the 2017 reader expects.
func persistContainer(refPack stream: Data, decompressedSize: UInt32, compressionID: UInt16 = 0xFB10) -> Data {
    var writer = ByteWriter()
    writer.raw(repeatElement(UInt8(0), count: 9))
    writer.uint32(UInt32(stream.count))
    writer.uint16(compressionID)
    writer.bigEndian = true
    writer.uint24(decompressedSize)
    writer.raw(stream)
    return writer.bytes
}

// MARK: - FAR1

@Suite struct FAR1ArchiveTests {
    @Test(arguments: [FAR1Archive.Variant.a, .b])
    func readsEntriesAndData(variant: FAR1Archive.Variant) throws {
        let bytes = makeFAR1([
            FAR1Fixture(name: "chair.iff", contents: Data("CHAIR".utf8)),
            FAR1Fixture(name: "table.iff", contents: Data("TABLE!".utf8)),
        ], variant: variant)

        let archive = try FAR1Archive(bytes: bytes, variant: variant)

        #expect(archive.entries.map(\.fileName) == ["chair.iff", "table.iff"])
        let table = try #require(archive.entry(named: "table.iff"))
        #expect(try archive.data(for: table) == Data("TABLE!".utf8))
    }

    @Test func rejectsAnotherVersion() {
        var bytes = makeFAR1([], variant: .b)
        bytes[8] = 3
        #expect(throws: FAR1Error.notAFAR1Archive) { try FAR1Archive(bytes: bytes, variant: .b) }
    }

    @Test func rejectsATruncatedManifest() {
        let bytes = makeFAR1([FAR1Fixture(name: "a.iff", contents: Data([1]))], variant: .b).dropLast(2)
        #expect(throws: FAR1Error.self) { try FAR1Archive(bytes: Data(bytes), variant: .b) }
    }

    @Test func rejectsEntriesOutsideTheArchive() throws {
        let archive = try FAR1Archive(bytes: makeFAR1([], variant: .b), variant: .b)
        let bogus = FAR1Archive.Entry(fileName: "x", dataLength: 10, compressedLength: 10, dataOffset: 1_000)
        #expect(throws: FAR1Error.entryOutOfBounds(fileName: "x")) { try archive.data(for: bogus) }
    }
}

// MARK: - FAR3

@Suite struct FAR3ArchiveTests {
    @Test func packsAssetIDsAsFreeSODoes() {
        let id = AssetID(fileID: 0x1234_5678, typeID: 0x9ABC_DEF0)
        #expect(id.packed == 0x1234_5678_9ABC_DEF0)
        #expect(AssetID(packed: id.packed) == id)
    }

    @Test func readsRawEntries() throws {
        let mesh = AssetID(fileID: 7, typeID: 2)
        let archive = try FAR3Archive(bytes: makeFAR3([
            FAR3Fixture(name: "a.mesh", id: mesh, stored: Data("MESH".utf8), decompressedSize: 4),
        ]))

        #expect(try archive.data(for: mesh) == Data("MESH".utf8))
        #expect(archive.entry(named: "a.mesh")?.assetID == mesh)
    }

    @Test func requiresTheTypeIDToMatch() throws {
        let archive = try FAR3Archive(bytes: makeFAR3([
            FAR3Fixture(name: "a", id: AssetID(fileID: 7, typeID: 2), stored: Data([1]), decompressedSize: 1),
        ]))
        let wrongType = AssetID(fileID: 7, typeID: 3)
        #expect(archive.entry(id: wrongType) == nil)
        #expect(throws: FAR3Error.entryNotFound(wrongType)) { try archive.data(for: wrongType) }
    }

    @Test func decompressesRefPackEntries() throws {
        let id = AssetID(fileID: 1, typeID: 1)
        let stream = Data([0x0E, 0x01, 0x61, 0x62, 0xFC, 0x00, 0x00])
        let archive = try FAR3Archive(bytes: makeFAR3([
            FAR3Fixture(name: "c", id: id, stored: persistContainer(refPack: stream, decompressedSize: 8),
                        decompressedSize: 8, compressionFlag: 1),
        ]))

        #expect(try archive.data(for: id) == Data("abababab".utf8))
    }

    @Test func returnsRawBytesWhenTheCompressionIDIsNotRefPack() throws {
        let id = AssetID(fileID: 1, typeID: 1)
        let stored = persistContainer(refPack: Data([1, 2, 3]), decompressedSize: 3, compressionID: 0x1234)
        let archive = try FAR3Archive(bytes: makeFAR3([
            FAR3Fixture(name: "c", id: id, stored: stored, decompressedSize: 6, compressionFlag: 1),
        ]))

        // The 2017 reader seeks back to the entry start and returns decompressedSize raw bytes.
        #expect(try archive.data(for: id) == stored.prefix(6))
    }

    @Test func keepsTheFirstEntryForARepeatedName() throws {
        let archive = try FAR3Archive(bytes: makeFAR3([
            FAR3Fixture(name: "same", id: AssetID(fileID: 1, typeID: 1), stored: Data([1]), decompressedSize: 1),
            FAR3Fixture(name: "same", id: AssetID(fileID: 2, typeID: 1), stored: Data([2]), decompressedSize: 1),
        ]))
        #expect(archive.entry(named: "same")?.assetID.fileID == 1)
        #expect(archive.entries.count == 2)
    }

    @Test func rejectsARepeatedFileID() {
        let bytes = makeFAR3([
            FAR3Fixture(name: "a", id: AssetID(fileID: 5, typeID: 1), stored: Data([1]), decompressedSize: 1),
            FAR3Fixture(name: "b", id: AssetID(fileID: 5, typeID: 2), stored: Data([2]), decompressedSize: 1),
        ])
        #expect(throws: FAR3Error.duplicateFileID(5)) { try FAR3Archive(bytes: bytes) }
    }

    @Test func rejectsAFAR1Archive() {
        #expect(throws: FAR3Error.notAFAR3Archive) { try FAR3Archive(bytes: makeFAR1([], variant: .b)) }
    }
}
