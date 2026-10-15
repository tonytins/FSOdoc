import Foundation

/// Builds synthetic test files byte by byte, so tests never need EA's game files.
struct ByteWriter {
    var bytes = Data()
    var bigEndian = false

    var count: Int { bytes.count }

    mutating func uint8(_ value: UInt8) { bytes.append(value) }

    mutating func uint16(_ value: UInt16) { integer(UInt64(value), byteCount: 2) }

    mutating func uint24(_ value: UInt32) { integer(UInt64(value), byteCount: 3) }

    mutating func uint32(_ value: UInt32) { integer(UInt64(value), byteCount: 4) }

    mutating func int32(_ value: Int32) { uint32(UInt32(bitPattern: value)) }

    mutating func int16(_ value: Int16) { uint16(UInt16(bitPattern: value)) }

    mutating func ascii(_ text: String) { bytes.append(contentsOf: Array(text.utf8)) }

    /// Writes text padded with NUL bytes to a fixed length.
    mutating func ascii(_ text: String, paddedTo length: Int) {
        let utf8 = Array(text.utf8.prefix(length))
        bytes.append(contentsOf: utf8)
        bytes.append(contentsOf: repeatElement(UInt8(0), count: length - utf8.count))
    }

    mutating func raw(_ data: some Sequence<UInt8>) { bytes.append(contentsOf: data) }

    /// Overwrites a little-endian 32-bit value at an offset, for patching manifest offsets.
    mutating func patchUInt32(_ value: UInt32, at offset: Int) {
        for index in 0..<4 {
            bytes[offset + index] = UInt8(truncatingIfNeeded: value >> (8 * index))
        }
    }

    private mutating func integer(_ value: UInt64, byteCount: Int) {
        for index in 0..<byteCount {
            let shift = bigEndian ? 8 * (byteCount - 1 - index) : 8 * index
            bytes.append(UInt8(truncatingIfNeeded: value >> shift))
        }
    }
}
