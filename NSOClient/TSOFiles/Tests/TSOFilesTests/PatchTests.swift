import Foundation
import Testing
@testable import TSOFiles

/// One PIFF entry to write.
struct PatchEntryFixture {
    var type: String
    var id: UInt16
    var delete = false
    var label = ""
    var newID: UInt16?
    var newSize: UInt32 = 0
    /// (offset delta in the output, size, add data or nil for a removal)
    var patches: [(UInt32, UInt32, [UInt8]?)] = []
}

/// Writes a .NET length-prefixed string (lengths below 128 only).
func dotNetString(_ writer: inout ByteWriter, _ text: String) {
    writer.uint8(UInt8(text.utf8.count))
    writer.ascii(text)
}

/// Builds the data of a version 1 PIFF chunk.
func piffData(source: String, _ entries: [PatchEntryFixture]) -> Data {
    var writer = ByteWriter()
    writer.uint16(1)
    dotNetString(&writer, source)
    writer.uint16(UInt16(entries.count))
    for entry in entries {
        writer.ascii(entry.type, paddedTo: 4)
        writer.uint16(entry.id)
        writer.uint8(entry.delete ? 1 : 0)
        guard !entry.delete else { continue }
        dotNetString(&writer, entry.label)
        writer.uint16(0)
        writer.uint16(entry.newID ?? entry.id)
        writer.uint32(entry.newSize)
        writer.uint32(UInt32(entry.patches.count))
        for (delta, size, data) in entry.patches {
            writer.uint8(UInt8(delta))   // one-byte variable-length numbers suffice here
            writer.uint8(UInt8(size))
            writer.uint8(data == nil ? 0 : 1)
            if let data { writer.raw(data) }
        }
    }
    return writer.bytes
}

/// A patch file: the PIFF chunk plus any chunks to add.
func patchFile(source: String, _ entries: [PatchEntryFixture], adding: [ChunkFixture] = []) throws -> IFFFile {
    try IFFFile(bytes: makeIFF([ChunkFixture(type: "PIFF", id: 1, label: "", contents: piffData(source: source, entries))] + adding))
}

func chunkSummary(_ iff: IFFFile) -> [String] {
    iff.chunks.map { "\($0.typeCode)#\($0.id):\(String(decoding: $0.data, as: UTF8.self))" }
}

@Suite struct PIFFTests {
    let original: IFFFile

    init() throws {
        original = try IFFFile(bytes: makeIFF([
            ChunkFixture(type: "BHAV", id: 1, label: "one", contents: Data("abcdef".utf8)),
            ChunkFixture(type: "BHAV", id: 2, label: "two", contents: Data("222".utf8)),
            ChunkFixture(type: "STR#", id: 1, label: "names", contents: Data("s".utf8)),
        ]))
    }

    @Test func insertsAndRemovesBytes() throws {
        // "abcdef" -> keep "ab", insert "XY", skip "cd", keep "ef" -> "abXYef"
        let patch = try patchFile(source: "x.iff", [
            PatchEntryFixture(type: "BHAV", id: 1, label: "renamed", newSize: 6,
                              patches: [(2, 2, Array("XY".utf8)), (2, 2, nil)]),
        ])
        let patched = try original.applying(patch)
        let bhav = try #require(patched.chunk(ofType: "BHAV", id: 1))
        #expect(String(decoding: bhav.data, as: UTF8.self) == "abXYef")
        #expect(bhav.label == "renamed")
    }

    @Test func allowsAFinalRemovalPastTheEndWhenNothingRemains() throws {
        // "222" -> keep "2", add "Z", then remove 5 bytes, more than remain. 2017 allows this.
        let patch = try patchFile(source: "x.iff", [
            PatchEntryFixture(type: "BHAV", id: 2, newSize: 2, patches: [(1, 1, Array("Z".utf8)), (1, 5, nil)]),
        ])
        #expect(try original.applying(patch).chunk(ofType: "BHAV", id: 2)?.data == Data("2Z".utf8))
    }

