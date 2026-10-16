import Foundation

/// Reads "field-encoded" values: variable-width, sign-extended integers packed
/// bit by bit, used by TSO's `TTAB` versions 9 and 10 and some TS1 chunks.
///
/// Ports the numeric part of FreeSO's `IffFieldEncode`. Each field starts with
/// one bit: 0 means the value is zero. Otherwise two bits pick a width (5, 8,
/// 13, or 16 bits for 16-bit fields; 6, 11, 21, or 32 for 32-bit fields), and
/// that many bits follow, most significant first, then are sign-extended.
/// Bits past the end of the data read as zero, as in FreeSO.
struct FieldEncodedReader {
    private static let shortWidths: [Int] = [5, 8, 13, 16]
    private static let longWidths: [Int] = [6, 11, 21, 32]

    private var reader: ByteReader
    private var currentByte: UInt8
    private var bitPosition = 0

    /// Starts reading at the reader's position. Like FreeSO, this fails if no byte is left.
    init(_ reader: ByteReader) throws(EndOfDataError) {
        self.reader = reader
        currentByte = try self.reader.readUInt8()
    }

    /// An upper bound on the bits left before reads start returning padding zeros.
    var bitsRemaining: Int { (8 - bitPosition) + reader.remaining * 8 }

    mutating func readUInt16() -> UInt16 { UInt16(truncatingIfNeeded: readField(isLong: false)) }
    mutating func readInt16() -> Int16 { Int16(truncatingIfNeeded: readField(isLong: false)) }
    mutating func readUInt32() -> UInt32 { UInt32(truncatingIfNeeded: readField(isLong: true)) }
    mutating func readInt32() -> Int32 { Int32(truncatingIfNeeded: readField(isLong: true)) }

    /// Reads a 32-bit field and converts the integer to a float.
    ///
    /// This isn't a bit-pattern reinterpretation. FreeSO's code converts the
    /// integer value (its comment says "this is incredibly wrong"), and the VM
    /// depends on the result, so it's kept.
    mutating func readFloat() -> Float { Float(readField(isLong: true)) }

    private mutating func readField(isLong: Bool) -> Int64 {
        guard readBit() == 1 else { return 0 }
        let code = Int(readBits(2))
        let width = isLong ? Self.longWidths[code] : Self.shortWidths[code]
        var value = Int64(readBits(width))
        let signBit = Int64(1) << (width - 1)
        if value & signBit != 0 { value |= -signBit }
        return value
    }

    private mutating func readBits(_ count: Int) -> UInt32 {
        var total: UInt32 = 0
        for _ in 0..<count {
            total = (total << 1) | UInt32(readBit())
        }
        return total
    }

    private mutating func readBit() -> UInt8 {
        let bit = (currentByte >> (7 - bitPosition)) & 1
        bitPosition += 1
        if bitPosition > 7 {
            bitPosition = 0
            currentByte = (try? reader.readUInt8()) ?? 0 // past the end reads zero, as in FreeSO
        }
        return bit
    }
}
