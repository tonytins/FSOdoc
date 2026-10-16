import Foundation

/// SimAntics behavior code: a routine of instructions.
///
/// Ports FreeSO's `BHAV`. Four header versions exist (0x8000 to 0x8003). Like
/// the 2017 reader, any other version yields a routine with no instructions.
public struct BHAV: IFFChunk {
    public static let typeCode = "BHAV"

    /// One SimAntics instruction.
    public struct Instruction: Sendable, Equatable {
        /// Below 256, a primitive; 256 and up, a call to another routine.
        public var opcode: UInt16
        /// The instruction index to go to on a true result, or a special exit value.
        public var truePointer: UInt8
        /// The instruction index to go to on a false result, or a special exit value.
        public var falsePointer: UInt8
        /// The primitive's 8-byte operand, decoded by the VM.
        public var operand: Data

        public init(opcode: UInt16, truePointer: UInt8, falsePointer: UInt8, operand: Data) {
            self.opcode = opcode
            self.truePointer = truePointer
            self.falsePointer = falsePointer
            self.operand = operand
        }
    }

    public let id: UInt16
    public let label: String
    /// The header version, 0x8000 to 0x8003 for known layouts.
    public let version: UInt16
    /// The routine type. Only versions 0x8002 and 0x8003 store it.
    public let type: UInt8
    /// The number of arguments. Only versions 0x8002 and 0x8003 store it.
    public let argumentCount: UInt8
    /// The number of local variables. Only versions 0x8002 and 0x8003 store it.
    public let localCount: UInt16
    /// Routine flags. Only versions 0x8002 and 0x8003 store them.
    public let flags: UInt16
    /// The instructions, in order.
    public let instructions: [Instruction]

    /// A routine built in code, for tools that write behavior.
    public init(id: UInt16, label: String, version: UInt16 = 0x8002, type: UInt8 = 0, argumentCount: UInt8 = 4,
                localCount: UInt16 = 0, flags: UInt16 = 0, instructions: [Instruction]) {
        self.id = id
        self.label = label
        self.version = version
        self.type = type
        self.argumentCount = argumentCount
        self.localCount = localCount
        self.flags = flags
        self.instructions = instructions
    }

    /// The chunk data, in the layout of ``version``, for writing an IFF.
    ///
    /// Reading the result gives back an equal routine. Bytes the reader skips are written as
    /// zeros, so a routine read from a file may not encode to that file's exact bytes. Version
    /// 0x8003 stores the local count in one byte; an unknown version writes only the version,
    /// which reads back as an empty routine, as 2017 does.
    public func encoded() -> Data {
        var bytes = Data()
        func append<Value: FixedWidthInteger>(_ value: Value) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        append(version)
        switch version {
        case 0x8000, 0x8001:
            append(UInt16(truncatingIfNeeded: instructions.count))
            bytes.append(contentsOf: [UInt8](repeating: 0, count: 8))
        case 0x8002:
            append(UInt16(truncatingIfNeeded: instructions.count))
            append(type)
            append(argumentCount)
            append(localCount)
            append(flags)
            bytes.append(contentsOf: [0, 0])
        case 0x8003:
            append(type)
            append(argumentCount)
            append(UInt8(truncatingIfNeeded: localCount))
            bytes.append(contentsOf: [0, 0])
            append(flags)
            append(UInt32(instructions.count))
        default:
            return bytes
        }
        for instruction in instructions {
            append(instruction.opcode)
            append(instruction.truePointer)
            append(instruction.falsePointer)
            let operand = [UInt8](instruction.operand.prefix(8))
            bytes.append(contentsOf: operand + [UInt8](repeating: 0, count: 8 - operand.count))
        }
        return bytes
    }

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (version, type, argumentCount, localCount, flags, instructions) = try record.parse(byteOrder: .littleEndian) { reader in
            let version = try reader.readUInt16()
            var count = 0
            var type: UInt8 = 0
            var argumentCount: UInt8 = 0
            var localCount: UInt16 = 0
            var flags: UInt16 = 0

            switch version {
            case 0x8000, 0x8001:
                count = Int(try reader.readUInt16())
                try reader.skip(8)
            case 0x8002:
                count = Int(try reader.readUInt16())
                type = try reader.readUInt8()
                argumentCount = try reader.readUInt8()
                localCount = try reader.readUInt16()
                flags = try reader.readUInt16()
                try reader.skip(2)
            case 0x8003:
                type = try reader.readUInt8()
                argumentCount = try reader.readUInt8()
                localCount = UInt16(try reader.readUInt8())
                try reader.skip(2)
                flags = try reader.readUInt16()
                count = Int(try reader.readUInt32())
            default:
                break // the 2017 reader leaves the routine empty
            }

            var instructions: [Instruction] = []
            for _ in 0..<count {
                instructions.append(Instruction(
                    opcode: try reader.readUInt16(),
                    truePointer: try reader.readUInt8(),
                    falsePointer: try reader.readUInt8(),
                    operand: try reader.readBytes(8)))
            }
            return (version, type, argumentCount, localCount, flags, instructions)
        }
    }
}
