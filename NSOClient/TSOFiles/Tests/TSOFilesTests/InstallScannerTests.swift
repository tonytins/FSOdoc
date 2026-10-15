import Foundation
import Testing
@testable import TSOFiles

/// A temporary directory of synthetic game files, removed when the test ends.
struct FakeInstall: ~Copyable {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tsofiles-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func write(_ data: Data, to relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }
}

@Suite struct InstallScannerTests {
    @Test(arguments: [
        (Data("DBPF".utf8) + Data(count: 8), ContainerKind.dbpf),
        (Data("IFF FILE 2.5:TYPE".utf8), .iff),
        (Data("FAR!byAZ".utf8) + Data([1, 0, 0, 0]), .far1),
        (Data("FAR!byAZ".utf8) + Data([3, 0, 0, 0]), .far3),
    ])
    func recognizesContainersByTheirFirstBytes(header: Data, kind: ContainerKind) {
        #expect(ContainerKind(header: header) == kind)
    }

    @Test(arguments: [Data("FAR!byAZ".utf8) + Data([2, 0, 0, 0]), Data("FAR!".utf8), Data("BM".utf8), Data()])
    func ignoresOtherFiles(header: Data) {
        #expect(ContainerKind(header: header) == nil)
    }

    @Test func scansAHealthyInstall() throws {
        let install = try FakeInstall()
        let object = makeIFF([ChunkFixture(type: "OBJD", id: 1, label: "chair", contents: Data([1]))])
        try install.write(makeFAR1([FAR1Fixture(name: "chair.iff", contents: object),
                                    FAR1Fixture(name: "chair.otf", contents: Data("<?xml".utf8))], variant: .b),
                          to: "objectdata/objects/objiff.far")
        let stream = Data([0x0E, 0x01, 0x61, 0x62, 0xFC, 0x00, 0x00])
        try install.write(makeFAR3([
            FAR3Fixture(name: "a.mesh", id: AssetID(fileID: 1, typeID: 2),
                        stored: persistContainer(refPack: stream, decompressedSize: 8),
                        decompressedSize: 8, compressionFlag: 1),
        ]), to: "avatardata/meshes/meshes.dat")
        try install.write(makeDBPF([DBPFFixture(type: .xa, instance: 1, contents: Data([1, 2]))]),
                          to: "sounddata/tsov2.dat")
        try install.write(object, to: "global/global.iff")
        try install.write(Data("BM....".utf8), to: "uigraphics/splash.bmp")

        let report = try InstallScanner().scan(directory: install.root)

        #expect(report.isClean, "\(report.failures)")
        #expect(report.containerCounts == [.far1: 1, .far3: 1, .dbpf: 1, .iff: 1])
        #expect(report.entriesRead == 4)
        #expect(report.nestedIFFCount == 1)
        #expect(report.otherFileCount == 1)
    }

    @Test func reportsBrokenFilesAndEntriesByPath() throws {
        let install = try FakeInstall()
        // A FAR3 entry whose RefPack stream points before the start of the output.
        let badStream = Data([0x0E, 0x05, 0x61, 0x62, 0xFC, 0x00, 0x00])
        try install.write(makeFAR3([
            FAR3Fixture(name: "bad.anim", id: AssetID(fileID: 9, typeID: 1),
                        stored: persistContainer(refPack: badStream, decompressedSize: 8),
                        decompressedSize: 8, compressionFlag: 1),
        ]), to: "b/anims.dat")
        // An IFF with a chunk smaller than its own header.
        try install.write(makeIFF([ChunkFixture(type: "BHAV", id: 1, label: "", contents: Data(), declaredSize: 4)]),
                          to: "a/broken.iff")

        let report = try InstallScanner().scan(directory: install.root)

        #expect(report.failures.map(\.path) == ["a/broken.iff", "b/anims.dat"], "sorted by path")
        #expect(report.failures[0].entry == nil)
        #expect(report.failures[1].entry == "bad.anim [0x900000001]")
        #expect(report.failures[1].message.contains("invalidBackReference"))
    }

    @Test func skipsEntryDataWhenAskedForHeadersOnly() throws {
        let install = try FakeInstall()
        try install.write(makeDBPF([DBPFFixture(type: .xa, instance: 1, contents: Data([1]))]), to: "s.dat")

        let report = try InstallScanner(readsEntries: false).scan(directory: install.root)

        #expect(report.containerCounts == [.dbpf: 1])
        #expect(report.entriesRead == 0)
    }

    @Test func failsForAMissingDirectory() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("no-such-\(UUID().uuidString)")
        #expect(throws: (any Error).self) { try InstallScanner().scan(directory: missing) }
    }
}