    @Test func deletesChunks() throws {
        let patch = try patchFile(source: "x.iff", [PatchEntryFixture(type: "STR#", id: 1, delete: true)])
        #expect(try original.applying(patch).chunk(ofType: "STR#", id: 1) == nil)
    }

    @Test func swapsIDsAndMovesBothChunksToTheEnd() throws {
        let patch = try patchFile(source: "x.iff", [
            PatchEntryFixture(type: "BHAV", id: 1, newID: 2, newSize: 6),
        ])
        let patched = try original.applying(patch)
        #expect(chunkSummary(patched) == ["STR##1:s", "BHAV#2:abcdef", "BHAV#1:222"])
    }

    @Test func addsChunksThatDontExistGroupedByType() throws {
        let patch = try patchFile(source: "x.iff", [], adding: [
            ChunkFixture(type: "BCON", id: 9, label: "", contents: Data("c".utf8)),
            ChunkFixture(type: "BHAV", id: 1, label: "", contents: Data("ignored".utf8)),
            ChunkFixture(type: "BHAV", id: 7, label: "", contents: Data("new".utf8)),
            ChunkFixture(type: "BCON", id: 8, label: "", contents: Data("d".utf8)),
        ])
        let patched = try original.applying(patch)
        #expect(chunkSummary(patched).suffix(3) == ["BCON#9:c", "BCON#8:d", "BHAV#7:new"])
        #expect(patched.chunk(ofType: "BHAV", id: 1)?.data == Data("abcdef".utf8), "existing chunks win")
    }

    @Test func skipsEntriesForMissingChunks() throws {
        let patch = try patchFile(source: "x.iff", [PatchEntryFixture(type: "OBJD", id: 5, delete: true)])
        #expect(try original.applying(patch).chunks == original.chunks)
    }

    @Test func rejectsASizeLargerThanThePatchCanProduce() throws {
        let patch = try patchFile(source: "x.iff", [PatchEntryFixture(type: "BHAV", id: 2, newSize: 1_000_000)])
        #expect(throws: PIFFError.invalidSize(typeCode: "BHAV", chunkID: 2)) { try original.applying(patch) }
    }

    @Test func rejectsAPatchPastTheOriginal() throws {
        let patch = try patchFile(source: "x.iff", [
            PatchEntryFixture(type: "BHAV", id: 2, newSize: 3, patches: [(50, 1, nil)]),
        ])
        #expect(throws: PIFFError.patchOutOfBounds(typeCode: "BHAV", chunkID: 2)) { try original.applying(patch) }
    }

    @Test func rejectsAFileWithoutAPatchChunk() {
        #expect(throws: PIFFError.missingPatchChunk) { try original.applying(original) }
    }

    @Test func readsThePatchHeader() throws {
        let piff = try PIFF(record: IFFChunkRecord(typeCode: "PIFF", id: 1, flags: 0, label: "",
                                                   data: piffData(source: "chairs.iff", [
                                                       PatchEntryFixture(type: "OBJD", id: 4, delete: true),
                                                   ])))
        #expect(piff.version == 1)
        #expect(piff.sourceFileName == "chairs.iff")
        #expect(piff.entries == [PIFF.Entry(typeCode: "OBJD", chunkID: 4, isDeletion: true, newChunkID: 4)])
    }
}

@Suite struct PatchRegistryTests {
    @Test func userPatchesReplaceShippedPatchesForTheSameFile() throws {
        let install = try FakeInstall()
        let shipped = makeIFF([ChunkFixture(type: "PIFF", id: 1, label: "", contents: piffData(source: "a.iff", []))])
        try install.write(shipped, to: "a1.piff")
        try install.write(shipped, to: "a2.piff")
        try install.write(shipped, to: "User/mine.piff")
        try install.write(makeIFF([ChunkFixture(type: "PIFF", id: 1, label: "", contents: piffData(source: "b.iff", []))]),
                          to: "b.piff")
        try install.write(Data("<T/>".utf8), to: "tuning/chairs.otf")
        try install.write(Data("not an iff".utf8), to: "broken.piff")

        let registry = try PatchRegistry(directory: install.root)

        #expect(registry.patches(for: "a.iff").count == 1, "the user patch replaced both shipped ones")
        #expect(registry.patches(for: "b.iff").count == 1)
        #expect(registry.patches(for: "c.iff").isEmpty)
        #expect(registry.tuningReplacement(for: "chairs.otf")?.lastPathComponent == "chairs.otf")
        #expect(registry.failures.map(\.path) == ["broken.piff"])
    }

