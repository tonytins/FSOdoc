import ArgumentParser
import Foundation
import TSOFiles

/// `tsofiles-check`: opens every container in a TSO install and reports failures.
@main
struct TSOFilesCheck: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tsofiles-check",
        abstract: "Open every FAR1, FAR3, DBPF, and IFF file in a TSO install and read every entry.",
        discussion: """
            Exits with 0 when everything reads, 1 when anything fails, and 2 when the folder \
            can't be listed.
            """)

    /// The FAR1 layouts, by the names the command line takes.
    enum Variant: String, ExpressibleByArgument, CaseIterable {
        case a, b

        var layout: FAR1Archive.Variant {
            switch self {
            case .a: .a
            case .b: .b
            }
        }
    }

    @Option(name: .customLong("far1-variant"), help: "FAR1 layout: b for TSO, a for The Sims 1.")
    var far1Variant: Variant = .b

    @Flag(help: "Open archives without reading entries or parsing chunks.")
    var headersOnly = false

    @Option(help: "List at most this many failures; all of them are counted.")
    var maxFailures = 50

    @Argument(help: "The install folder. Defaults to $TSO_GAME_DIR.")
    var directory: String?

    func validate() throws {
        guard maxFailures >= 0 else { throw ValidationError("--max-failures takes a number of 0 or more.") }
    }

    /// The folder to scan: the argument, else `TSO_GAME_DIR`.
    func installDirectory(environment: [String: String]) throws(ValidationError) -> URL {
        guard let path = directory ?? environment["TSO_GAME_DIR"], !path.isEmpty else {
            throw ValidationError("No directory given and TSO_GAME_DIR is not set.")
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func run() throws {
        let directory = try installDirectory(environment: ProcessInfo.processInfo.environment)
        let scanner = InstallScanner(far1Variant: far1Variant.layout, readsEntries: !headersOnly, parsesChunks: !headersOnly)
        let report: ScanReport
        do {
            report = try scanner.scan(directory: directory)
        } catch {
            FileHandle.standardError.write(Data("tsofiles-check: can't list \(directory.path): \(error)\n".utf8))
            throw ExitCode(2)
        }
        for line in ScanReportText.lines(for: report, maxFailures: maxFailures) {
            print(line)
        }
        if !report.isClean { throw ExitCode.failure }
    }
}

/// The report `tsofiles-check` prints, one string per line.
enum ScanReportText {
    static func lines(for report: ScanReport, maxFailures: Int) -> [String] {
        var lines = ContainerKind.allCases.map { "\($0.rawValue): \(report.containerCounts[$0, default: 0]) files" }
        lines.append("entries read: \(report.entriesRead) (IFFs inside archives: \(report.nestedIFFCount))")
        let chunkSummary = report.chunkCounts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
        lines.append("chunks parsed: \(report.chunkCounts.values.reduce(0, +))"
                     + (chunkSummary.isEmpty ? "" : " (\(chunkSummary.joined(separator: ", ")))"))
        lines.append("other files: \(report.otherFileCount)")
        lines.append("failures: \(report.failures.count)")
        for failure in report.failures.prefix(maxFailures) {
            let location = failure.entry.map { "\(failure.path): \($0)" } ?? failure.path
            lines.append("  \(location): \(failure.message)")
        }
        if report.failures.count > maxFailures {
            lines.append("  ... and \(report.failures.count - maxFailures) more")
        }
        if !report.unreferencedChunkFailures.isEmpty {
            lines.append("unreferenced chunks that don't parse (the game never loads them): \(report.unreferencedChunkFailures.count)")
            for failure in report.unreferencedChunkFailures.prefix(maxFailures) {
                lines.append("  \(failure.path): \(failure.entry ?? ""): \(failure.message)")
            }
        }
        return lines
    }
}
