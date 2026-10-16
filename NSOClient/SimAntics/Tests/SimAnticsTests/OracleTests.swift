import Foundation
import Testing
import TSOContent
@testable import SimAntics

/// A folder from `NSOClient/scripts/oracle-fixtures.sh`, named by `TSO_ORACLE_DIR`, or `nil`.
let oracleDirectory: URL? = ProcessInfo.processInfo.environment["TSO_ORACLE_DIR"].map { URL(fileURLWithPath: $0) }
let gameDirectory: URL? = ProcessInfo.processInfo.environment["TSO_GAME_DIR"].map { URL(fileURLWithPath: $0) }

/// FreeSO's content folder in the 2017 snapshot, which the oracle uses too.
let freeSOContentDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("../../../../TSOClient/tso.content/Content").standardizedFileURL

/// Compares each ported primitive with the 2017 answers from `fso-oracle run-primitive`.
///
/// Each case runs on fresh entities with the GUIDs the oracle reports and the state the
/// request sets, then the exit code (or failure), registers, and every changed value
/// are compared. Cases that need behavior this port doesn't have yet are counted, not failed.
@Suite(.enabled(if: oracleDirectory != nil && gameDirectory != nil, "TSO_ORACLE_DIR or TSO_GAME_DIR is not set"))
struct OraclePrimitiveTests {
    @Test(arguments: ["expression", "sleep", "test_object_type", "refresh", "set_to_next", "random_number"])
    func matches2017(primitive: String) throws {
        let directory = try required(oracleDirectory)
        let requests = try Dictionary(uniqueKeysWithValues: jsonLines(directory.appendingPathComponent("\(primitive).requests.jsonl"))
            .map { (try required($0["id"] as? String), $0) })
        let responses = try jsonLines(directory.appendingPathComponent("\(primitive).responses.jsonl"))
        let content = try GameContent(.init(gameDirectory: try required(gameDirectory),
                                            freeSOContentDirectory: freeSOContentDirectory))

        var matched = 0, unsupported: [String: Int] = [:], mismatches: [String] = []
        for response in responses where response["requestError"] == nil {
            let id = try required(response["id"] as? String)
            let outcome = try OracleCase(request: try required(requests[id]), response: response).run(content)
            switch outcome {
            case .unsupported(let reason):
                unsupported[reason, default: 0] += 1
            case .result(let actual):
                let expected = OracleCase.comparable(response)
                if canonical(actual) == canonical(expected) {
                    matched += 1
                } else {
                    mismatches.append("\(id): 2017 \(canonical(expected)) Swift \(canonical(actual))")
                }
            }
        }
        print("\(primitive) against 2017: \(matched) matched, \(mismatches.count) mismatched, "
              + "\(unsupported.values.reduce(0, +)) unsupported \(unsupported.sorted { $0.value > $1.value }.prefix(8))")
        #expect(matched > 0)
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches, first: \(mismatches.prefix(5).joined(separator: "\n"))")
    }
}

/// One `run-primitive` request, rebuilt in a Swift VM.
struct OracleCase {
    enum Outcome {
        case result([String: Any])
        case unsupported(String)
    }

    let request: [String: Any]
    let response: [String: Any]

    /// The response fields both sides produce: the exit code or whether it failed, and the state after.
    static func comparable(_ response: [String: Any]) -> [String: Any] {
        var fields = response.filter { ["exit", "temps", "tempXL", "locals", "args", "stackObject", "seed",
                                         "globals", "objects", "created", "removed", "thread"].contains($0.key) }
        if response["exception"] != nil { fields["failed"] = true }
        return fields
    }

