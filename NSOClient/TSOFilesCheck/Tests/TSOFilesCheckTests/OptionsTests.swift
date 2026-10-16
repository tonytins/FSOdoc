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
        #expect(try command.installDirectory(environment: [:]).path == "/games/tso")
    }

    @Test func fallsBackToTheEnvironment() throws {
        let command = try TSOFilesCheck.parse([])
        #expect(try command.installDirectory(environment: ["TSO_GAME_DIR": "/opt/tso"]).path == "/opt/tso")
        #expect(command.far1Variant == .b)
        #expect(!command.headersOnly)
        #expect(command.maxFailures == 50)
    }

    @Test func needsADirectory() throws {
        let command = try TSOFilesCheck.parse([])
        #expect(throws: ValidationError.self) { try command.installDirectory(environment: [:]) }
        #expect(throws: ValidationError.self) { try command.installDirectory(environment: ["TSO_GAME_DIR": ""]) }
    }

    @Test(arguments: [
        ["--far1-variant", "c", "/x"],
        ["--max-failures", "-1", "/x"],
        ["--max-failures"],
        ["--verbose", "/x"],
        ["/x", "/y"],
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
