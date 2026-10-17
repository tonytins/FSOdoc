import Foundation
import SimAntics
import TSOContent
import TSOFiles

/// NSOClient's answers to `fso-oracle`'s questions, in `fso-oracle`'s formats (see
/// `NSOClient/Oracle/README.md`), so the two can be compared line for line.
///
/// Where NSOClient can't answer because something isn't ported yet, it says so with an
/// `unsupported` line, which `fso-oracle` never prints; comparisons count those as skipped.
public struct Answers {
    public let content: GameContent

    public init(content: GameContent) {
        self.content = content
    }

    // MARK: list-objects

    /// One tab-separated line per registered object, sorted by GUID, as `fso-oracle list-objects`
    /// prints them: the GUID (8 hex digits), then the `OBJD` label, the resource name, the
    /// semi-global (or `-`), routines by name, BHAVs, tuning tables, and the entry point table
    /// (`condition:action` pairs, or `none`); or `missing`, or `error` and the error's kind.
    public func objectListing() -> [String] {
        let vm = try? VM(content: content, seed: 1)
        return content.objects.references.enumerated().map { index, reference in
            let guid = String(format: "%08x", reference.guid)
            let object: GameObject?
            do {
                object = try content.objects.object(guid: reference.guid)
            } catch {
                return "\(guid)\terror\t\(Self.kind(of: error))"
            }
            guard let object else { return "\(guid)\tmissing" }
            let resource = object.resource
            let routines = (try? resource.mainFile.chunks(BHAV.self).count).map(String.init) ?? "error"
            return [guid, object.definition.label, resource.name, resource.semiGlobal?.name ?? "-",
                    "\(resource.treesByName.count)", routines, "\(resource.tuning?.tables.count ?? 0)",
                    entryPoints(of: reference.guid, id: Int16(truncatingIfNeeded: index + 1), in: vm)].joined(separator: "\t")
        }
    }

    /// The entry point table an entity builds, as `fso-oracle` prints it.
    private func entryPoints(of guid: UInt32, id: Int16, in vm: VM?) -> String {
        guard let vm else { return "error no global" }
        do {
            let entity = try vm.addObject(guid: guid, id: id)
            return entity.entryPoints.map { $0.map { "\($0.conditionFunction):\($0.actionFunction)" }.joined(separator: ",") } ?? "none"
        } catch {
            return "error \(error)"
        }
    }

    // MARK: Loading a lot

    /// The seed both oracles use unless told otherwise.
    public static let defaultSeed: UInt64 = 0x0F50_D0C5_EED0_0001

    /// A VM with a lot loaded as `fso-oracle` loads one: the blueprint, then the tick the load
    /// runs in, then the random seed set again, so the first digest starts from the seed.
    func loadedLot(_ blueprint: Blueprint, seed: UInt64) throws(SimAnticsError) -> (VM, [VM.LeftOut]) {
        let vm = try VM(content: content, seed: seed)
        let leftOut = try vm.load(blueprint)
        vm.tick()
        vm.random = VMRandom(seed: seed)
        return (vm, leftOut)
    }

    private static func digest(of vm: VM, tick: Int) -> String {
        "tick \(tick) seed \(String(format: "%016llx", vm.random.seed)) entities \(vm.entities.count) digest \(StateDigest.hex(of: vm))"
    }

    /// The digest line, then with `dump`, each entity's digested fields.
    private static func digestLines(of vm: VM, tick: Int, dump: Bool) -> [String] {
        [digest(of: vm, tick: tick)] + (dump ? StateDigest.lines(of: vm) : [])
    }

    /// Ticks `vm`, with a digest every `every` ticks and at the end, then an `unsupported` line
    /// if a thread reached something not ported (naming what failed first when that came before).
    private static func run(_ vm: VM, ticks: Int, every: Int, dump: Bool = false, into lines: inout [String]) {
        if ticks > 0 {
            for tick in 1...ticks {
                vm.tick()
                if (every > 0 && tick % every == 0) || tick == ticks { lines += digestLines(of: vm, tick: tick, dump: dump) }
            }
        }
        if let gap = vm.reportedErrors.first(where: { if case .unsupported = $0.error { true } else { false } }),
           case .unsupported(let reason) = gap.error {
            let first = vm.reportedErrors.first
            lines.append("unsupported \(reason)" + (gap == first ? "" : " after \(first.map { "\($0.error)" } ?? "")"))
        }
    }

