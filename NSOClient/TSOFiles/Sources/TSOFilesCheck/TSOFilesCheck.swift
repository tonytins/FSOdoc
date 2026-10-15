import Foundation
import TSOFiles

/// `tsofiles-check`: opens every container in a TSO install and reports failures.
@main
struct TSOFilesCheck {
    static let usage = """
        usage: tsofiles-check [--far1-variant a|b] [--headers-only] [--max-failures N] [directory]

        Opens every FAR1, FAR3, DBPF, and IFF file under the directory and reads
        every archive entry. The directory defaults to $TSO_GAME_DIR.

          --far1-variant a|b   FAR1 layout: b for TSO (default), a for The Sims 1
          --headers-only       open archives without reading their entries
          --max-failures N     list at most N failures (default 50; all are counted)
        """

    static func main() {
        let options: Options
        do {
            options = try Options(arguments: Array(CommandLine.arguments.dropFirst()),
                                  environment: ProcessInfo.processInfo.environment)
        } catch {
            printError("\(error.message)\n\n\(usage)")
            exit(2)
        }

        let scanner = InstallScanner(far1Variant: options.far1Variant, readsEntries: !options.headersOnly)
        let report: ScanReport
        do {
            report = try scanner.scan(directory: options.directory)
        } catch {
            printError("can't list \(options.directory.path): \(error)")
            exit(2)
        }

        printReport(report, maxFailures: options.maxFailures)
        exit(report.isClean ? 0 : 1)
    }

    private static func printReport(_ report: ScanReport, maxFailures: Int) {
        for kind in ContainerKind.allCases {
            print("\(kind.rawValue): \(report.containerCounts[kind, default: 0]) files")
        }
        print("entries read: \(report.entriesRead) (IFFs inside FAR1: \(report.nestedIFFCount))")
        print("other files: \(report.otherFileCount)")
        print("failures: \(report.failures.count)")

        for failure in report.failures.prefix(maxFailures) {
            let location = failure.entry.map { "\(failure.path): \($0)" } ?? failure.path
            print("  \(location): \(failure.message)")
        }
        if report.failures.count > maxFailures {
            print("  ... and \(report.failures.count - maxFailures) more")
        }
    }

    private static func printError(_ message: String) {
        FileHandle.standardError.write(Data("tsofiles-check: \(message)\n".utf8))
    }
}

struct Options {
    struct UsageError: Error {
        var message: String
    }

    var far1Variant = FAR1Archive.Variant.b
    var headersOnly = false
    var maxFailures = 50
    var directory: URL

    init(arguments: [String], environment: [String: String]) throws(UsageError) {
        var path: String?
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--far1-variant":
                switch remaining.popFirst() {
                case "a": far1Variant = .a
                case "b": far1Variant = .b
                default: throw UsageError(message: "--far1-variant takes a or b")
                }
            case "--headers-only":
                headersOnly = true
            case "--max-failures":
                guard let value = remaining.popFirst().flatMap(Int.init), value >= 0 else {
                    throw UsageError(message: "--max-failures takes a number of 0 or more")
                }
                maxFailures = value
            case "-h", "--help":
                throw UsageError(message: "help requested")
            case let option where option.hasPrefix("-"):
                throw UsageError(message: "unknown option \(option)")
            default:
                guard path == nil else { throw UsageError(message: "only one directory may be given") }
                path = argument
            }
        }

        guard let directory = path ?? environment["TSO_GAME_DIR"], !directory.isEmpty else {
            throw UsageError(message: "no directory given and TSO_GAME_DIR is not set")
        }
        self.directory = URL(fileURLWithPath: directory, isDirectory: true)
    }
}
