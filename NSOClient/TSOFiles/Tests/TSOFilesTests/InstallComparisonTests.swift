import Foundation
import Testing
@testable import TSOFiles

@Suite struct InstallComparisonTests {
    @Test func findsFilesEntriesAndChunksThatDiffer() throws {
        let first = try FakeInstall(), second = try FakeInstall()
        let chair = ChunkFixture(type: "OBJD", id: 128, label: "chair", contents: validOBJD())
        let newChair = ChunkFixture(type: "OBJD", id: 128, label: "chair", contents: validOBJD(treeTableID: 9))
        let routine = ChunkFixture(type: "BHAV", id: 4096, label: "main", contents: Data([1, 2, 3]))
        try first.write(makeFAR1([FAR1Fixture(name: "chair.iff", contents: makeIFF([chair])),
                                  FAR1Fixture(name: "gone.iff", contents: makeIFF([chair]))], variant: .b),
                        to: "objectdata/objects/objiff.far")
        try second.write(makeFAR1([FAR1Fixture(name: "chair.iff", contents: makeIFF([newChair, routine]))], variant: .b),
                         to: "ObjectData/Objects/OBJIFF.far") // paths match in any letter case
        try first.write(Data("same".utf8), to: "same.txt")
        try second.write(Data("same".utf8), to: "same.txt")
        try first.write(Data("one".utf8), to: "notes.txt")
        try second.write(Data("two!".utf8), to: "notes.txt")
        try first.write(Data("a".utf8), to: "beta-only.cfg")
        try second.write(Data("b".utf8), to: "uigraphics/new.bmp")

        let differences = try InstallComparison().compare(first.root, second.root)
        #expect(differences.identicalFileCount == 1)
        #expect(differences.onlyInFirst == ["beta-only.cfg"])
        #expect(differences.onlyInSecond == ["uigraphics/new.bmp"])
        #expect(differences.changedFiles.map(\.path) == ["notes.txt", "objectdata/objects/objiff.far"])

        let notes = differences.changedFiles[0]
        #expect(notes.kind == nil && notes.firstSize == 3 && notes.secondSize == 4 && notes.entries.isEmpty)
        let archive = differences.changedFiles[1]
        #expect(archive.kind == .far1)
        #expect(archive.entries == [
            EntryDifference(name: "chair.iff: BHAV #4096", change: .onlyInSecond, guid: nil),
            EntryDifference(name: "chair.iff: OBJD #128", change: .changed, guid: "00000000"),
            EntryDifference(name: "gone.iff", change: .onlyInFirst, guid: nil),
        ])
    }

    @Test func identicalInstallsHaveNoDifferences() throws {
        let first = try FakeInstall(), second = try FakeInstall()
        try first.write(makeIFF([]), to: "a.iff")
        try second.write(makeIFF([]), to: "a.iff")
        let differences = try InstallComparison().compare(first.root, second.root)
        #expect(differences.isEmpty && differences.identicalFileCount == 1)
    }

    @Test func failsOnAMissingRoot() throws {
        let first = try FakeInstall()
        #expect(throws: (any Error).self) { try InstallComparison().compare(first.root, first.root.appendingPathComponent("missing")) }
    }
}
