/// The primitives, one type each, named after their 2017 classes without the `VM` prefix.
public enum Primitives {}

/// A SimAntics primitive: an operation with an opcode below 256.
///
/// Primitives hold no state; everything they change lives in the VM.
public protocol Primitive: SendableMetatype {
    associatedtype Operand: PrimitiveOperand
    /// The 2017 registration name, such as `expression`.
    static var name: String { get }
    static var opcode: UInt8 { get }
    static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode
}

/// A primitive's operand, decoded from the BHAV's 8 bytes.
public protocol PrimitiveOperand: Sendable {
    init(bytes: [UInt8])
}

/// The primitives a VM runs, by opcode.
///
/// Ports the registrations in the `VMContext` constructor.
public struct PrimitiveTable: Sendable {
    /// A primitive with its operand decoded, ready to run on a frame.
    public struct Prepared: Sendable {
        public let name: String
        public let operand: any PrimitiveOperand
        let run: @Sendable (StackFrame) throws(SimAnticsError) -> ExitCode

        public func execute(in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
            try run(frame)
        }
    }

    private struct Registration: Sendable {
        let name: String
        let prepare: @Sendable ([UInt8]) -> Prepared
    }

    private var registrations: [UInt8: Registration] = [:]

    /// The primitives this port supports.
    public static let standard: PrimitiveTable = {
        var table = PrimitiveTable()
        table.register(Primitives.Expression.self)
        return table
    }()

    public init() {}

    public mutating func register<P: Primitive>(_ primitive: P.Type) {
        registrations[P.opcode] = Registration(name: P.name) { bytes in
            let operand = P.Operand(bytes: bytes)
            return Prepared(name: P.name, operand: operand) { frame throws(SimAnticsError) in
                try P.execute(operand, in: frame)
            }
        }
    }

    /// The primitives 2017 registers in TSO mode, by opcode, with their registration names.
    public static let tso2017Names: [UInt8: String] = [
        0: "sleep", 1: "generic_sims_online_call", 2: "expression", 4: "grab", 5: "drop",
        6: "change_suit_or_accessory", 7: "refresh", 8: "random_number", 9: "burn", 11: "get_distance_to",
        12: "get_direction_to", 13: "push_interaction", 14: "find_best_object_for_function", 15: "breakpoint",
        16: "find_location_for", 17: "idle_for_input", 18: "remove_object_instance", 20: "run_functional_tree",
        22: "look_towards", 23: "play_sound", 24: "old_relationship", 25: "transfer_funds", 26: "relationship",
        27: "goto_relative", 28: "run_tree_by_name", 29: "set_motive_deltas", 30: "syslog", 31: "set_to_next",
        32: "test_object_type", 35: "special_effect", 36: "dialog_private", 37: "test_sim_interacting_with",
        38: "dialog_global", 39: "dialog_semiglobal", 40: "online_jobs_call", 41: "set_balloon_headline",
        42: "create_object_instance", 43: "drop_onto", 44: "animate", 45: "goto_routing_slot", 46: "snap",
        47: "reach", 48: "stop_all_sounds", 49: "stackobj_notify_out_of_idle", 50: "change_action_string",
        62: "invoke_plugin", 63: "get_terrain_info", 65: "find_best_action", 67: "inventory_operations",
    ]

    /// The name of the primitive with an opcode, or `nil` if there is none.
    public func name(of opcode: UInt8) -> String? {
        registrations[opcode]?.name
    }

    /// Decodes an instruction's operand for its opcode.
    public func decode(opcode: UInt16, operand bytes: [UInt8]) -> DecodedOperand {
        if opcode >= 256 { return .subroutine(SubroutineOperand(bytes: bytes)) }
        guard let registration = registrations[UInt8(opcode)] else {
            if let name = Self.tso2017Names[UInt8(opcode)] { return .unportedPrimitive(name) }
            return .missingPrimitive
        }
        return .primitive(registration.prepare(bytes))
    }
}
