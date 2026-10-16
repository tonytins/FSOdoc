import Foundation
import TSOFiles

/// A BHAV prepared to run: every operand decoded once.
///
/// Ports FreeSO's `VMRoutine` and `VMTranslator.Assemble`.
public struct Routine: Sendable {
    public let id: UInt16
    public let name: String
    public let type: UInt8
    public let argumentCount: UInt16
    public let localCount: UInt16
    public let instructions: [Instruction]

    /// Decodes a BHAV's instructions with the primitives in `table`.
    public init(_ bhav: BHAV, primitives table: PrimitiveTable) {
        id = bhav.id
        name = bhav.label
        type = bhav.type
        argumentCount = UInt16(bhav.argumentCount)
        localCount = bhav.localCount
        instructions = bhav.instructions.enumerated().map { index, instruction in
            Instruction(index: UInt8(truncatingIfNeeded: index), opcode: instruction.opcode,
                        truePointer: instruction.truePointer, falsePointer: instruction.falsePointer,
                        operand: table.decode(opcode: instruction.opcode, operand: [UInt8](instruction.operand)))
        }
    }

    /// A routine built directly, for tests and tools.
    public init(id: UInt16, name: String = "", type: UInt8 = 0, argumentCount: UInt16 = 4, localCount: UInt16 = 0,
                instructions: [Instruction]) {
        self.id = id
        self.name = name
        self.type = type
        self.argumentCount = argumentCount
        self.localCount = localCount
        self.instructions = instructions
    }
}

/// One decoded instruction.
public struct Instruction: Sendable {
    public let index: UInt8
    public let opcode: UInt16
    public let truePointer: UInt8
    public let falsePointer: UInt8
    public let operand: DecodedOperand

    public init(index: UInt8, opcode: UInt16, truePointer: UInt8, falsePointer: UInt8, operand: DecodedOperand) {
        self.index = index
        self.opcode = opcode
        self.truePointer = truePointer
        self.falsePointer = falsePointer
        self.operand = operand
    }
}

/// An instruction's operand, decoded for what the opcode does.
public enum DecodedOperand: Sendable {
    /// A call to another routine (opcodes 256 and up).
    case subroutine(SubroutineOperand)
    /// A primitive, ready to run.
    case primitive(PrimitiveTable.Prepared)
    /// A primitive opcode with no implementation in 2017; it takes the true branch.
    case missingPrimitive
    /// A primitive 2017 has that this port doesn't yet; running it throws ``SimAnticsError/unsupported(_:)``.
    case unportedPrimitive(String)
}

/// The arguments of a subroutine call.
///
/// Ports `VMSubRoutineOperand`: four little-endian 16-bit arguments. When any of
/// arguments 1 to 3 is non-zero, an argument of -1 takes the temp register with its index.
public struct SubroutineOperand: Sendable, Equatable {
    public var arguments: [Int16]
    public var usesTemps: Bool

    public init(bytes: [UInt8]) {
        var reader = OperandReader(bytes)
        arguments = (0..<4).map { _ in reader.int16() }
        usesTemps = !(arguments[1] == 0 && arguments[2] == 0 && arguments[3] == 0)
    }

    /// A call with up to four arguments; ``usesTemps`` follows from them, as when decoding.
    public init(arguments: [Int16]) {
        self.init(bytes: OperandWriter.bytes { writer in
            for argument in (arguments + [0, 0, 0, 0]).prefix(4) { writer.int16(argument) }
        })
    }

    public func encoded() -> [UInt8] {
        OperandWriter.bytes { writer in
            for argument in arguments { writer.int16(argument) }
        }
    }
}

/// Writes an 8-byte operand in little-endian order, padded with zeros.
public struct OperandWriter {
    private(set) var bytes: [UInt8] = []

    public static func bytes(_ write: (inout OperandWriter) -> Void) -> [UInt8] {
        var writer = OperandWriter()
        write(&writer)
        return Array((writer.bytes + [UInt8](repeating: 0, count: 8)).prefix(8))
    }

    public mutating func uint8(_ value: UInt8) { bytes.append(value) }

    public mutating func uint16(_ value: UInt16) {
        bytes.append(UInt8(truncatingIfNeeded: value))
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    public mutating func int16(_ value: Int16) { uint16(UInt16(bitPattern: value)) }

    public mutating func uint32(_ value: UInt32) {
        uint16(UInt16(truncatingIfNeeded: value))
        uint16(UInt16(truncatingIfNeeded: value >> 16))
    }
}

/// Reads an 8-byte operand in little-endian order. Reads past the end give zeros.
public struct OperandReader {
    private let bytes: [UInt8]
    private var position = 0

    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    public mutating func uint8() -> UInt8 {
        defer { position += 1 }
        return position < bytes.count ? bytes[position] : 0
    }

    public mutating func uint16() -> UInt16 {
        UInt16(uint8()) | UInt16(uint8()) << 8
    }

    public mutating func int16() -> Int16 {
        Int16(bitPattern: uint16())
    }

    public mutating func uint32() -> UInt32 {
        UInt32(uint16()) | UInt32(uint16()) << 16
    }
}
