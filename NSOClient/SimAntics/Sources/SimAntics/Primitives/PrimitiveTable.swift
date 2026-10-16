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

    /// The name of the primitive with an opcode, or `nil` if there is none.
    public func name(of opcode: UInt8) -> String? {
        registrations[opcode]?.name
    }

    /// Decodes an instruction's operand for its opcode.
    public func decode(opcode: UInt16, operand bytes: [UInt8]) -> DecodedOperand {
        if opcode >= 256 { return .subroutine(SubroutineOperand(bytes: bytes)) }
        guard let registration = registrations[UInt8(opcode)] else { return .missingPrimitive }
        return .primitive(registration.prepare(bytes))
    }
}
