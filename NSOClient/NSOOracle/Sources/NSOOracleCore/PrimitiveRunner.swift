import Foundation
import SimAntics
import TSOContent

/// `run-primitive` (protocol version 1, see `NSOClient/FSO.Oracle/README.md`): one primitive run on
/// request, on a freshly loaded lot, answered as `fso-oracle run-primitive` answers.
///
/// Ports the oracle's `PrimitiveRunner`. The lot loads as `fso-oracle` loads it (see
/// ``Answers/lotRun(_:ticks:every:seed:dump:leftOut:)``), the requested state is applied in
/// the same order, and the primitive runs on a one-instruction routine whose frame is pushed onto
/// the caller's thread, with the caller as the callee and code owner. The exit code is reported,
/// not acted on. The response holds the lot before running and only the primitive's effects.
///
/// Where NSOClient can't take the measurement, the response says so with `unsupported`, which `fso-oracle`
/// never writes: a primitive not ported yet, or a lot whose loading reached one.
public struct PrimitiveRunner {
    public static let protocolVersion = 1

    let answers: Answers
    let lot: Blueprint
    let defaultSeed: UInt64

    /// - Parameters:
    ///   - lot: the lot every request starts from, without the objects `fso-oracle` leaves out.
    ///   - defaultSeed: the random seed for loading, and for requests that don't give one.
    public init(answers: Answers, lot: Blueprint, defaultSeed: UInt64 = Answers.defaultSeed) {
        self.answers = answers
        self.lot = lot
        self.defaultSeed = defaultSeed
    }