    @Test func ignoresShippedPatchesAfterAUserPatch() throws {
        var registry = PatchRegistry()
        let patch = try patchFile(source: "a.iff", [])
        try registry.register(patch, named: "user.piff", isUserPatch: true)
        try registry.register(patch, named: "shipped.piff", isUserPatch: false)
        #expect(registry.patches(for: "a.iff").map(\.name) == ["user.piff"])
    }

    /// Uses a type this package doesn't parse, so the patches are checked only for fit.
    @Test func appliesEveryPatchInOrder() throws {
        let original = try IFFFile(bytes: makeIFF([ChunkFixture(type: "XYZW", id: 1, label: "", contents: Data("ab".utf8))]))
        var registry = PatchRegistry()
        try registry.register(patchFile(source: "a.iff", [PatchEntryFixture(type: "XYZW", id: 1, newSize: 3, patches: [(2, 1, [0x63])])]),
                              named: "first.piff", isUserPatch: false)
        try registry.register(patchFile(source: "a.iff", [PatchEntryFixture(type: "XYZW", id: 1, newSize: 4, patches: [(3, 1, [0x64])])]),
                              named: "second.piff", isUserPatch: false)
        let outcome = registry.applyingPatches(to: original, fileName: "a.iff")
        #expect(outcome.file.chunk(ofType: "XYZW", id: 1)?.data == Data("abcd".utf8))
        #expect(outcome.applied == ["first.piff", "second.piff"])
        #expect(outcome.skipped.isEmpty)
    }

    /// A patch written for another version of the file (FreeSO's patches target the
    /// 2003 production files) is skipped as a whole, and later patches still apply.
    @Test func skipsAPatchThatDoesntFitTheFile() throws {
        let original = try IFFFile(bytes: makeIFF([
            ChunkFixture(type: "BCON", id: 1, label: "", contents: Data([0, 0])), // no constants
            ChunkFixture(type: "FWAV", id: 1, label: "", contents: Data("old\0".utf8)),
        ]))
        var registry = PatchRegistry()
        // Reaches past the original: doesn't apply at all.
        try registry.register(patchFile(source: "a.iff", [
            PatchEntryFixture(type: "FWAV", id: 1, newSize: 4, patches: [(0, 4, Array("new\0".utf8))]),
            PatchEntryFixture(type: "BCON", id: 1, newSize: 9, patches: [(40, 1, nil)]),
        ]), named: "wrong-version.piff", isUserPatch: false)
        // Applies, but leaves a BCON that declares 5 constants and holds none: doesn't parse.
        try registry.register(patchFile(source: "a.iff", [
            PatchEntryFixture(type: "BCON", id: 1, newSize: 2, patches: [(0, 2, [5, 0]), (2, 2, nil)]),
        ]), named: "garbles.piff", isUserPatch: false)
        try registry.register(patchFile(source: "a.iff", [
            PatchEntryFixture(type: "FWAV", id: 1, newSize: 4, patches: [(0, 4, Array("new\0".utf8)), (4, 4, nil)]),
        ]), named: "fits.piff", isUserPatch: false)

        let outcome = registry.applyingPatches(to: original, fileName: "a.iff")

        #expect(outcome.applied == ["fits.piff"])
        #expect(outcome.skipped.map(\.name) == ["wrong-version.piff", "garbles.piff"])
        #expect(outcome.file.chunk(ofType: "BCON", id: 1)?.data == Data([0, 0]), "skipped patches change nothing")
        #expect(try outcome.file.chunk(FWAV.self, id: 1)?.name == "new")
    }
}
