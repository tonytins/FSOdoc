import Foundation
import Testing
import TSOFiles
@testable import TSOContent

/// An install with one object file (`chair`) holding two objects, a semi-global, and tuning.
func makeInstall(chairOTF: Data = otf(tableID: 4096, value: 7), extraTableEntries: [String] = [],
                 chairChunks: [ChunkFixture] = []) throws -> FakeInstall {
    let install = try FakeInstall()
    try install.write(objectTable([
        tableEntry(guid: 0x100, file: "chair", group: 1, subIndex: 0),
        tableEntry(guid: 0x101, file: "chair", group: 1, subIndex: 1),
        tableEntry(guid: 0x102, file: "chair"),
        tableEntry(guid: 0x103, file: "missing"),
    ] + extraTableEntries), to: "packingslips/objecttable.xml")
    let chair = makeIFF([
        objdChunk(id: 128, label: "chair", guid: 0x100, masterID: 1, subIndex: 0),
        objdChunk(id: 129, label: "chair part", guid: 0x101, masterID: 1, subIndex: 1),
        globChunk("ChairGlobals"),
        bhavChunk(id: 4096, label: "main"),
        bhavChunk(id: 4097, label: "shared\0junk"),
    ] + chairChunks)
    try install.write(makeFAR1([(name: "chair.iff", contents: chair)]), to: "ObjectData/Objects/objiff.far")
    try install.write(makeFAR1([(name: "chair.otf", contents: chairOTF)]), to: "ObjectData/Objects/objotf.far")
    try install.write(makeIFF([bhavChunk(id: 8192, label: "shared"), bhavChunk(id: 8193, label: "semi-global only")]),
                      to: "ObjectData/Globals/chairglobals.iff")
    try install.write(otf(tableID: 8192, value: 3), to: "ObjectData/Globals/chairglobals.otf")
    try install.write(makeIFF([bhavChunk(id: 256, label: "idle")]), to: "ObjectData/Globals/Global.iff")
    return install
}

/// Loads an install and runs `body` while its folder exists. Objects load lazily, so the
/// install must outlive every use of the content, not just `GameContent.init`.
func withContent(_ install: FakeInstall, patchDirectory: URL? = nil, standaloneDirectory: URL? = nil,
                 loadsSprites: Bool = false, _ body: (GameContent) throws -> Void) throws {
    try withExtendedLifetime(install) {
        try body(try GameContent(.init(gameDirectory: install.root, patchDirectory: patchDirectory,
                                       standaloneObjectDirectory: standaloneDirectory, loadsSprites: loadsSprites)))
    }
}