    /// The response to one request line, as one line of JSON. Blank lines and lines starting
    /// with `#` have none.
    public func answerLine(_ line: String) -> String? {
        let text = line.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !text.hasPrefix("#") else { return nil }
        let response = answer(text)
        guard let data = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]) else {
            return #"{"protocol":1,"requestError":"the response doesn't encode as JSON"}"#
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// The response to one request. Never throws: problems are reported in the response.
    public func answer(_ line: String) -> [String: Any] {
        var id: JSONValue?
        let request: Request
        do {
            guard case .object(let fields, let keys) = try JSONValue.parse(line) else {
                throw RequestError("a request must be a JSON object")
            }
            id = fields["id"]
            request = try Request(fields, keys: keys, defaultSeed: defaultSeed)
        } catch let error as RequestError {
            return Self.response(id, "requestError", error.message)
        } catch {
            return Self.response(id, "requestError", "the request isn't JSON: \(error)")
        }

        let vm: VM
        do {
            (vm, _) = try answers.loadedLot(lot, seed: defaultSeed)
        } catch .unsupported(let reason) {
            return Self.response(id, "unsupported", "loading the lot reached \(reason)")
        } catch {
            return Self.response(id, "requestError", "the lot doesn't load: \(error)")
        }
        for report in vm.reportedErrors {
            if case .unsupported(let reason) = report.error {
                return Self.response(id, "unsupported", "loading the lot reached \(reason)")
            }
        }
        do {
            return try execute(request, on: vm, id: id)
        } catch let error as RequestError {
            return Self.response(id, "requestError", error.message)
        } catch {
            return Self.response(id, "requestError", "\(error)")
        }
    }

    // MARK: Running

    private func execute(_ request: Request, on vm: VM, id: JSONValue?) throws -> [String: Any] {
        let caller: Entity
        if let callerID = request.caller {
            guard let entity = vm.entity(id: callerID) else { throw RequestError("no object \(callerID) on the lot") }
            caller = entity
        } else {
            guard let lowest = vm.entities.min(by: { $0.objectID < $1.objectID }) else { throw RequestError("the lot has no objects") }
            caller = lowest
        }
        if request.stackObject != 0 && vm.entity(id: request.stackObject) == nil {
            throw RequestError("no object \(request.stackObject) on the lot")
        }

        // The requested state, then a snapshot, so the response holds only the primitive's effects.
        vm.random = VMRandom(seed: request.seed)
        if let clock = request.clock {
            vm.clock.hours = Int32(clock.hours)
            vm.clock.minutes = Int32(clock.minutes)
            vm.clock.minuteFractions = Int32(clock.minuteFractions)
        }
        for (index, value) in request.globals {
            guard index < vm.globalState.count else {
                throw RequestError("global \(index) is out of range (0 to \(vm.globalState.count - 1))")
            }
            vm.globalState[index] = value
        }
        for (objectID, state) in request.objects {
            guard let entity = vm.entity(id: objectID) else { throw RequestError("no object \(objectID) on the lot") }
            if let direction = state.direction { entity.direction = Direction(notch: direction) }  // exactly, unsnapped
            for (index, value) in state.data {
                guard index < entity.objectData.count else {
                    throw RequestError("object data \(index) is out of range for object \(objectID)")
                }
                entity.objectData[index] = value
            }
            for (index, value) in state.attributes { entity.setAttribute(value, at: UInt16(index)) }
            if let list = state.list { entity.list = list }
        }
        let thread = caller.thread
        if let tick = request.currentTick { vm.scheduler.currentTick = tick }
        if let start = request.idleStart { thread.idleStartTick = start }
        if let interrupt = request.interrupt { thread.isInterrupted = interrupt }
        thread.tempRegisters = (0..<thread.tempRegisters.count).map { $0 < request.temps.count ? request.temps[$0] : 0 }
        thread.tempXL = (0..<thread.tempXL.count).map { $0 < request.tempXL.count ? request.tempXL[$0] : 0 }

        let decoded = vm.primitives.decode(opcode: UInt16(request.opcode), operand: request.operand)
        let routine = Routine(id: 4096, name: "fso-oracle request", argumentCount: UInt16(request.args.count),
                              localCount: UInt16(request.locals.count), instructions: [
            Instruction(index: 0, opcode: UInt16(request.opcode), truePointer: 254, falsePointer: 255, operand: decoded),
        ])
        let frame = StackFrame(thread: thread, routine: routine, caller: caller, callee: caller, codeOwner: caller.object)
        frame.locals = request.locals
        frame.arguments = request.args
        frame.stackObjectID = request.stackObject
        thread.stack.append(frame)

        let before = Snapshot(vm)
        let threadBefore = (thread.idleStartTick, thread.isInterrupted, thread.scheduledTick)
        var response = Self.response(id, nil, nil)
        response["lot"] = vm.entities.sorted { $0.objectID < $1.objectID }.map { entity -> [Any] in
            let category = entity.objectData[Int(ObjectVariable.category.rawValue)]
            return [Int(entity.objectID), String(format: "%08x", entity.object.guid), Int(category),
                    vm.objects(inCategory: category)?.contains { $0 === entity } ?? false,
                    Int(entity.position.x), Int(entity.position.y), Int(entity.position.level), Int(entity.direction.rawValue),
                    entity.objectData.map(Int.init), entity.attributes.map(Int.init),
                    entity.footprint.map { [$0.x1, $0.y1, $0.x2, $0.y2] } ?? NSNull(),
                    (0..<entity.totalSlots).map { Int(entity.slot($0)?.objectID ?? 0) }]
        }
        response["lotSize"] = [vm.lotSize.width, vm.lotSize.height]
        response["groups"] = Self.groups(of: vm)

        switch decoded {
        case .primitive(let primitive):
            response["primitive"] = PrimitiveTable.fsoCompat[request.opcode] ?? primitive.name
            do {
                response["exit"] = try primitive.execute(in: frame).fsoCompatName
            } catch .unsupported(let reason) {
                return Self.response(id, "unsupported", reason)
            } catch {
                // FreeSO lets this reach VMThread.Tick, which resets the thread.
                response["exception"] = "\(error)"
            }
        case .unportedPrimitive(let name):
            return Self.response(id, "unsupported", "primitive \(request.opcode) (\(name))")
        case .missingPrimitive, .subroutine:
            // ExecuteInstruction treats an opcode with no primitive as GOTO_TRUE.
            response["exit"] = "GOTO_TRUE"
            response["noPrimitive"] = true
        }

        response["temps"] = thread.tempRegisters.map(Int.init)
        response["tempXL"] = thread.tempXL.map(Int.init)
        response["locals"] = frame.locals.map(Int.init)
        response["args"] = frame.arguments.map(Int.init)
        response["stackObject"] = Int(frame.stackObjectID)
        response["callerGUID"] = String(format: "%08x", caller.object.guid)
        if let requested = vm.entity(id: request.stackObject) {
            response["stackObjectGUID"] = String(format: "%08x", requested.object.guid)
        }
        response["seed"] = String(format: "%016llx", vm.random.seed)
        var threadChanges: [String: Any] = [:]
        if thread.idleStartTick != threadBefore.0 { threadChanges["idleStart"] = Int(thread.idleStartTick) }
        if thread.isInterrupted != threadBefore.1 { threadChanges["interrupt"] = thread.isInterrupted }
        if thread.scheduledTick != threadBefore.2 { threadChanges["scheduledTick"] = Int(thread.scheduledTick) }
        response["thread"] = threadChanges
        // More than 1: the primitive pushed frames.
        response["frames"] = thread.stack.count - (thread.stack.firstIndex { $0 === frame } ?? thread.stack.count)
        Snapshot(vm).describe(since: before, into: &response)
        return response
    }

    /// Objects that share a group with others, or came from a multi-tile master, by group:
    /// `[multiTile, masterGUID or null, objectIDs]`, ordered by each group's lowest object ID.
    private static func groups(of vm: VM) -> [[Any]] {
        var seen: [ObjectIdentifier] = [], groups: [MultitileGroup] = []
        for entity in vm.entities where !seen.contains(ObjectIdentifier(entity.group)) {
            seen.append(ObjectIdentifier(entity.group))
            if entity.group.isMultiTile || entity.group.objects.count > 1 { groups.append(entity.group) }
        }
        return groups
            .sorted { ($0.objects.map(\.objectID).min() ?? 0) < ($1.objects.map(\.objectID).min() ?? 0) }
            .map { group in
                let master = group.objects.lazy.compactMap(\.masterDefinition).first
                return [group.isMultiTile, master.map { String(format: "%08x", $0.guid) } ?? NSNull(),
                        group.objects.map { Int($0.objectID) }]
            }
    }

    private static func response(_ id: JSONValue?, _ key: String?, _ message: String?) -> [String: Any] {
        var response: [String: Any] = ["protocol": protocolVersion]
        if let id { response["id"] = id.foundationValue }
        if let key, let message { response[key] = message }
        return response
    }
}

