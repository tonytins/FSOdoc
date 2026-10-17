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
let leastObjects = onMockInstall ? 10 : 2_000

/// A blueprint by file name: from the fixtures' synthetic lots, FreeSO's, the repository's, or the mock install's.
func blueprintFile(_ file: String) throws -> URL {
    let candidates = [try required(oracleDirectory).appendingPathComponent("blueprints/\(file)"),
                      freeSOContent.appendingPathComponent("Blueprints/\(file)"),
                      repository.appendingPathComponent("NSOClient/Lots/\(file)"),
                      repository.appendingPathComponent("NSOClient/MockInstall/Lots/\(file)")]
    return try required(candidates.first { FileManager.default.fileExists(atPath: $0.path) }, file)
}

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
/// lots run, primitives, and room maps.
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

    /// Each lot `oracle-review.sh` ran, with the objects `fso-oracle` left out left out here too, for
    /// the ticks the script runs (1,800, a digest every 300).
    @Test func lotRunsMatchFreeSO() throws {
        let fso = try lines("lots.digests")
        let leftOut = (try? lines("lots.leftout")) ?? []
        let answers = try answers()
        var nso: [String] = []
        for file in Set(fso.compactMap { $0.split(separator: " ").first.map(String.init) }).sorted() {
            var lot = try Blueprint(xml: try Data(contentsOf: try blueprintFile(file)))
            let guids = Set(leftOut.compactMap { line -> UInt32? in
                let fields = line.split(separator: "\t")
                guard fields.count == 2, fields[0] == file else { return nil }
                return UInt32(fields[1].dropFirst(2), radix: 16)
            })
            lot.objects.removeAll { guids.contains($0.guid) }
            nso += answers.lotRun(lot, ticks: 1800, every: 300).map { "\(file) \($0)" }
        }
        let comparison = Comparison.lotRuns(fso: fso, nso: nso)
        print(comparison.summary, comparison.skipsByCount.prefix(8))
        #expect(comparison.matched + comparison.skipped.values.reduce(0, +) > 1)
        if onMockInstall { #expect(comparison.matched >= 1) }  // the mock lot runs in full
        #expect(comparison.mismatches.isEmpty, "\(comparison.mismatches.prefix(5))")
    }

    /// Every generated case of each ported primitive, on the lot `fso-oracle run-primitive`
    /// loaded: the lot as loaded, the exit code, registers, and every effect.
    @Test(arguments: ["expression", "sleep", "test_object_type", "refresh", "set_to_next", "random_number",
                      "play_sound", "create_object_instance", "find_location_for", "run_tree_by_name", "stackobj_notify_out_of_idle", "get_distance_to", "get_direction_to", "transfer_funds"])
    func primitivesMatchFreeSO(primitive: String) throws {
        let directory = try required(oracleDirectory)
        let lotPath = try lines("primitives.lot").first ?? ""
        var lot = try Blueprint(xml: try Data(contentsOf: try blueprintFile(URL(fileURLWithPath: lotPath).lastPathComponent)))
        let leftOut = Set(((try? lines("primitives.leftout")) ?? []).compactMap { UInt32($0.dropFirst(2), radix: 16) })
        lot.objects.removeAll { leftOut.contains($0.guid) }
        let runner = PrimitiveRunner(answers: try answers(), lot: lot)
        let requests = try String(contentsOf: directory.appendingPathComponent("\(primitive).requests.jsonl"), encoding: .utf8)
            .split(separator: "\n").map(String.init)
        let nso = requests.compactMap(runner.answerLine)
        let comparison = Comparison.primitives(primitive, fso: try lines("\(primitive).responses.jsonl"), nso: nso)
        print(comparison.summary, comparison.skipsByCount.prefix(4))
        #expect(comparison.matched > 0)
        #expect(comparison.mismatches.isEmpty, "\(comparison.mismatches.prefix(5))")
    }

    @Test func roomMapsMatchFreeSO() throws {
        let fso = try lines("rooms.jsonl")
        let nso = try fso.map { line -> String in
            let object = try required((try JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any])
            let url = try blueprintFile(try required(object["file"] as? String))
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

    @Test func comparesLotRunsUpToWhatIsNotPorted() {
        let fso = ["a.xml tick 0 x", "a.xml tick 300 y", "b.xml tick 0 x", "b.xml tick 300 y",
                   "c.xml tick 0 x", "c.xml tick 300 y", "d.xml tick 0 x", "e.xml error X"]
        let nso = ["a.xml tick 0 x", "a.xml tick 300 y", "b.xml tick 0 x", "b.xml unsupported at tick 13: primitive 28 (run_tree_by_name)",
                   "c.xml tick 0 z", "c.xml unsupported at tick 13: primitive 28 (run_tree_by_name)", "d.xml tick 0 w"]
        let lots = Comparison.lotRuns(fso: fso, nso: nso)
        #expect(lots.matched == 1)
        #expect(lots.skipped == ["unsupported: primitive 28 (run_tree_by_name)": 1, "FreeSO couldn't run it": 1])
        #expect(lots.mismatches == ["c.xml: FreeSO tick 0 x NSOClient tick 0 z", "d.xml: FreeSO tick 0 x NSOClient tick 0 w"])
    }

    @Test func comparesPrimitiveResponsesByID() {
        let fso = [#"{"id":"a","exit":"GOTO_TRUE","temps":[1],"lot":[[1]]}"#, #"{"id":"b","exit":"GOTO_TRUE","temps":[1]}"#,
                   #"{"id":"c","requestError":"no object 9"}"#, #"{"id":"d","exception":"NullReferenceException: x","temps":[0]}"#,
                   #"{"id":"e","exit":"GOTO_TRUE"}"#, #"{"id":"f","exit":"GOTO_TRUE","protocol":1}"#]
        let nso = [#"{"id":"a","temps":[1],"exit":"GOTO_TRUE","lot":[[1]]}"#, #"{"id":"b","exit":"GOTO_FALSE","temps":[1]}"#,
                   #"{"id":"d","exception":"nullReference","temps":[0]}"#, #"{"id":"e","unsupported":"primitive 28 (run_tree_by_name)"}"#,
                   #"{"id":"f","exit":"GOTO_TRUE"}"#]
        let primitives = Comparison.primitives("Primitive: test", fso: fso, nso: nso)
        #expect(primitives.matched == 3)   // a, d (both threw), f (protocol isn't compared)
        #expect(primitives.mismatches == [#""b": exit: FreeSO "GOTO_TRUE" NSOClient "GOTO_FALSE""#])
        #expect(primitives.skipped == ["FreeSO couldn't run it": 1, "unsupported: primitive 28 (run_tree_by_name)": 1])
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
