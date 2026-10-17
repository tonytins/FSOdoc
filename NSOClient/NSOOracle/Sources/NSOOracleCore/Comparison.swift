import Foundation

/// One experiment's outcome: how `fso-oracle`'s and `nso-oracle`'s records of it compare.
///
/// Neither side is assumed right. A disagreement is a finding, listed with both records for
/// someone to explain; an inconclusive case is one where a side couldn't take the measurement.
public struct Comparison: Sendable, Equatable {
    public var name: String
    /// Cases where both recorded the same result.
    public var matched = 0
    /// Cases where the results differ, each described with both.
    public var mismatches: [String] = []
    /// Inconclusive cases, by why: NSOClient can't take the measurement yet, or FreeSO couldn't.
    public var skipped: [String: Int] = [:]
    /// Cases NSOClient measures where FreeSO couldn't, such as an object FreeSO fails to load.
    public var recovered = 0

    public init(name: String) {
        self.name = name
    }

    /// Why cases were inconclusive, most common first, then by name.
    public var skipsByCount: [(reason: String, count: Int)] {
        skipped.map { (reason: $0.key, count: $0.value) }.sorted { ($0.count, $1.reason) > ($1.count, $0.reason) }
    }

    public var summary: String {
        let skips = skipped.values.reduce(0, +)
        return "\(name): \(matched) agree, \(mismatches.count) disagree, \(skips) inconclusive"
            + (recovered > 0 ? ", \(recovered) answered where FreeSO failed" : "")
    }

    mutating func skip(_ reason: String) {
        skipped[reason, default: 0] += 1
    }

    // MARK: Each kind

    /// `list-objects`: the content columns (label, resource, semi-global, routine and tuning
    /// counts), object by object. An object FreeSO can't load counts as recovered if NSOClient
    /// loads it, and as matched if both fail the same way (FreeSO's null reference is NSOClient's
    /// missing file).
    public static func content(fso: [String], nso: [String]) -> Comparison {
        var result = Comparison(name: "Content")
        let ours = byFirstField(nso)
        for line in fso {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 2 else { continue }
            let mine = ours[fields[0]] ?? []
            switch fields[1] {
            case "missing":
                if mine.count >= 2 && mine[1] == "missing" { result.matched += 1 } else {
                    result.mismatches.append("\(fields[0]): FreeSO has no OBJD; NSOClient \(mine.dropFirst().prefix(2))")
                }
            case "error":
                if mine.count >= 2 && mine[1] == "error" {
                    if mine.count >= 3 && mine[2] == "missingFile" && fields.count >= 3 && fields[2] == "NullReferenceException" {
                        result.matched += 1
                    } else {
                        result.mismatches.append("\(fields[0]): FreeSO \(fields.dropFirst()) NSOClient \(mine.dropFirst())")
                    }
                } else if mine.count >= 8 {
                    result.recovered += 1
                } else {
                    result.mismatches.append("\(fields[0]): FreeSO \(fields.dropFirst()) NSOClient \(mine.dropFirst())")
                }
            default:
                let columns = 7
                if mine.count >= columns && Array(mine.prefix(columns)) == Array(fields.prefix(columns)) {
                    result.matched += 1
                } else {
                    result.mismatches.append("\(fields[0]): FreeSO \(fields.prefix(columns).dropFirst()) NSOClient \(mine.prefix(columns).dropFirst())")
                }
            }
        }
        return result
    }

    /// `list-objects`, column 8: the entry point table each loaded object's entity builds.
    public static func entryPoints(fso: [String], nso: [String]) -> Comparison {
        var result = Comparison(name: "Entry points")
        let ours = byFirstField(nso)
        for line in fso {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 8 else { continue }
            let mine = ours[fields[0]] ?? []
            if mine.count == 8 && mine[7] == fields[7] {
                result.matched += 1
            } else {
                result.mismatches.append("\(fields[0]): FreeSO \(fields[7].prefix(80)) NSOClient \((mine.count == 8 ? mine[7] : "no answer").prefix(80))")
            }
        }
        return result
    }

    /// `run-objects`: every digest line of each object FreeSO could run.
    public static func objectRuns(fso: [String], nso: [String]) -> Comparison {
        var result = Comparison(name: "Objects run alone")
        let (expected, order) = groupedByGUID(fso)
        let (actual, _) = groupedByGUID(nso)
        for guid in order {
            let lines = expected[guid] ?? []
            guard lines.first?.hasPrefix("tick") == true else {
                result.skip("FreeSO couldn't run it")
                continue
            }
            let mine = actual[guid] ?? []
            if let reason = mine.first(where: { $0.hasPrefix("unsupported") }) {
                result.skip(reason.replacingOccurrences(of: "unsupported ", with: "unsupported: "))
            } else if mine.first == "missing" {
                result.skip("not in NSOClient's content")
            } else if mine.first?.hasPrefix("error") == true {
                result.skip("NSOClient failed to create it")
            } else if mine == lines {
                result.matched += 1
            } else {
                let first = zip(lines, mine).first { $0 != $1 }
                result.mismatches.append("\(guid): FreeSO \(first?.0 ?? "\(lines.count) lines") NSOClient \(first?.1 ?? "\(mine.count) lines")")
            }
        }
        return result
    }