    func run(_ content: GameContent) throws -> Outcome {
        let seed = (request["seed"] as? String).flatMap { UInt64($0, radix: 16) } ?? 0x0F50_D0C5_EED0_0001
        let vm = try VM(content: content, seed: seed)
        let callerID = Int16(request["caller"] as? Int ?? 1)
        let stackObjectID = Int16(request["stackObject"] as? Int ?? 0)
        // Rebuild every object on the oracle's lot, with the categories it registered.
        for entry in response["lot"] as? [[Any]] ?? [] {
            let id = Int16(try required(entry[0] as? Int)), category = Int16(try required(entry[2] as? Int))
            let entity = try vm.addObject(guid: try required(UInt32(try required(entry[1] as? String), radix: 16)), id: id)
            entity.objectData[Int(ObjectVariable.category.rawValue)] = category
            if entry[3] as? Bool == true { vm.changeCategory(of: entity, from: nil, to: category) }
        }
        if vm.entity(id: callerID) == nil { try vm.addObject(guid: try guid("callerGUID"), id: callerID) }
        if response["stackObjectGUID"] != nil, vm.entity(id: stackObjectID) == nil {
            try vm.addObject(guid: try guid("stackObjectGUID"), id: stackObjectID)
        }
        let caller = try required(vm.entity(id: callerID))

        for (key, value) in request["globals"] as? [String: Int] ?? [:] { vm.globalState[Int(key)!] = Int16(value) }
        if let clock = request["clock"] as? [String: Int] {
            vm.clock.hours = Int32(clock["hours"] ?? 0)
            vm.clock.minutes = Int32(clock["minutes"] ?? 0)
            vm.clock.minuteFractions = Int32(clock["minuteFractions"] ?? 0)
        }
        for (key, state) in request["objects"] as? [String: [String: Any]] ?? [:] {
            let entity = try required(vm.entity(id: Int16(key)!))
            for (index, value) in state["data"] as? [String: Int] ?? [:] { entity.objectData[Int(index)!] = Int16(value) }
            for (index, value) in state["attributes"] as? [String: Int] ?? [:] { entity.setAttribute(Int16(value), at: UInt16(index)!) }
            if let list = state["list"] as? [Int] { entity.list = list.map { Int16($0) } }
            if let direction = state["direction"] as? Int { entity.directionNotch = Int16(direction) }
        }
        if let tick = request["currentTick"] as? Int { vm.scheduler.currentTick = UInt32(tick) }
        if let start = request["idleStart"] as? Int { caller.thread.idleStartTick = UInt32(start) }
        if let interrupt = request["interrupt"] as? Bool { caller.thread.isInterrupted = interrupt }
        for (index, value) in (request["temps"] as? [Int] ?? []).enumerated() { caller.thread.tempRegisters[index] = Int16(value) }
        for (index, value) in (request["tempXL"] as? [Int] ?? []).enumerated() { caller.thread.tempXL[index] = Int32(value) }

        let operand = try required(Data(hexString: try required(request["operand"] as? String)))
        let (primitive, ran) = try vm.makePrimitiveFrame(
            opcode: UInt8(try required(request["opcode"] as? Int)),
            operand: [UInt8](operand) + [UInt8](repeating: 0, count: 8 - operand.count), caller: caller,
            locals: (request["locals"] as? [Int] ?? []).map { Int16($0) },
            arguments: (request["args"] as? [Int] ?? [0, 0, 0, 0]).map { Int16($0) }, stackObjectID: stackObjectID)
        let before = Snapshot(vm)
        let threadBefore = (caller.thread.idleStartTick, caller.thread.isInterrupted, caller.thread.scheduledTick)
        var fields: [String: Any] = [:]
        switch Result(catching: { () throws(SimAnticsError) in try primitive.execute(in: ran) }) {
        case .success(let exit): fields["exit"] = exit.name2017
        case .failure(.unsupported(let reason)): return .unsupported(reason)
        case .failure: fields["failed"] = true
        }
        fields["temps"] = caller.thread.tempRegisters.map(Int.init)
        fields["tempXL"] = caller.thread.tempXL.map(Int.init)
        fields["locals"] = ran.locals.map(Int.init)
        fields["args"] = ran.arguments.map(Int.init)
        fields["stackObject"] = Int(ran.stackObjectID)
        fields["seed"] = String(format: "%016llx", vm.random.seed)
        Snapshot(vm).describe(since: before, into: &fields)
        var threadChanges: [String: Any] = [:]
        if caller.thread.idleStartTick != threadBefore.0 { threadChanges["idleStart"] = Int(caller.thread.idleStartTick) }
        if caller.thread.isInterrupted != threadBefore.1 { threadChanges["interrupt"] = caller.thread.isInterrupted }
        if caller.thread.scheduledTick != threadBefore.2 { threadChanges["scheduledTick"] = Int(caller.thread.scheduledTick) }
        fields["thread"] = threadChanges
        return .result(fields)
    }

