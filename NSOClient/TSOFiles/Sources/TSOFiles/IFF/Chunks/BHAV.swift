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
