import Foundation
import Testing
@testable import TSOFiles

struct DBPFFixture {
    var type: DBPFTypeID
    var group: DBPFGroupID = .samples
    var instance: UInt32
    var contents: Data
}

/// Builds a DBPF archive in the 1.0 or 2.0 header layout the 2017 reader expects.
func makeDBPF(_ files: [DBPFFixture], majorVersion: UInt32 = 1, minorVersion: UInt32 = 0) -> Data {
    let isVersion2 = majorVersion == 2 && minorVersion == 0
    var writer = ByteWriter()
    writer.ascii("DBPF")
    writer.uint32(majorVersion)
    writer.uint32(minorVersion)
    writer.raw(repeatElement(UInt8(0), count: 12))

    if !isVersion2 {
        writer.int32(1_000) // date created
        writer.int32(2_000) // date modified
        writer.uint32(7)    // index major version
    }
    writer.uint32(UInt32(files.count))
    let indexOffsetPosition: Int
    if isVersion2 {
        writer.uint32(UInt32(files.count * 20)) // index size
        writer.uint32(0)                        // index minor version
        indexOffsetPosition = writer.count
        writer.uint32(0)                        // index offset, patched below
    } else {
        indexOffsetPosition = writer.count
        writer.uint32(0)                        // index offset, patched below
        writer.uint32(UInt32(files.count * 20)) // index size
    }

    var offsets: [Int] = []
    for file in files {
        offsets.append(writer.count)
        writer.raw(file.contents)
    }
    writer.patchUInt32(UInt32(writer.count), at: indexOffsetPosition)
    for (file, offset) in zip(files, offsets) {
        writer.uint32(file.type.rawValue)
        writer.uint32(file.group.rawValue)
        writer.uint32(file.instance)
        writer.uint32(UInt32(offset))
        writer.uint32(UInt32(file.contents.count))
    }
    return writer.bytes
}

@Suite struct DBPFArchiveTests {
    @Test func readsAVersionOneArchive() throws {
        let archive = try DBPFArchive(bytes: makeDBPF([
            DBPFFixture(type: .xa, instance: 10, contents: Data("XA".utf8)),
            DBPFFixture(type: .utk, group: .tsov2, instance: 11, contents: Data("UTK!".utf8)),
        ]))

        #expect(archive.dateCreated == 1_000)
        #expect(archive.dateModified == 2_000)
        #expect(archive.entries.count == 2)
        let utk = try #require(archive.entry(instanceID: 11, typeID: .utk))
        #expect(utk.groupID == .tsov2)
        #expect(try archive.data(for: utk) == Data("UTK!".utf8))
    }

    @Test func readsAVersionTwoArchive() throws {
        let archive = try DBPFArchive(bytes: makeDBPF([
            DBPFFixture(type: .hit, instance: 3, contents: Data([1, 2, 3])),
        ], majorVersion: 2))

        #expect(archive.dateCreated == nil)
        let hit = try #require(archive.entry(instanceID: 3, typeID: .hit))
        #expect(try archive.data(for: hit) == Data([1, 2, 3]))
    }

    @Test func packsLookupIDsAsFreeSODoes() {
        let entry = DBPFArchive.Entry(typeID: .xa, groupID: .samples, instanceID: 0x0102_0304,
                                      fileOffset: 0, fileSize: 0)
        #expect(entry.lookupID == 0x0102_0304_1D07_EB4B)
    }

    @Test func keepsTheFirstEntryForARepeatedID() throws {
        let archive = try DBPFArchive(bytes: makeDBPF([
            DBPFFixture(type: .xa, instance: 1, contents: Data([1])),
            DBPFFixture(type: .xa, instance: 1, contents: Data([2])),
        ]))
        let first = try #require(archive.entry(instanceID: 1, typeID: .xa))
        #expect(try archive.data(for: first) == Data([1]))
        #expect(archive.entries(ofType: .xa).count == 2)
    }

    @Test func returnsNoEntriesForAMissingType() throws {
        let archive = try DBPFArchive(bytes: makeDBPF([]))
        #expect(archive.entries(ofType: .mp3).isEmpty)
    }

    @Test func rejectsOtherFiles() {
        #expect(throws: DBPFError.notADBPFArchive) { try DBPFArchive(bytes: Data("FAR!byAZ".utf8)) }
    }

    @Test func rejectsATruncatedIndex() {
        let bytes = makeDBPF([DBPFFixture(type: .xa, instance: 1, contents: Data([1]))]).dropLast(4)
        #expect(throws: DBPFError.self) { try DBPFArchive(bytes: Data(bytes)) }
    }

    @Test func rejectsEntriesOutsideTheArchive() throws {
        let archive = try DBPFArchive(bytes: makeDBPF([]))
        let bogus = DBPFArchive.Entry(typeID: .xa, groupID: .samples, instanceID: 1, fileOffset: 500, fileSize: 10)
        #expect(throws: DBPFError.entryOutOfBounds(bogus)) { try archive.data(for: bogus) }
    }
}
