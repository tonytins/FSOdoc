import Foundation
import Testing
import SimAntics
import TSOContent
@testable import NSOOracleCore

/// A folder from `NSOClient/scripts/oracle-fixtures.sh` (`TSO_ORACLE_DIR`) and the install it came from.
let oracleDirectory = ProcessInfo.processInfo.environment["TSO_ORACLE_DIR"].map { URL(fileURLWithPath: $0) }
let gameDirectory = ProcessInfo.processInfo.environment["TSO_GAME_DIR"].map { URL(fileURLWithPath: $0) }
let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../..").standardizedFileURL
let freeSOContent = repository.appendingPathComponent("TSOClient/tso.content/Content")
/// Whether the install is NSOClient/MockInstall, which has a handful of objects, not thousands.
let onMockInstall = gameDirectory?.standardizedFileURL.path
    == repository.appendingPathComponent("NSOClient/MockInstall/TSOClient").standardizedFileURL.path
/// The fewest objects a comparison must match: every mock object and FreeSO's own, or most of a real install.
let leastObjects = onMockInstall ? 8 : 2_000

struct MissingFixture: Error {
    var what: String
}

func required<Value>(_ value: Value?, _ what: String = "a fixture value") throws -> Value {
    guard let value else { throw MissingFixture(what: what) }
    return value
}

func lines(_ name: String) throws -> [String] {
    try String(contentsOf: try required(oracleDirectory).appendingPathComponent(name), encoding: .utf8)
        .split(separator: "\n").map(String.init)
}

/// NSOClient against FreeSO's answers from the fixtures: content, entry points, objects run alone,
/// and room maps. The primitive comparisons stay in the SimAntics tests, which rebuild the
/// oracle's lot.
@Suite(.enabled(if: oracleDirectory != nil && gameDirectory != nil, "TSO_ORACLE_DIR or TSO_GAME_DIR is not set"))
struct FixtureComparisonTests {
    private func answers() throws -> Answers {
        Answers(content: try GameContent(.init(gameDirectory: try required(gameDirectory), freeSOContentDirectory: freeSOContent)))
    }

    @Test func contentAndEntryPointsMatchFreeSO() throws {
        let fso = try lines("objects.tsv"), nso = try answers().objectListing()
        for comparison in [Comparison.content(fso: fso, nso: nso), .entryPoints(fso: fso, nso: nso)] {
            print(comparison.summary)
            #expect(comparison.matched >= leastObjects)
            #expect(comparison.mismatches.isEmpty, "\(comparison.mismatches.prefix(5))")
        }
    }

    @Test func objectsRunAloneMatchFreeSO() throws {
        let fso = try lines("objects.digests")
        let answers = try answers()
        let lot = try Blueprint(xml: try Data(contentsOf: freeSOContent.appendingPathComponent("Blueprints/empty_lot_fso.xml")))
            .architecture()
        var nso: [String] = []
        for guid in Set(fso.compactMap { $0.split(separator: " ").first }).sorted() {
            let value = try required(UInt32(guid, radix: 16))
            nso += answers.objectRun(guid: value, on: lot, ticks: 30, every: 10).map { "\(guid) \($0)" }
        }
        let comparison = Comparison.objectRuns(fso: fso, nso: nso)
        print(comparison.summary, comparison.skipsByCount.prefix(8))
        #expect(comparison.matched >= leastObjects)
        #expect(comparison.mismatches.isEmpty, "\(comparison.mismatches.prefix(5))")
    }

    @Test func roomMapsMatchFreeSO() throws {
        let directory = try required(oracleDirectory)
        let fso = try lines("rooms.jsonl")
        let nso = try fso.map { line -> String in
            let object = try required((try JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any])
            let file = try required(object["file"] as? String)
            let candidates = [directory.appendingPathComponent("blueprints/\(file)"),
                              freeSOContent.appendingPathComponent("Blueprints/\(file)"),
                              repository.appendingPathComponent("NSOClient/Lots/\(file)")]
            let url = try required(candidates.first { FileManager.default.fileExists(atPath: $0.path) }, file)
            return String(decoding: try JSONSerialization.data(withJSONObject: Answers.roomMaps(of: url)), as: UTF8.self)
        }
        let comparison = Comparison.roomMaps(fso: fso, nso: nso)
        print(comparison.summary)
        #expect(comparison.matched > 1)
        #expect(comparison.mismatches.isEmpty, "\(comparison.mismatches.prefix(5))")
    }
}

