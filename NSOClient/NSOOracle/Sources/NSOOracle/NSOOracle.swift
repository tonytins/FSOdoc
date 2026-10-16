import ArgumentParser
import Foundation
import NSOOracleCore
import SimAntics
import TSOContent

/// `nso-oracle`: NSOClient's answers to `fso-oracle`'s questions, and the two compared.
@main
struct NSOOracle: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nso-oracle",
        abstract: "Answer fso-oracle's questions with NSOClient, and compare the two.",
        discussion: """
            list-objects, run-objects, and room-maps print the same formats as fso-oracle's \
            commands of the same names (see NSOClient/Oracle/README.md). compare reads both sides' \
            answers and prints how they agree, and with --review writes docs/results/nso-review.md.
            """,
        subcommands: [ListObjects.self, RunObjects.self, RoomMaps.self, Compare.self])
}

/// The folder of FreeSO's content in the 2017 snapshot, which `fso-oracle` uses too.
private let repositoryContent = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("../../../../TSOClient/tso.content/Content").standardizedFileURL

struct InstallOptions: ParsableArguments {
    @Option(help: "The TSO install. Defaults to $TSO_GAME_DIR.")
    var game: String?

    @Option(help: "FreeSO's Content folder, for patches and standalone objects (default: the one in this repository).")
    var content: String?

    func load() throws -> GameContent {
        guard let path = game ?? ProcessInfo.processInfo.environment["TSO_GAME_DIR"], !path.isEmpty else {
            throw ValidationError("No --game given and TSO_GAME_DIR is not set.")
        }
        return try GameContent(.init(gameDirectory: URL(fileURLWithPath: path, isDirectory: true),
                                     freeSOContentDirectory: contentDirectory))
    }

    var contentDirectory: URL {
        content.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? repositoryContent
    }
}

extension NSOOracle {
    struct ListObjects: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list-objects",
                                                        abstract: "Print what NSOClient loads for every registered object.")
        @OptionGroup var install: InstallOptions

        func run() throws {
            for line in Answers(content: try install.load()).objectListing() { print(line) }
        }
    }

    struct RunObjects: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "run-objects",
            abstract: "For each GUID on standard input, run the object alone on an empty lot and print digests.")
        @OptionGroup var install: InstallOptions

        @Option(help: "The lot (default: Blueprints/empty_lot_fso.xml in the content folder); its objects are left out.")
        var blueprint: String?

        @Option(help: "Ticks to run.") var ticks = 1800
        @Option(help: "Also print a digest every this many ticks (0 for only the end).") var every = 0

        func run() throws {
            let answers = Answers(content: try install.load())
            let lot = blueprint.map { URL(fileURLWithPath: $0) }
                ?? install.contentDirectory.appendingPathComponent("Blueprints/empty_lot_fso.xml")
            let architecture = try Blueprint(xml: try Data(contentsOf: lot)).architecture()
            while let line = readLine() {
                let text = line.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { continue }
                guard let guid = UInt32(text, radix: 16) else {
                    print("\(text) error not a GUID")
                    continue
                }
                let prefix = String(format: "%08x", guid)
                for answer in answers.objectRun(guid: guid, on: architecture, ticks: ticks, every: every) {
                    print("\(prefix) \(answer)")
                }
            }
        }
    }

    struct RoomMaps: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "room-maps", abstract: "For each blueprint path on standard input, print its room maps and rooms as JSON.")

        func run() throws {
            while let line = readLine() {
                let path = line.trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { continue }
                let data = try JSONSerialization.data(withJSONObject: Answers.roomMaps(of: URL(fileURLWithPath: path)))
                print(String(decoding: data, as: UTF8.self))
            }
        }
    }

    struct Compare: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Compare fso-oracle's and nso-oracle's answers, and optionally write the review.",
            discussion: """
                Each folder holds the same files from its side: objects.tsv (list-objects), \
                objects.digests (run-objects), rooms.jsonl (room-maps), and optionally timings.tsv \
                (command, tab, seconds). Missing files are left out of the comparison.
                """)

        @Option(help: "fso-oracle's answers.") var fso: String
        @Option(help: "nso-oracle's answers.") var nso: String
        @Option(help: "The install's name in the review, such as production or beta.") var install = "production"
        @Option(help: "Write this install's section of the review to this file (such as docs/results/nso-review.md).")
        var review: String?
        @Option(help: "The commit the answers came from, for the review.") var commit = "unknown"

        func run() throws {
            func lines(_ folder: String, _ file: String) -> [String]? {
                (try? String(contentsOfFile: "\(folder)/\(file)", encoding: .utf8))?.split(separator: "\n").map(String.init)
            }
            var comparisons: [Comparison] = []
            if let theirs = lines(fso, "objects.tsv"), let ours = lines(nso, "objects.tsv") {
                comparisons.append(.content(fso: theirs, nso: ours))
                comparisons.append(.entryPoints(fso: theirs, nso: ours))
            }
            if let theirs = lines(fso, "objects.digests"), let ours = lines(nso, "objects.digests") {
                comparisons.append(.objectRuns(fso: theirs, nso: ours))
            }
            if let theirs = lines(fso, "rooms.jsonl"), let ours = lines(nso, "rooms.jsonl") {
                comparisons.append(.roomMaps(fso: theirs, nso: ours))
            }
            for comparison in comparisons { print(comparison.summary) }

            guard let review else { return }
            var timings: [String: Double] = [:]
            for (side, folder) in [("fso", fso), ("nso", nso)] {
                for line in lines(folder, "timings.tsv") ?? [] {
                    let fields = line.split(separator: "\t")
                    if fields.count == 2, let seconds = Double(fields[1]) { timings["\(side) \(fields[0])"] = seconds }
                }
            }
            let run = Review.Run(install: install, date: Date(), commit: commit, comparisons: comparisons, timings: timings)
            let existing = try? String(contentsOfFile: review, encoding: .utf8)
            try Review.updating(existing, with: run).write(toFile: review, atomically: true, encoding: .utf8)
            print("review: \(install) written to \(review)")
        }
    }
}
