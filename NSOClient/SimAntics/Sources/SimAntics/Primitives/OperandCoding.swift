// Operands are 8 bytes in a BHAV instruction, little-endian. Primitives decode them with
// ``OperandReader`` and encode them back with ``OperandWriter``.

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