@Suite struct ComparisonTests {
    @Test func comparesContentColumnByColumn() {
        let fso = ["00000001\tchair\tchairs\t-\t3\t4\t0\t0:4096", "00000002\tmissing",
                   "00000003\terror\tNullReferenceException", "00000004\terror\tArgumentException", "00000005\tlamp\tlamps\t-\t1\t1\t0\tnone"]
        let nso = ["00000001\tchair\tchairs\t-\t3\t4\t0\t0:4096", "00000002\tmissing",
                   "00000003\terror\tmissingFile", "00000004\tlamp\tlamps\t-\t1\t1\t0\tnone", "00000005\tlamp\tlamps\t-\t2\t1\t0\tnone"]
        let content = Comparison.content(fso: fso, nso: nso)
        #expect(content.matched == 3 && content.recovered == 1 && content.mismatches.count == 1)
        #expect(content.mismatches[0].hasPrefix("00000005:"))
        let entryPoints = Comparison.entryPoints(fso: fso, nso: nso)
        #expect(entryPoints.matched == 2 && entryPoints.mismatches.isEmpty)
    }

    @Test func comparesObjectRunsAndCountsWhatCantRun() {
        let fso = ["a tick 0 seed 1 entities 1 digest x", "a tick 10 seed 2 entities 1 digest y",
                   "b tick 0 seed 1 entities 1 digest x", "c missing", "d tick 0 seed 1 entities 1 digest x",
                   "e tick 0 seed 1 entities 1 digest x"]
        let nso = ["a tick 0 seed 1 entities 1 digest x", "a tick 10 seed 2 entities 1 digest y",
                   "b tick 0 seed 1 entities 1 digest z", "c missing",
                   "d tick 0 seed 1 entities 1 digest x", "d unsupported primitive 11 (get_distance_to)", "e missing"]
        let runs = Comparison.objectRuns(fso: fso, nso: nso)
        #expect(runs.matched == 1 && runs.mismatches == ["b: FreeSO tick 0 seed 1 entities 1 digest x NSOClient tick 0 seed 1 entities 1 digest z"])
        #expect(runs.skipped == ["FreeSO couldn't run it": 1, "unsupported: primitive 11 (get_distance_to)": 1, "not in NSOClient's content": 1])
    }

    @Test func comparesRoomMapsEntryForEntry() {
        let fso = [#"{"file":"a.xml","size":[4,4],"maps":[[1]],"rooms":[[1,1,0,true,16,false,[],[0,0,4,4],[1]]]}"#,
                   #"{"file":"b.xml","size":[4,4],"maps":[[1]],"rooms":[]}"#, #"{"file":"c.xml","error":"X"}"#]
        let nso = [#"{"rooms":[[1,1,0,true,16,false,[],[0,0,4,4],[1]]],"maps":[[1]],"size":[4,4],"file":"a.xml"}"#,
                   #"{"file":"b.xml","size":[4,4],"maps":[[2]],"rooms":[]}"#]
        let rooms = Comparison.roomMaps(fso: fso, nso: nso)
        #expect(rooms.matched == 1 && rooms.mismatches == ["b.xml: maps differs"] && rooms.skipped == ["FreeSO couldn't load it": 1])
    }
}

@Suite struct ReviewTests {
    private func run(_ install: String, matched: Int) -> Review.Run {
        var comparison = Comparison(name: "Room maps")
        comparison.matched = matched
        comparison.mismatches = ["b.xml: maps | differs"]
        comparison.skipped = ["FreeSO couldn't load it": 2]
        return Review.Run(install: install, date: Date(timeIntervalSince1970: 0), commit: "abc1234",
                          comparisons: [comparison], timings: ["fso room-maps": 2.5])
    }

    @Test func writesOneSectionPerInstall() {
        let first = Review.updating(nil, with: run("production", matched: 61))
        #expect(first.hasPrefix("# NSOClient review"))
        #expect(first.contains("## Production") && first.contains("Run on 1970-01-01 at commit `abc1234`."))
        #expect(first.contains("| Room maps | 61 | 1 | 2 | 0 |"))
        #expect(first.contains("- b.xml: maps \\| differs") && first.contains("| `fso room-maps` | 2.5 |"))

        let both = Review.updating(first, with: run("beta", matched: 50))
        #expect(both.contains("## Beta") && both.contains("## Production"))
        #expect(both.range(of: "## Production")!.lowerBound < both.range(of: "## Beta")!.lowerBound)  // production first

        let rerun = Review.updating(both, with: run("production", matched: 62))
        #expect(rerun.contains("| Room maps | 62 |") && !rerun.contains("| Room maps | 61 |"))
        #expect(rerun.contains("| Room maps | 50 |"))                     // the beta's section stays
        #expect(Review.sections(of: rerun).count == 2)
    }
}