    /// `run-lot`: every digest line of each lot, prefixed with the lot's file name. A lot
    /// agrees if every line does. One where NSOClient stopped at something not ported is
    /// inconclusive, by what, if every digest before it agrees; otherwise, as for any other
    /// difference, the disagreement names the first line that differs.
    public static func lotRuns(fso: [String], nso: [String]) -> Comparison {
        var result = Comparison(name: "Lots run")
        let (expected, order) = groupedByGUID(fso)
        let (actual, _) = groupedByGUID(nso)
        for lot in order {
            let lines = expected[lot] ?? []
            guard lines.first?.hasPrefix("tick") == true else {
                result.skip("FreeSO couldn't run it")
                continue
            }
            let mine = actual[lot] ?? []
            let reached = mine.prefix { !$0.hasPrefix("unsupported") }
            if reached.count < mine.count, Array(lines.prefix(reached.count)) == Array(reached) {
                // `unsupported at tick N: what`, counted by what.
                let line = mine[reached.count]
                let what = line.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? line
                result.skip("unsupported: \(what)")
            } else if mine == lines {
                result.matched += 1
            } else {
                let first = zip(lines, mine).first { $0 != $1 }
                result.mismatches.append("\(lot): FreeSO \(first?.0 ?? "\(lines.count) lines") NSOClient \(first?.1 ?? "\(mine.count) lines")")
            }
        }
        return result
    }

    /// The `run-primitive` response fields both sides must agree on: the lot as loaded, the exit
    /// code (or, for an exception, only that there was one), and the state after.
    static let primitiveFields = ["primitive", "noPrimitive", "exit", "temps", "tempXL", "locals", "args", "stackObject",
                                  "seed", "thread", "frames", "globals", "objects", "created", "removed",
                                  "lot", "lotSize", "groups", "callerGUID", "stackObjectGUID"]

    /// `run-primitive`: each response by its `id`. Requests FreeSO couldn't run are inconclusive,
    /// and so are those NSOClient answered with `unsupported`, by what. A disagreement names the
    /// first field that differs.
    public static func primitives(_ name: String, fso: [String], nso: [String]) -> Comparison {
        var result = Comparison(name: name)
        func responses(_ lines: [String]) -> [(String, [String: Any])] {
            lines.compactMap { line in
                guard let object = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any] else { return nil }
                return (plain(object["id"]), object)
            }
        }
        let ours = Dictionary(responses(nso), uniquingKeysWith: { first, _ in first })
        for (id, theirs) in responses(fso) {
            guard theirs["requestError"] == nil else {
                result.skip("FreeSO couldn't run it")
                continue
            }
            guard let mine = ours[id] else {
                result.mismatches.append("\(id): NSOClient has no answer")
                continue
            }
            if let reason = mine["unsupported"] as? String {
                result.skip("unsupported: \(reason)")
                continue
            }
            if let error = mine["requestError"] {
                result.mismatches.append("\(id): NSOClient couldn't run it: \(error)")
                continue
            }
            func fields(_ response: [String: Any]) -> [String: Any] {
                var fields = response.filter { primitiveFields.contains($0.key) }
                if response["exception"] != nil { fields["exception"] = true }
                return fields
            }
            let (expected, actual) = (fields(theirs), fields(mine))
            let keys = Set(expected.keys).union(actual.keys).sorted()
            if let key = keys.first(where: { canonical(expected[$0]) != canonical(actual[$0]) }) {
                let show = { (value: Any?) in value == nil ? "nothing" : String(plain(value).prefix(200)) }
                result.mismatches.append("\(id): \(key): FreeSO \(show(expected[key])) NSOClient \(show(actual[key]))")
            } else {
                result.matched += 1
            }
        }
        return result
    }

    /// `room-maps`: each lot's size, room maps, and rooms, entry for entry.
    public static func roomMaps(fso: [String], nso: [String]) -> Comparison {
        var result = Comparison(name: "Room maps")
        func objects(_ lines: [String]) -> [String: [String: Any]] {
            var byFile: [String: [String: Any]] = [:]
            for line in lines {
                guard let object = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
                      let file = object["file"] as? String else { continue }
                byFile[file] = object
            }
            return byFile
        }
        let ours = objects(nso)
        for (file, theirs) in objects(fso).sorted(by: { $0.key < $1.key }) {
            guard theirs["error"] == nil else {
                result.skip("FreeSO couldn't load it")
                continue
            }
            guard let mine = ours[file], mine["error"] == nil else {
                result.mismatches.append("\(file): NSOClient \(ours[file]?["error"] ?? "has no answer")")
                continue
            }
            let keys = ["size", "rooms", "maps"]
            if let key = keys.first(where: { canonical(theirs[$0]) != canonical(mine[$0]) }) {
                result.mismatches.append("\(file): \(key) differs")
            } else {
                result.matched += 1
            }
        }
        return result
    }

    // MARK: Parsing

    /// A JSON value as text, with sorted keys, or `null`.
    private static func plain(_ value: Any?) -> String {
        guard let value, let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed]) else {
            return "null"
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// A JSON value written with sorted keys, so equal values compare equal.
    private static func canonical(_ value: Any?) -> Data? {
        guard let value else { return nil }
        return try? JSONSerialization.data(withJSONObject: ["v": value], options: [.sortedKeys])
    }

    private static func byFirstField(_ lines: [String]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for line in lines {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if let key = fields.first { result[key] = fields }
        }
        return result
    }

    /// `key rest` lines (a GUID or a lot's file name first), grouped by key in first-seen order.
    private static func groupedByGUID(_ lines: [String]) -> ([String: [String]], [String]) {
        var grouped: [String: [String]] = [:], order: [String] = []
        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if grouped[parts[0]] == nil { order.append(parts[0]) }
            grouped[parts[0], default: []].append(parts[1])
        }
        return (grouped, order)
    }
}