@Suite struct ObjectProviderTests {
    @Test func registersTheObjectTable() throws {
        try withContent(try makeInstall()) { content throws in
            #expect(content.objects.references.map(\.guid) == [0x100, 0x101, 0x102, 0x103])
            #expect(content.objects.reference(guid: 0x101)
                    == .init(guid: 0x101, fileName: "chair", source: .archive, name: nil, group: 1, subIndex: 1))
        }
    }

    @Test func loadsAnObjectWithItsSemiGlobalAndTuning() throws {
        try withContent(try makeInstall()) { content throws in
            let chair = try #require(try content.objects.object(guid: 0x100))
            #expect(chair.guid == 0x100)
            #expect(chair.definition.label == "chair")
            #expect(chair.resource.name == "chair")
            #expect(chair.resource.semiGlobal?.name == "chairglobals")
            #expect(chair.resource.tuningTable(id: 4096)?.key(id: 0)?.value == 7)
            #expect(chair.resource.semiGlobal?.tuningTable(id: 8192)?.key(id: 0)?.value == 3)
            #expect(chair.resource.tuningFailure == nil)
            #expect(chair.resource.sprites == nil)
        }
    }

    @Test func sharesOneResourceAcrossAFile() throws {
        try withContent(try makeInstall()) { content throws in
            let chair = try #require(try content.objects.object(guid: 0x100))
            let part = try #require(try content.objects.object(guid: 0x101))
            #expect(part.definition.label == "chair part")
            #expect(part.resource.mainFile.chunks == chair.resource.mainFile.chunks)
        }
    }

    @Test func namesTreesByLabelUpToTheFirstNULWithTheObjectsOwnFirst() throws {
        try withContent(try makeInstall()) { content throws in
            let trees = try #require(try content.objects.object(guid: 0x100)).resource.treesByName
            #expect(trees.mapValues(\.id) == ["main": 4096, "shared": 4097, "semi-global only": 8193])
        }
    }

    @Test func returnsNilForAnUnregisteredGUIDOrOneMissingFromItsFile() throws {
        try withContent(try makeInstall()) { content throws in
            #expect(try content.objects.object(guid: 0x999) == nil)
            #expect(try content.objects.object(guid: 0x102) == nil)
        }
    }

    @Test func throwsForAFileMissingFromTheArchive() throws {
        try withContent(try makeInstall()) { content throws in
            #expect(throws: ContentError.missingFile("objectdata/objects/objiff.far/missing.iff")) {
                try content.objects.object(guid: 0x103)
            }
            #expect(try content.objects.object(guid: 0x100) != nil)
        }
    }

    @Test func keepsTheFirstOfDuplicateGUIDs() throws {
        try withContent(try makeInstall(extraTableEntries: [tableEntry(guid: 0x100, file: "other")])) { content throws in
            #expect(content.objects.reference(guid: 0x100)?.fileName == "chair")
            #expect(content.objects.duplicates.map(\.ignored.fileName) == ["other"])
        }
    }

    @Test func reportsTuningThatFailsToLoadAndLoadsTheObjectAnyway() throws {
        try withContent(try makeInstall(chairOTF: Data("<O><T".utf8))) { content throws in
            let chair = try #require(try content.objects.object(guid: 0x100))
            #expect(chair.resource.tuning == nil)
            #expect(chair.resource.tuningFailure?.hasPrefix("chair.otf: ") == true)
        }
    }

    @Test func throwsForAMissingSemiGlobal() throws {
        let install = try makeInstall()
        try install.write(makeFAR1([(name: "chair.iff", contents: makeIFF([
            objdChunk(label: "chair", guid: 0x100), globChunk("nosuch"),
        ]))]), to: "ObjectData/Objects/objiff.far")
        try withContent(install) { content throws in
            #expect(throws: ContentError.missingFile("objectdata/globals/nosuch.iff")) {
                try content.objects.object(guid: 0x100)
            }
        }
    }

    @Test func treatsAnEmptyGLOBAsNoSemiGlobal() throws {
        let install = try makeInstall()
        try install.write(makeFAR1([(name: "chair.iff", contents: makeIFF([
            objdChunk(label: "chair", guid: 0x100), ChunkFixture(type: "GLOB", id: 128, contents: Data([0])),
        ]))]), to: "ObjectData/Objects/objiff.far")
        try withContent(install) { content throws in
            #expect(try #require(try content.objects.object(guid: 0x100)).resource.semiGlobal == nil)
        }
    }

    @Test func loadsSpritesWhenAsked() throws {
        let install = try makeInstall()
        try install.write(makeFAR1([(name: "chair.spf", contents: makeIFF([]))]), to: "ObjectData/Objects/objspf1.far")
        try withContent(install, loadsSprites: true) { content throws in
            #expect(try #require(try content.objects.object(guid: 0x100)).resource.sprites != nil)
        }
        try withContent(install) { content throws in
            #expect(try #require(try content.objects.object(guid: 0x100)).resource.sprites == nil)
        }
    }

    @Test func registersEveryObjectInStandaloneFiles() throws {
        let install = try makeInstall()
        let objects = install.root.appendingPathComponent("FreeSO/Objects")
        let path = try install.write(makeIFF([objdChunk(label: "lamp", guid: 0x200, masterID: 3, subIndex: 2)]),
                                     to: "FreeSO/Objects/nested/lamp.iff").path
        try install.write("ignored", to: "FreeSO/Objects/readme.txt")
        try withContent(install, standaloneDirectory: objects) { content throws in
            #expect(content.objects.reference(guid: 0x200)
                    == .init(guid: 0x200, fileName: path, source: .standalone, name: "lamp", group: 3, subIndex: 2))
            #expect(try content.objects.object(guid: 0x200)?.definition.label == "lamp")
        }
    }

    @Test func registersObjectsAgainWhenAPatchChangesTheirFile() throws {
        let install = try makeInstall()
        try install.write(addingPatch(source: "chair.iff", chunks: [objdChunk(id: 200, label: "patched", guid: 0x300)]),
                          to: "Patch/chair.piff")
        try withContent(install, patchDirectory: install.root.appendingPathComponent("Patch")) { content throws in
            #expect(content.objects.reference(guid: 0x300) == nil)

            let chair = try #require(try content.objects.object(guid: 0x100))
            #expect(chair.resource.patches.applied == ["chair.piff"])
            #expect(content.objects.reference(guid: 0x300)?.name == "patched")
            // Registrations from the file replace the table's: 0x102 isn't in the file, so it's gone.
            #expect(content.objects.reference(guid: 0x100)?.name == "chair")
            #expect(content.objects.reference(guid: 0x102) == nil)
            #expect(try content.objects.object(guid: 0x300)?.definition.label == "patched")
        }
    }

    @Test func failsWithoutTheObjectTableOrArchive() throws {
        let install = try makeInstall()
        try FileManager.default.removeItem(at: install.root.appendingPathComponent("packingslips/objecttable.xml"))
        #expect(throws: ContentError.missingFile("packingslips/objecttable.xml")) { try withContent(install) { _ in } }

        let noArchive = try makeInstall()
        try FileManager.default.removeItem(at: noArchive.root.appendingPathComponent("ObjectData/Objects/objiff.far"))
        #expect(throws: ContentError.missingFile("objectdata/objects/objiff.far")) { try withContent(noArchive) { _ in } }
    }
}

@Suite struct GlobalProviderTests {
    @Test func loadsTheGlobalInAnyLetterCase() throws {
        try withContent(try makeInstall()) { content throws in
            let global = try content.global()
            #expect(global.name == "global")
            #expect(try global.chunk(BHAV.self, id: 256)?.label == "idle")
            #expect(global.tuning == nil)
            #expect(try content.globals.resource(named: "CHAIRGLOBALS").tuningTable(id: 8192) != nil)
        }
    }

    @Test func appliesPatchesByLowerCaseFileName() throws {
        let install = try makeInstall()
        try install.write(addingPatch(source: "global.iff", chunks: [bhavChunk(id: 257, label: "patched")]),
                          to: "Patch/global.piff")
        try withContent(install, patchDirectory: install.root.appendingPathComponent("Patch")) { content throws in
            let global = try content.global()
            #expect(global.patches.applied == ["global.piff"])
            #expect(try global.chunk(BHAV.self, id: 257)?.label == "patched")
        }
    }

    @Test func throwsForAMissingGlobalAndTriesAgainLater() throws {
        let install = try makeInstall()
        try withContent(install) { content throws in
            #expect(throws: ContentError.missingFile("objectdata/globals/late.iff")) { try content.globals.resource(named: "late") }
        }
    }

    @Test func throwsForMalformedTuning() throws {
        let install = try makeInstall()
        try install.write(Data("<O><T".utf8), to: "ObjectData/Globals/global.otf")
        try withContent(install) { content throws in
            #expect(throws: ContentError.self) { try content.global() }
        }
    }
}
