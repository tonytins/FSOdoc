import Foundation
import Testing
@testable import TSOContent

@Suite struct GameFileIndexTests {
    let index = GameFileIndex(root: URL(fileURLWithPath: "/game"), relativePaths: [
        "UIGraphics/Hello.bmp", "objectdata/objects/objiff.far", "sounddata/a.hit", "SoundData/A.hit",
    ])

    @Test(arguments: ["uigraphics/hello.bmp", "UIGRAPHICS/HELLO.BMP", #"UIGraphics\Hello.bmp"#])
    func findsFilesInAnyLetterCase(path: String) {
        #expect(index.storedPath(for: path) == "UIGraphics/Hello.bmp")
        #expect(index.url(for: path)?.path == "/game/UIGraphics/Hello.bmp")
    }

    @Test func reportsMissingFiles() {
        #expect(index.storedPath(for: "objectdata/objects/objotf.far") == nil)
    }

    @Test func keepsTheFirstOfPathsThatDifferOnlyInCase() {
        #expect(index.storedPath(for: "sounddata/a.hit") == "SoundData/A.hit")
        #expect(index.caseCollisions == [["SoundData/A.hit", "sounddata/a.hit"]])
    }

    @Test func filtersOnLowerCasePaths() {
        #expect(index.paths { $0.hasPrefix("sounddata/") } == ["SoundData/A.hit", "sounddata/a.hit"])
    }

    @Test func listsAFolderOnDisk() throws {
        let install = try FakeInstall()
        try install.write("x", to: "ObjectData/Objects/objiff.far")
        let index = try GameFileIndex(root: install.root)
        #expect(index.relativePaths == ["ObjectData/Objects/objiff.far"])
        #expect(index.storedPath(for: "objectdata/objects/objiff.far") == "ObjectData/Objects/objiff.far")
    }

    @Test func failsOnAMissingFolder() {
        #expect(throws: ContentError.self) { try GameFileIndex(root: URL(fileURLWithPath: "/nonexistent-\(UUID())")) }
    }
}

@Suite struct GameLocatorTests {
    let home = URL(fileURLWithPath: "/nonexistent-home-\(UUID())", isDirectory: true)

    @Test func prefersTheConfiguredFolder() throws {
        let install = try FakeInstall()
        try install.write("x", to: "ObjectData/x")
        let locator = GameLocator(configuredDirectory: install.root, environment: ["TSO_GAME_DIR": "/elsewhere"], homeDirectory: home)
        #expect(try locator.locate() == install.root)
    }

    @Test func usesTheEnvironmentVariable() throws {
        let install = try FakeInstall()
        try install.write("x", to: "objectdata/x")
        let locator = GameLocator(environment: ["TSO_GAME_DIR": install.root.path], homeDirectory: home)
        #expect(try locator.locate().path == install.root.path)
    }

    @Test func rejectsAGivenFolderThatIsNotAnInstall() throws {
        let empty = try FakeInstall()
        #expect(throws: ContentError.notAnInstall(path: empty.root.path)) {
            try GameLocator(configuredDirectory: empty.root, homeDirectory: home).locate()
        }
        #expect(throws: ContentError.notAnInstall(path: "/nowhere")) {
            try GameLocator(environment: ["TSO_GAME_DIR": "/nowhere"], homeDirectory: home).locate()
        }
    }

    @Test func listsEveryDefaultFolderWhenNoneIsAnInstall() {
        let locator = GameLocator(environment: [:], homeDirectory: home, workingDirectory: home)
        #expect(throws: ContentError.gameNotFound(searched: locator.defaultDirectories.map(\.path))) {
            try locator.locate()
        }
    }

    #if os(Linux)
    @Test func looksUnderXDGDataHomeOnLinux() {
        let locator = GameLocator(environment: ["XDG_DATA_HOME": "/data"], homeDirectory: home, workingDirectory: home)
        #expect(locator.defaultDirectories.map(\.path) == ["/data/The Sims Online/TSOClient", home.path + "/game/TSOClient"])
    }
    #endif
}

@Suite struct ObjectTableTests {
    @Test func readsEntries() throws {
        let table = try ObjectTable(bytes: Data(objectTable([
            tableEntry(guid: 0x3A44E0F8, file: "2personportal", group: 1, subIndex: -1),
            #"<I g="98e0f8bd" n="aquarium1" o="Aquarium" m="0" i="256"/>"#,
        ]).utf8))
        #expect(table.entries == [
            .init(guid: 0x3A44E0F8, fileName: "2personportal", name: nil, group: 1, subIndex: -1),
            .init(guid: 0x98E0F8BD, fileName: "aquarium1", name: "Aquarium", group: 0, subIndex: 256),
        ])
    }

    @Test(arguments: [
        (#"<I n="a" m="0" i="0"/>"#, #"entry 0 has no "g""#),
        (#"<I g="0x1" m="0" i="0"/>"#, #"entry 0 has no "n""#),
        (#"<I g="zz" n="a" m="0" i="0"/>"#, #"entry 0 has an invalid GUID "zz""#),
        (#"<I g="0x1" n="a" m="40000" i="0"/>"#, #"entry 0 has an invalid group "40000" or sub-index "0""#),
    ])
    func rejectsMalformedEntries(entry: String, message: String) {
        #expect(throws: ContentError.invalidObjectTable(message)) {
            try ObjectTable(bytes: Data(objectTable([entry]).utf8))
        }
    }

    @Test func rejectsMalformedXML() {
        #expect(throws: ContentError.self) { try ObjectTable(bytes: Data("<ObjectInfoTable><I".utf8)) }
    }
}