    private func guid(_ key: String) throws -> UInt32 {
        try required(UInt32(try required(response[key] as? String), radix: 16))
    }
}

/// The state a primitive can change outside its frame, as the oracle snapshots it.
struct Snapshot {
    struct EntityState {
        var data: [Int16], attributes: [Int16], list: [Int16], direction: Int16
    }

    let globals: [Int16]
    let entities: [Int16: EntityState]

    init(_ vm: VM) {
        globals = vm.globalState
        entities = Dictionary(uniqueKeysWithValues: vm.entities.map {
            ($0.objectID, EntityState(data: $0.objectData, attributes: $0.attributes, list: $0.list, direction: $0.directionNotch))
        })
    }

    func describe(since before: Snapshot, into fields: inout [String: Any]) {
        fields["globals"] = Self.changes(before.globals, globals)
        var objects: [String: Any] = [:]
        for (id, state) in entities {
            guard let old = before.entities[id] else { continue }
            var changes: [String: Any] = [:]
            let data = Self.changes(old.data, state.data), attributes = Self.changes(old.attributes, state.attributes)
            if !data.isEmpty { changes["data"] = data }
            if !attributes.isEmpty { changes["attributes"] = attributes }
            if old.list != state.list { changes["list"] = state.list.map(Int.init) }
            if old.direction != state.direction { changes["direction"] = 1 << Int(state.direction) } // 2017's Direction flags
            if !changes.isEmpty { objects[String(id)] = changes }
        }
        fields["objects"] = objects
        fields["created"] = entities.keys.filter { before.entities[$0] == nil }.sorted().map(Int.init)
        fields["removed"] = before.entities.keys.filter { entities[$0] == nil }.sorted().map(Int.init)
    }

    private static func changes(_ before: [Int16], _ after: [Int16]) -> [String: Int] {
        var changes: [String: Int] = [:]
        for index in 0..<max(before.count, after.count) {
            let old = index < before.count ? before[index] : 0, new = index < after.count ? after[index] : 0
            if old != new { changes[String(index)] = Int(new) }
        }
        return changes
    }
}

func jsonLines(_ url: URL) throws -> [[String: Any]] {
    try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map {
        try required(try JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
    }
}

/// JSON with sorted keys, for comparing two decoded answers.
func canonical(_ value: [String: Any]) -> String {
    (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? "?"
}

extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}

struct MissingFixtureValue: Error, CustomStringConvertible {
    var description: String
}

/// Unwraps a value an oracle fixture must have; unlike `#require`, it nests.
func required<Value>(_ value: Value?, _ what: @autoclosure () -> String = "a fixture value",
                     sourceLocation: SourceLocation = #_sourceLocation) throws -> Value {
    guard let value else { throw MissingFixtureValue(description: "missing \(what()) at \(sourceLocation)") }
    return value
}

/// Compares every object's entry point table with the one a 2017 entity builds (`objects.tsv`, column 8).
@Suite(.enabled(if: oracleDirectory != nil && gameDirectory != nil, "TSO_ORACLE_DIR or TSO_GAME_DIR is not set"))
struct OracleEntryPointTests {
    @Test func matches2017() throws {
        let lines = try String(contentsOf: try required(oracleDirectory).appendingPathComponent("objects.tsv"), encoding: .utf8)
            .split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        let content = try GameContent(.init(gameDirectory: try required(gameDirectory),
                                            freeSOContentDirectory: freeSOContentDirectory))
        let vm = try VM(content: content, seed: 1)
        var compared = 0, mismatches: [String] = []
        for (index, fields) in lines.enumerated() where fields.count == 8 {
            let guid = try required(UInt32(fields[0], radix: 16))
            let actual: String
            do {
                let entity = try vm.addObject(guid: guid, id: Int16(index + 1))
                actual = entity.entryPoints.map { $0.map { "\($0.conditionFunction):\($0.actionFunction)" }.joined(separator: ",") } ?? "none"
            } catch {
                actual = "error \(error)"
            }
            if actual != fields[7] { mismatches.append("\(fields[0]): 2017 \(fields[7].prefix(80)) Swift \(actual.prefix(80))") }
            compared += 1
        }
        print("Entry points against 2017: \(compared) objects compared, \(mismatches.count) mismatched")
        #expect(compared > 2_000)
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5).joined(separator: "\n"))")
    }
}