// MARK: Requests

/// A request `run-primitive` can't run, reported instead of crashing.
struct RequestError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

/// A parsed and validated request, with `fso-oracle`'s rules and defaults.
struct Request {
    struct ObjectState {
        var data: [(Int, Int16)] = []
        var attributes: [(Int, Int16)] = []
        /// The whole list, front first, or `nil` to leave it.
        var list: [Int16]?
        /// The facing, 0 (north) to 7 clockwise, or `nil` to leave it.
        var direction: Int?
    }

    var opcode: UInt8
    var operand: [UInt8]
    var caller: Int16?
    var stackObject: Int16
    var seed: UInt64
    var temps: [Int16]
    var tempXL: [Int32]
    var locals: [Int16]
    var args: [Int16]
    var globals: [(Int, Int16)]
    var objects: [(Int16, ObjectState)]
    var clock: (hours: Int, minutes: Int, minuteFractions: Int)?
    var currentTick: UInt32?
    var idleStart: UInt32?
    var interrupt: Bool?

    private static let known: Set<String> = ["id", "opcode", "operand", "caller", "stackObject", "seed", "temps", "tempXL",
                                             "locals", "args", "globals", "objects", "clock", "currentTick", "idleStart", "interrupt"]

    init(_ json: [String: JSONValue], keys: [String], defaultSeed: UInt64) throws {
        if let unknown = keys.first(where: { !Self.known.contains($0) }) { throw RequestError("unknown field \"\(unknown)\"") }
        guard let opcode = json["opcode"] else { throw RequestError("\"opcode\" is required") }
        self.opcode = UInt8(try Self.integer(opcode, "opcode", 0, 255))
        operand = try Self.operandBytes(json["operand"])
        caller = try json["caller"].map { Int16(try Self.integer($0, "caller", 1, Int64(Int16.max))) }
        stackObject = try json["stackObject"].map { Int16(try Self.integer($0, "stackObject", Int64(Int16.min), Int64(Int16.max))) } ?? 0
        seed = try json["seed"].map { try Self.hex($0, "seed") } ?? defaultSeed
        temps = try Self.shorts(json["temps"], "temps", maximumCount: 20, defaultCount: 0)
        tempXL = try Self.ints(json["tempXL"], "tempXL", maximumCount: 2)
        locals = try Self.shorts(json["locals"], "locals", maximumCount: 255, defaultCount: 0)
        args = try Self.shorts(json["args"], "args", maximumCount: 255, defaultCount: 4)
        globals = try Self.sparse(json["globals"], "globals")
        objects = try Self.objectStates(json["objects"])
        clock = try Self.clockState(json["clock"])
        currentTick = try json["currentTick"].map { UInt32(try Self.integer($0, "currentTick", 0, Int64(UInt32.max))) }
        idleStart = try json["idleStart"].map { UInt32(try Self.integer($0, "idleStart", 0, Int64(UInt32.max))) }
        switch json["interrupt"] {
        case nil: interrupt = nil
        case .bool(let flag): interrupt = flag
        default: throw RequestError("\"interrupt\" must be true or false")
        }
    }

