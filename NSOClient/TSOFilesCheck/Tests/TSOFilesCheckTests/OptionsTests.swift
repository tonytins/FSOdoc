import ArgumentParser
import Foundation
import Testing
import TSOFiles
@testable import TSOFilesCheck

@Suite struct OptionsTests {
    @Test func readsEveryOption() throws {
        let command = try TSOFilesCheck.parse(["--far1-variant", "a", "--headers-only", "--max-failures", "5", "/games/tso"])
        #expect(command.far1Variant == .a)
        #expect(command.headersOnly)
        #expect(command.maxFailures == 5)
        let installs = try command.installs(environment: ["TSO_GAME_DIR": "/opt/tso", "TSO_BETA_DIR": "/opt/beta"])
        #expect(installs.map(\.directory.path) == ["/games/tso"] && installs[0].source == nil)
    }

    @Test func fallsBackToTheEnvironment() throws {
        let command = try TSOFilesCheck.parse([])
        let installs = try command.installs(environment: ["TSO_GAME_DIR": "/opt/tso"])
        #expect(installs == [.init(source: "TSO_GAME_DIR", directory: URL(fileURLWithPath: "/opt/tso", isDirectory: true))])
        #expect(command.far1Variant == .b)
        #expect(!command.headersOnly)
        #expect(command.maxFailures == 50)
        #expect(command.install == .all)
    }

    @Test func checksBothInstallsGameFirst() throws {
        let environment = ["TSO_BETA_DIR": "/opt/beta", "TSO_GAME_DIR": "/opt/tso"]
        let all = try TSOFilesCheck.parse([]).installs(environment: environment)
        #expect(all.map(\.source) == ["TSO_GAME_DIR", "TSO_BETA_DIR"])
        #expect(all.map(\.directory.path) == ["/opt/tso", "/opt/beta"])
        #expect(try TSOFilesCheck.parse([]).installs(environment: ["TSO_BETA_DIR": "/opt/beta"]).map(\.source) == ["TSO_BETA_DIR"])
        #expect(try TSOFilesCheck.parse(["--install", "beta"]).installs(environment: environment).map(\.source) == ["TSO_BETA_DIR"])
        #expect(try TSOFilesCheck.parse(["--install", "game"]).installs(environment: environment).map(\.source) == ["TSO_GAME_DIR"])
    }

    @Test func checksOneFolderOnce() throws {
        let installs = try TSOFilesCheck.parse([]).installs(environment: ["TSO_GAME_DIR": "/opt/tso", "TSO_BETA_DIR": "/opt/x/../tso/"])
        #expect(installs.map(\.source) == ["TSO_GAME_DIR"])
    }

    @Test func needsADirectory() throws {
        let command = try TSOFilesCheck.parse([])
        #expect(throws: ValidationError.self) { try command.installs(environment: [:]) }
        #expect(throws: ValidationError.self) { try command.installs(environment: ["TSO_GAME_DIR": "", "TSO_BETA_DIR": ""]) }
        #expect(throws: ValidationError.self) {
            try TSOFilesCheck.parse(["--install", "beta"]).installs(environment: ["TSO_GAME_DIR": "/opt/tso"])
        }
    }

    @Test func recognizesInstalls() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tsofiles-install-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #expect(!TSOFilesCheck.isInstall(root))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("ObjectData"), withIntermediateDirectories: true)
        #expect(TSOFilesCheck.isInstall(root))
        #expect(!TSOFilesCheck.isInstall(root.appendingPathComponent("missing")))
    }

    @Test(arguments: [
        ["--far1-variant", "c", "/x"],
        ["--max-failures", "-1", "/x"],
        ["--max-failures"],
        ["--verbose", "/x"],
        ["/x", "/y"],
        ["--install", "beta", "/x"],
        ["--install", "demo"],
        ["--help"],
    ])
    func rejectsBadArguments(arguments: [String]) {
        #expect(throws: (any Error).self) { try TSOFilesCheck.parse(arguments) }
    }
}