    // MARK: run-objects

    /// For one GUID: the lot with its objects taken out, the object created out of the world,
    /// then ticks, as `fso-oracle run-objects` does. Lines don't include the GUID: `tick N seed S
    /// entities E digest D` after creation, every `every` ticks, and at the end; `missing` if
    /// there's no such object; `error` and the error if creating it fails; and, after the digests,
    /// `unsupported` and what wasn't ported if the object reached it.
    public func objectRun(guid: UInt32, on lot: Blueprint, ticks: Int, every: Int,
                          seed: UInt64 = Answers.defaultSeed) -> [String] {
        var empty = lot
        empty.objects = []
        let vm: VM
        do {
            (vm, _) = try loadedLot(empty, seed: seed)
            guard try vm.createObject(guid: guid) != nil else { return ["missing"] }
        } catch SimAnticsError.unsupported(let reason) {
            return ["unsupported while creating: \(reason)"]
        } catch {
            return ["error \(error)"]
        }
        var lines = [Self.digest(of: vm, tick: 0)]
        Self.run(vm, ticks: ticks, every: every, into: &lines)
        return lines
    }

    // MARK: run-lot

    /// A lot loaded with its objects, then ticked, as `fso-oracle run-lot` does: `tick N seed S
    /// entities E digest D` after loading, every `every` ticks, and at the end. Once a thread
    /// reaches something not ported, the state can't match FreeSO's any more, so the run stops
    /// there with `unsupported at tick N:` and what wasn't ported, and no digest for that tick;
    /// `N` is 0 if loading reached it. Other failures give `error`. Objects left out are reported
    /// through `leftOut`, as `fso-oracle` reports them on standard error. With `dump`, each digest
    /// is followed by every entity's digested fields, as `fso-oracle --dump` prints them.
    public func lotRun(_ lot: Blueprint, ticks: Int, every: Int, seed: UInt64 = Answers.defaultSeed, dump: Bool = false,
                       leftOut: (VM.LeftOut) -> Void = { _ in }) -> [String] {
        let vm: VM
        do {
            let loaded = try loadedLot(lot, seed: seed)
            vm = loaded.0
            loaded.1.forEach(leftOut)
        } catch SimAnticsError.unsupported(let reason) {
            return ["unsupported at tick 0: \(reason)"]
        } catch {
            return ["error \(error)"]
        }
        func gap() -> String? {
            for report in vm.reportedErrors { if case .unsupported(let reason) = report.error { return reason } }
            return nil
        }
        if let reason = gap() { return ["unsupported at tick 0: \(reason)"] }
        var lines = Self.digestLines(of: vm, tick: 0, dump: dump)
        if ticks > 0 {
            for tick in 1...ticks {
                vm.tick()
                if let reason = gap() {
                    lines.append("unsupported at tick \(tick): \(reason)")
                    break
                }
                if (every > 0 && tick % every == 0) || tick == ticks { lines += Self.digestLines(of: vm, tick: tick, dump: dump) }
            }
        }
        return lines
    }

    // MARK: room-maps

    /// A blueprint's room maps and rooms as `fso-oracle room-maps` prints them: one JSON object
    /// with `file`, `size`, `maps`, and `rooms`, or `file` and `error`.
    public static func roomMaps(of blueprint: URL) -> [String: Any] {
        var output: [String: Any] = ["file": blueprint.lastPathComponent]
        do {
            let architecture = try Blueprint(xml: try Data(contentsOf: blueprint)).architecture()
            output["size"] = [architecture.width, architecture.height]
            output["maps"] = architecture.roomMaps.map { $0.map.map(Int.init) }
            output["rooms"] = architecture.rooms.dropFirst().map { room -> [Any] in
                [Int(room.id), Int(room.lightBaseRoom), Int(room.level) - 1, room.isOutside, Int(room.area), room.isPool,
                 room.adjacentRooms.map(Int.init), [room.bounds.x, room.bounds.y, room.bounds.width, room.bounds.height],
                 room.supportRooms.map(Int.init)]
            }
        } catch {
            output["error"] = "\(Self.kind(of: error))"
        }
        return output
    }

    /// An error's case name, such as `missingFile`.
    static func kind(of error: any Error) -> String {
        let text = "\(error)"
        return String(text.prefix { $0 != "(" })
    }
}