    private static func integer(_ value: JSONValue, _ name: String, _ minimum: Int64, _ maximum: Int64) throws -> Int64 {
        guard case .integer(let number) = value, number >= minimum, number <= maximum else {
            throw RequestError("\"\(name)\" must be an integer from \(minimum) to \(maximum)")
        }
        return number
    }

    private static func hex(_ value: JSONValue, _ name: String) throws -> UInt64 {
        guard case .string(let text) = value, let number = UInt64(text, radix: 16) else {
            throw RequestError("\"\(name)\" must be a hexadecimal string")
        }
        return number
    }

    /// Hex bytes, as stored in the BHAV; shorter operands are padded with zeros to 8.
    private static func operandBytes(_ value: JSONValue?) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 8)
        guard let value else { return bytes }
        guard case .string(let text) = value, text.count.isMultiple(of: 2), text.count <= 16 else {
            throw RequestError("\"operand\" must be a hexadecimal string of up to 8 bytes")
        }
        var index = text.startIndex, offset = 0
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            guard let byte = UInt8(text[index..<next], radix: 16) else {
                throw RequestError("\"operand\" must be a hexadecimal string of up to 8 bytes")
            }
            bytes[offset] = byte
            offset += 1
            index = next
        }
        return bytes
    }

    private static func array(_ value: JSONValue, _ name: String, maximumCount: Int) throws -> [JSONValue] {
        guard case .array(let items) = value, items.count <= maximumCount else {
            throw RequestError("\"\(name)\" must be an array of at most \(maximumCount) values")
        }
        return items
    }

    private static func shorts(_ value: JSONValue?, _ name: String, maximumCount: Int, defaultCount: Int) throws -> [Int16] {
        guard let value else { return [Int16](repeating: 0, count: defaultCount) }
        return try array(value, name, maximumCount: maximumCount).map { Int16(try integer($0, name, Int64(Int16.min), Int64(Int16.max))) }
    }

    private static func ints(_ value: JSONValue?, _ name: String, maximumCount: Int) throws -> [Int32] {
        guard let value else { return [] }
        return try array(value, name, maximumCount: maximumCount).map { Int32(try integer($0, name, Int64(Int32.min), Int64(Int32.max))) }
    }

    /// An object of index to value, such as `{"3": 10}`, in the request's order.
    private static func sparse(_ value: JSONValue?, _ name: String) throws -> [(Int, Int16)] {
        guard let value else { return [] }
        guard case .object(let fields, let keys) = value else { throw RequestError("\"\(name)\" must be an object of index to value") }
        return try keys.map { key in
            guard key.allSatisfy(\.isASCII), key.allSatisfy(\.isNumber), let index = Int(key), index <= 0xFFFF, let field = fields[key] else {
                throw RequestError("\"\(name)\" key \"\(key)\" is not an index")
            }
            return (index, Int16(try integer(field, name, Int64(Int16.min), Int64(Int16.max))))
        }
    }

    private static func objectStates(_ value: JSONValue?) throws -> [(Int16, ObjectState)] {
        guard let value else { return [] }
        guard case .object(let fields, let keys) = value else { throw RequestError("\"objects\" must be an object of object ID to state") }
        return try keys.map { key in
            guard key.allSatisfy(\.isASCII), key.allSatisfy(\.isNumber), let objectID = Int16(key), objectID != 0 else {
                throw RequestError("\"objects\" key \"\(key)\" is not an object ID")
            }
            guard case .object(let state, let stateKeys) = fields[key],
                  stateKeys.allSatisfy({ ["data", "attributes", "list", "direction"].contains($0) }) else {
                throw RequestError("object \(key) state must be an object with \"data\", \"attributes\", and \"list\"")
            }
            var result = ObjectState()
            result.data = try sparse(state["data"], "data")
            result.attributes = try sparse(state["attributes"], "attributes")
            result.list = try state["list"].map { try shorts($0, "list", maximumCount: Int(Int16.max), defaultCount: 0) }
            result.direction = try state["direction"].map { Int(try integer($0, "direction", 0, 7)) }
            return (objectID, result)
        }
    }

    /// `{"hours": h, "minutes": m, "minuteFractions": f}`, each required.
    private static func clockState(_ value: JSONValue?) throws -> (hours: Int, minutes: Int, minuteFractions: Int)? {
        guard let value else { return nil }
        guard case .object(let clock, _) = value, clock.count == 3 else {
            throw RequestError("\"clock\" must be an object with \"hours\", \"minutes\", and \"minuteFractions\"")
        }
        func part(_ name: String, _ maximum: Int64) throws -> Int {
            guard let field = clock[name] else { throw RequestError("\"clock\" needs \"\(name)\"") }
            return Int(try integer(field, name, 0, maximum))
        }
        return (try part("hours", 23), try part("minutes", 59), try part("minuteFractions", 149))
    }
}