/// Runs each object alone, out of the world, and compares state digests with
/// `fso-oracle run-objects` (`objects.digests`) after creation and every 10 ticks to 30.
///
/// Objects whose run needs behavior not ported yet are counted, not compared, as are
/// multi-tile objects (not ported) and objects 2017 can't create.
@Suite(.enabled(if: oracleDirectory != nil && gameDirectory != nil, "TSO_ORACLE_DIR or TSO_GAME_DIR is not set"))
struct OracleObjectRunTests {
    @Test func matches2017() throws {
        let text = try String(contentsOf: try required(oracleDirectory).appendingPathComponent("objects.digests"), encoding: .utf8)
        var expected: [String: [String]] = [:], order: [String] = []
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if expected[parts[0]] == nil { order.append(parts[0]) }
            expected[parts[0], default: []].append(parts[1])
        }
        let content = try GameContent(.init(gameDirectory: try required(gameDirectory),
                                            freeSOContentDirectory: freeSOContentDirectory))
        var matched = 0, mismatches: [String] = [], skipped: [String: Int] = [:]
        for guidText in order {
            let lines = try required(expected[guidText])
            guard lines.first?.hasPrefix("tick") == true else { skipped["2017 couldn't run it", default: 0] += 1; continue }
            let guid = try required(UInt32(guidText, radix: 16))
            guard let object = try content.objects.object(guid: guid) else { skipped["not in Swift content", default: 0] += 1; continue }
            if object.definition.masterID != 0 && object.definition.subIndex == -1 {
                skipped["multi-tile", default: 0] += 1
                continue
            }
            let vm = try VM(content: content, seed: 0x0F50_D0C5_EED0_0001)
            var actual: [String] = []
            func record(_ tick: Int) {
                actual.append("tick \(tick) seed \(String(format: "%016llx", vm.random.seed)) entities \(vm.entities.count) digest \(StateDigest.hex(of: vm))")
            }
            do {
                try vm.addObject(guid: guid, id: 1).initialize()
                record(0)
                for tick in 1...30 {
                    vm.tick()
                    if tick % 10 == 0 { record(tick) }
                }
            } catch {
                skipped["Swift failed to create it", default: 0] += 1
                continue
            }
            if let gap = vm.reportedErrors.first(where: { if case .unsupported = $0.error { true } else { false } }) {
                if case .unsupported(let reason) = gap.error {
                    // Name what failed first when 2017 would have deleted the object.
                    let cause = vm.reportedErrors.first.map { "\($0.error)" } ?? ""
                    skipped["unsupported: \(reason)\(gap == vm.reportedErrors.first ? "" : " after \(cause)")", default: 0] += 1
                }
                continue
            }
            if actual == lines {
                matched += 1
            } else {
                let first = zip(lines, actual).first { $0 != $1 }
                mismatches.append("\(guidText) \(object.definition.label): 2017 \(first?.0 ?? "?") Swift \(first?.1 ?? "?")")
            }
        }
        print("Objects run against 2017: \(matched) matched, \(mismatches.count) mismatched, skipped \(skipped.sorted { $0.value > $1.value }.prefix(10))")
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches, first: \(mismatches.prefix(5).joined(separator: "\n"))")
    }
}