@Suite struct ScanReportTextTests {
    /// A folder with one good IFF and one truncated FAR1.
    func scanTestFolder() throws -> ScanReport {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tsofiles-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var iff = Data("IFF FILE 2.5:TYPE FOLLOWED BY SIZE\0 JAMIE DOORNBOS & MAXIS 1".utf8)
        iff.append(Data(count: 60 - iff.count + 4))
        try iff.write(to: root.appendingPathComponent("empty.iff"))
        try Data("FAR!byAZ".utf8 + [1, 0, 0, 0, 0xff]).write(to: root.appendingPathComponent("broken.far"))
        try Data("text".utf8).write(to: root.appendingPathComponent("notes.txt"))
        return try InstallScanner(far1Variant: .b, readsEntries: true, parsesChunks: true).scan(directory: root)
    }

    @Test func summarizesAndListsFailures() throws {
        let lines = ScanReportText.lines(for: try scanTestFolder(), maxFailures: 50)
        #expect(lines.contains("FAR1: 1 files") && lines.contains("IFF: 1 files"))
        #expect(lines.contains("other files: 1"))
        #expect(lines.contains("failures: 1"))
        #expect(lines.contains { $0.hasPrefix("  broken.far: ") })
    }

    @Test func countsFailuresPastTheLimit() throws {
        let lines = ScanReportText.lines(for: try scanTestFolder(), maxFailures: 0)
        #expect(lines.contains("failures: 1"))
        #expect(lines.last == "  ... and 1 more")
    }
}

@Suite struct DifferencesTests {
    func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tsofiles-differences-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func writesTheDifferencesOnce() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let game = root.appendingPathComponent("game"), beta = root.appendingPathComponent("beta")
        for folder in [game, beta] {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("objectdata"), withIntermediateDirectories: true)
        }
        try Data("new".utf8).write(to: game.appendingPathComponent("objectdata/new.txt"))
        let notes = root.appendingPathComponent("install-differences.md")
        let command = try TSOFilesCheck.parse(["--differences", notes.path])
        let installs = [TSOFilesCheck.Install(source: "TSO_GAME_DIR", directory: game),
                        TSOFilesCheck.Install(source: "TSO_BETA_DIR", directory: beta)]

        #expect(command.noteDifferences(between: installs, date: Date(timeIntervalSince1970: 0)))
        let written = try String(contentsOf: notes, encoding: .utf8)
        #expect(written.contains("on 1970-01-01, comparing the install in `TSO_GAME_DIR`"))
        #expect(written.contains("## Only in `TSO_GAME_DIR`\n\n- `objectdata/new.txt`"))

        // A second run leaves the notes alone, even when the installs change.
        try Data("newer".utf8).write(to: beta.appendingPathComponent("objectdata/newer.txt"))
        #expect(command.noteDifferences(between: installs))
        #expect(try String(contentsOf: notes, encoding: .utf8) == written)
    }

    @Test func skipsWithoutAFolderForTheNotes() throws {
        let root = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let notes = root.appendingPathComponent("missing/install-differences.md")
        let command = try TSOFilesCheck.parse(["--differences", notes.path])
        let installs = [TSOFilesCheck.Install(source: "A", directory: root), TSOFilesCheck.Install(source: "B", directory: root)]
        #expect(command.noteDifferences(between: installs))
        #expect(!FileManager.default.fileExists(atPath: notes.path))
    }

    @Test func describesChangedEntries() {
        var differences = InstallDifferences()
        differences.identicalFileCount = 3
        differences.changedFiles = [FileDifference(path: "objiff.far", firstSize: 10, secondSize: 12, kind: .far1, entries: [
            EntryDifference(name: "chair.iff: OBJD #128", change: .changed, guid: "000000ab"),
            EntryDifference(name: "a|b.iff", change: .onlyInSecond, guid: nil),
        ])]
        let text = DifferencesReport.markdown(differences, first: "TSO_GAME_DIR", second: "TSO_BETA_DIR", date: Date(timeIntervalSince1970: 0))
        #expect(text.contains("| Identical | 3 |"))
        #expect(text.contains("FAR1, 10 bytes in `TSO_GAME_DIR`, 12 in `TSO_BETA_DIR`."))
        #expect(text.contains("| `chair.iff: OBJD #128` | changed | 000000ab |"))
        #expect(text.contains("| `a\\|b.iff` | only in `TSO_BETA_DIR` |  |"))
        #expect(!text.contains("The installs are identical."))
    }
}