// MARK: Snapshots

/// The state a primitive can change outside its frame, as `fso-oracle` snapshots it.
struct Snapshot {
    struct EntityState {
        var data: [Int16], attributes: [Int16], list: [Int16], direction: Direction, position: LotPosition
    }

    let globals: [Int16]
    let entities: [Int16: EntityState]

    init(_ vm: VM) {
        globals = vm.globalState
        var entities: [Int16: EntityState] = [:]
        for entity in vm.entities {
            entities[entity.objectID] = EntityState(data: entity.objectData, attributes: entity.attributes, list: entity.list,
                                                    direction: entity.direction, position: entity.position)
        }
        self.entities = entities
    }

    /// Adds what changed since `before`: globals, each object's changed values, and the objects
    /// created and removed.
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
            if old.position != state.position {
                changes["position"] = [Int(state.position.x), Int(state.position.y), Int(state.position.level)]
            }
            if old.direction != state.direction { changes["direction"] = Int(state.direction.rawValue) }
            if !changes.isEmpty { objects[String(id)] = changes }
        }
        fields["objects"] = objects
        fields["created"] = entities.keys.filter { before.entities[$0] == nil }.sorted().map(Int.init)
        fields["removed"] = before.entities.keys.filter { entities[$0] == nil }.sorted().map(Int.init)
    }

    /// Indexes whose value changed; a list that grew reports its new entries, one that shrank reports 0.
    private static func changes(_ before: [Int16], _ after: [Int16]) -> [String: Int] {
        var changes: [String: Int] = [:]
        for index in 0..<max(before.count, after.count) {
            let old = index < before.count ? before[index] : 0, new = index < after.count ? after[index] : 0
            if old != new { changes[String(index)] = Int(new) }
        }
        return changes
    }
}
