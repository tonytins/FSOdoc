import ArgumentParser
import Foundation
import NSOOracleCore
import SimAntics
import TSOContent

/// `nso-oracle`: NSOClient's side of the experiments `fso-oracle` runs on FreeSO, and the two compared.
@main
struct NSOOracle: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nso-oracle",
        abstract: "Run fso-oracle's experiments on NSOClient, and compare the two sides' records.",
        discussion: """
            list-objects, run-objects, run-lot, run-primitive, and room-maps record their results in the same formats as fso-oracle's \
            commands of the same names (see NSOClient/FSO.Oracle/README.md). compare reads both sides' \
            records and reports whether they agree, and with --review writes docs/results/nso-review.md.
            """,
        subcommands: [ListObjects.self, RunObjects.self, RunLot.self, RunPrimitive.self, RoomMaps.self, Compare.self])
}

/// The folder of FreeSO's content in the snapshot (update-46), which `fso-oracle` uses too.
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

/// The lot `run-lot` and `run-primitive` load.
struct LotOptions: ParsableArguments {
    @Option(help: "The lot (default: Blueprints/empty_lot_fso.xml in the content folder).")
    var blueprint: String?

    @Option(name: .customLong("leave-out"),
            help: "An object GUID (hex) to leave out of the lot, such as one fso-oracle left out. Repeatable.")
    var leaveOut: [String] = []

    func lot(in install: InstallOptions) throws -> Blueprint {
        let file = blueprint.map { URL(fileURLWithPath: $0) }
            ?? install.contentDirectory.appendingPathComponent("Blueprints/empty_lot_fso.xml")
        var lot = try Blueprint(xml: try Data(contentsOf: file))
        let guids = try Set(leaveOut.map { text throws -> UInt32 in
            let digits = text.lowercased().hasPrefix("0x") ? String(text.dropFirst(2)) : text
            guard let guid = UInt32(digits, radix: 16) else { throw ValidationError("--leave-out \(text) isn't a hex GUID") }
            return guid
        })
        lot.objects.removeAll { guids.contains($0.guid) }
        return lot
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
            let lotFile = blueprint.map { URL(fileURLWithPath: $0) }
                ?? install.contentDirectory.appendingPathComponent("Blueprints/empty_lot_fso.xml")
            let lot = try Blueprint(xml: try Data(contentsOf: lotFile))
            while let line = readLine() {
                let text = line.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { continue }
                guard let guid = UInt32(text, radix: 16) else {
                    print("\(text) error not a GUID")
                    continue
                }
                let prefix = String(format: "%08x", guid)
                for answer in answers.objectRun(guid: guid, on: lot, ticks: ticks, every: every) {
                    print("\(prefix) \(answer)")
                }
            }
        }
    }

    struct RunLot: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "run-lot", abstract: "Load a lot with its objects, run it, and print digests.")
        @OptionGroup var install: InstallOptions
        @OptionGroup var lotOptions: LotOptions

        @Option(help: "Ticks to run.") var ticks = 1800
        @Option(help: "Also print a digest every this many ticks (0 for only the end).") var every = 0
        @Flag(help: "After each digest, print the digested fields of every entity, one line each.") var dump = false

        func run() throws {
            let answers = Answers(content: try install.load())
            let lines = answers.lotRun(try lotOptions.lot(in: install), ticks: ticks, every: every, dump: dump) { leftOut in
                FileHandle.standardError.write(Data("nso-oracle: object \(String(format: "0x%08X", leftOut.object.guid)) left out of the lot: \(leftOut.reason)\n".utf8))
            }
            for line in lines { print(line) }
        }
    }

    struct RunPrimitive: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "run-primitive",
            abstract: "Run fso-oracle run-primitive requests on standard input, one JSON line each, on a freshly loaded lot.")
        @OptionGroup var install: InstallOptions
        @OptionGroup var lotOptions: LotOptions

        func run() throws {
            let runner = PrimitiveRunner(answers: Answers(content: try install.load()), lot: try lotOptions.lot(in: install))
            while let line = readLine() {
                if let response = runner.answerLine(line) { print(response) }
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
            abstract: "Report whether fso-oracle's and nso-oracle's records agree, and optionally write the review.",
            discussion: """
                Each folder holds the same files from its side: objects.tsv (list-objects), \
                objects.digests (run-objects), lots.digests (run-lot, each line prefixed with the lot's \
                file name), PRIMITIVE.responses.jsonl (run-primitive), rooms.jsonl (room-maps), and optionally timings.tsv \
                (command, tab, seconds). Missing files are left out of the comparison.
                """)

        @Option(help: "fso-oracle's records.") var fso: String
        @Option(help: "nso-oracle's records.") var nso: String
        @Option(help: "The install's name in the review, such as production or beta.") var install = "production"
        @Option(help: "Write this install's section of the review to this file (such as docs/results/nso-review.md).")
        var review: String?
        @Option(help: "The commit the records came from, for the review.") var commit = "unknown"
        @Flag(help: "Exit with an error on any disagreement, so a person looks at it first (as CI runs it).") var strict = false

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
            if let theirs = lines(fso, "lots.digests"), let ours = lines(nso, "lots.digests") {
                comparisons.append(.lotRuns(fso: theirs, nso: ours))
            }
            let responses = (try? FileManager.default.contentsOfDirectory(atPath: fso))?
                .filter { $0.hasSuffix(".responses.jsonl") }.sorted() ?? []
            for file in responses {
                guard let theirs = lines(fso, file), let ours = lines(nso, file) else { continue }
                let primitive = String(file.dropLast(".responses.jsonl".count))
                comparisons.append(.primitives("Primitive: \(primitive)", fso: theirs, nso: ours))
            }
            if let theirs = lines(fso, "rooms.jsonl"), let ours = lines(nso, "rooms.jsonl") {
                comparisons.append(.roomMaps(fso: theirs, nso: ours))
            }
            for comparison in comparisons { print(comparison.summary) }
            if strict {
                let mismatched = comparisons.filter { !$0.mismatches.isEmpty }
                for comparison in mismatched {
                    for mismatch in comparison.mismatches.prefix(5) { print("\(comparison.name) disagreement: \(mismatch)") }
                }
                if !mismatched.isEmpty { throw ExitCode.failure }
                if comparisons.isEmpty { throw ValidationError("no records to compare in \(fso) and \(nso)") }
            }

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
