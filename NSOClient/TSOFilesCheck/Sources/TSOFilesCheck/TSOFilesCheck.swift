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
            Without a folder, checks every install named by $TSO_GAME_DIR and $TSO_BETA_DIR, \
            one after the other. When both are checked and the differences file doesn't exist \
            yet, it compares the two installs once and writes how they differ there. Exits with 0 when everything reads, 1 when anything fails, and \
            2 when a folder isn't an install or can't be listed.
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

    /// Which of the installs in the environment to check.
    enum InstallChoice: String, ExpressibleByArgument, CaseIterable {
        case all, game, beta
    }

    @Option(help: "Without a folder: which installs to check, game ($TSO_GAME_DIR), beta ($TSO_BETA_DIR), or all that are set.")
    var install: InstallChoice = .all

    @Option(help: "Where to note how the two installs differ, if it doesn't exist yet.")
    var differences = "docs/results/install-differences.md"

    @Argument(help: "The install folder. Defaults to $TSO_GAME_DIR and $TSO_BETA_DIR.")
    var directory: String?

    func validate() throws {
        guard maxFailures >= 0 else { throw ValidationError("--max-failures takes a number of 0 or more.") }
        guard directory == nil || install == .all else {
            throw ValidationError("--install picks from the environment; give it or a folder, not both.")
        }
    }

    /// An install to check, and where it was named.
    struct Install: Equatable {
        /// The environment variable that named it, or `nil` for the command line.
        var source: String?
        var directory: URL
    }

    /// The installs to check: the argument, else each set variable `--install` picks, in the
    /// order `TSO_GAME_DIR`, `TSO_BETA_DIR`. Two variables naming one folder check it once.
    func installs(environment: [String: String]) throws(ValidationError) -> [Install] {
        if let directory {
            guard !directory.isEmpty else { throw ValidationError("The folder can't be empty.") }
            return [Install(source: nil, directory: URL(fileURLWithPath: directory, isDirectory: true))]
        }
        let variables: [String] = switch install {
        case .all: ["TSO_GAME_DIR", "TSO_BETA_DIR"]
        case .game: ["TSO_GAME_DIR"]
        case .beta: ["TSO_BETA_DIR"]
        }
        var found: [Install] = []
        for variable in variables {
            guard let path = environment[variable], !path.isEmpty else { continue }
            let directory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
            if !found.contains(where: { $0.directory == directory }) { found.append(Install(source: variable, directory: directory)) }
        }
        guard !found.isEmpty else {
            throw ValidationError("No folder given and \(variables.joined(separator: " and ")) \(variables.count == 1 ? "is" : "are") not set.")
        }
        return found
    }

    /// Whether a folder holds an install: it has an `objectdata` folder, in any letter case.
    static func isInstall(_ directory: URL) -> Bool {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return false }
        return names.contains { $0.lowercased() == "objectdata" }
    }

    /// Compares two installs and writes the differences file, unless it exists. Returns false
    /// if the comparison or the write failed.
    func noteDifferences(between installs: [Install], date: Date = Date()) -> Bool {
        let file = URL(fileURLWithPath: differences)
        print("")
        guard !FileManager.default.fileExists(atPath: file.path) else {
            print("differences: already noted in \(differences); delete it to compare again")
            return true
        }
        guard FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path) else {
            print("differences: not compared; \(file.deletingLastPathComponent().path) doesn't exist (run from the repository root, or pass --differences)")
            return true
        }
        let first = installs[0], second = installs[1]
        do {
            let result = try InstallComparison(far1Variant: far1Variant.layout).compare(first.directory, second.directory)
            let text = DifferencesReport.markdown(result, first: first.source ?? first.directory.path,
                                                  second: second.source ?? second.directory.path, date: date)
            try Data(text.utf8).write(to: file, options: .withoutOverwriting)
            print("differences: \(result.changedFiles.count) files differ, \(result.onlyInFirst.count) only in "
                  + "\(first.source ?? "the first"), \(result.onlyInSecond.count) only in \(second.source ?? "the second"); "
                  + "noted in \(differences)")
            return true
        } catch {
            fflush(nil)
            FileHandle.standardError.write(Data("tsofiles-check: can't compare the installs: \(error)\n".utf8))
            return false
        }
    }

    func run() throws {
        let installs = try installs(environment: ProcessInfo.processInfo.environment)
        let scanner = InstallScanner(far1Variant: far1Variant.layout, readsEntries: !headersOnly, parsesChunks: !headersOnly)
        var exitCode: Int32 = 0
        var scanned: [Install] = []
        for (index, install) in installs.enumerated() {
            if installs.count > 1 || install.source != nil {
                if index > 0 { print("") }
                print("== \(install.source.map { "\($0): " } ?? "")\(install.directory.path)")
            }
            fflush(nil) // keep the header ahead of any error on standard error
            guard Self.isInstall(install.directory) else {
                FileHandle.standardError.write(Data("tsofiles-check: \(install.directory.path) isn't a TSO install (no objectdata folder)\n".utf8))
                exitCode = 2
                continue
            }
            let report: ScanReport
            do {
                report = try scanner.scan(directory: install.directory)
            } catch {
                FileHandle.standardError.write(Data("tsofiles-check: can't list \(install.directory.path): \(error)\n".utf8))
                exitCode = 2
                continue
            }
            for line in ScanReportText.lines(for: report, maxFailures: maxFailures) {
                print(line)
            }
            scanned.append(install)
            if !report.isClean && exitCode == 0 { exitCode = 1 }
        }
        if scanned.count == 2, !noteDifferences(between: scanned) { exitCode = 2 }
        if exitCode != 0 { throw ExitCode(exitCode) }
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
