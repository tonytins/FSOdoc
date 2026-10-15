import Foundation

/// The order of bytes in a multi-byte integer.
public enum ByteOrder: Sendable {
    case littleEndian
    case bigEndian
}

/// An error from reading past the end of the data.
public struct EndOfDataError: Error, Equatable, Sendable {
    /// The offset where the read started.
    public var offset: Int
    /// The number of bytes the read needed.
    public var needed: Int
    /// The number of bytes that were left.
    public var available: Int
}

/// Reads integers, bytes, and strings from a byte buffer.
///
/// Every read checks the remaining length first and throws ``EndOfDataError``
/// instead of reading out of bounds, so a truncated or corrupt file is an error
/// the caller can handle.
public struct ByteReader: Sendable {
    /// The byte order used by the integer reads.
    public var byteOrder: ByteOrder

    private let bytes: Data

    /// The current read position, counted from the start of the data.
    public private(set) var offset = 0

    /// Creates a reader over the given bytes.
    public init(_ bytes: Data, byteOrder: ByteOrder) {
        // Rebase slices so offsets always count from zero.
        self.bytes = bytes.startIndex == 0 ? bytes : Data(bytes)
        self.byteOrder = byteOrder
    }

    /// The total number of bytes.
    public var count: Int { bytes.count }

    /// The number of bytes left to read.
    public var remaining: Int { bytes.count - offset }

    // MARK: Position

    /// Moves the read position to an absolute offset.
    public mutating func seek(to newOffset: Int) throws(EndOfDataError) {
        guard newOffset >= 0, newOffset <= bytes.count else {
            throw EndOfDataError(offset: newOffset, needed: 0, available: max(0, bytes.count - max(0, newOffset)))
        }
        offset = newOffset
    }

    /// Moves the read position forward.
    public mutating func skip(_ byteCount: Int) throws(EndOfDataError) {
        try requireBytes(byteCount)
        offset += byteCount
    }

    // MARK: Integers

    public mutating func readUInt8() throws(EndOfDataError) -> UInt8 {
        try requireBytes(1)
        defer { offset += 1 }
        return bytes[offset]
    }

    public mutating func readUInt16() throws(EndOfDataError) -> UInt16 {
        UInt16(truncatingIfNeeded: try readUnsigned(byteCount: 2))
    }

    public mutating func readInt16() throws(EndOfDataError) -> Int16 {
        Int16(bitPattern: try readUInt16())
    }

    public mutating func readUInt32() throws(EndOfDataError) -> UInt32 {
        UInt32(truncatingIfNeeded: try readUnsigned(byteCount: 4))
    }

    public mutating func readInt32() throws(EndOfDataError) -> Int32 {
        Int32(bitPattern: try readUInt32())
    }

    /// Reads a 24-bit unsigned integer, as used by FAR3 and RefPack headers.
    public mutating func readUInt24() throws(EndOfDataError) -> UInt32 {
        UInt32(truncatingIfNeeded: try readUnsigned(byteCount: 3))
    }

    // MARK: Bytes and strings

    /// Reads exactly `byteCount` bytes.
    public mutating func readBytes(_ byteCount: Int) throws(EndOfDataError) -> Data {
        try requireBytes(byteCount)
        defer { offset += byteCount }
        return bytes.subdata(in: offset..<(offset + byteCount))
    }

    /// Reads up to `byteCount` bytes, returning fewer if the data ends first.
    ///
    /// This matches .NET's `BinaryReader.ReadBytes`, which some 2017 readers rely on.
    public mutating func readBytes(upTo byteCount: Int) -> Data {
        let length = max(0, min(byteCount, remaining))
        defer { offset += length }
        return bytes.subdata(in: offset..<(offset + length))
    }

    /// Reads a fixed-length ASCII string, keeping any NUL characters.
    ///
    /// Bytes above 0x7F become `?`, as .NET's ASCII decoder does.
    public mutating func readASCII(length: Int) throws(EndOfDataError) -> String {
        ASCII.decode(try readBytes(length))
    }

    // MARK: Private

    private func requireBytes(_ byteCount: Int) throws(EndOfDataError) {
        guard byteCount >= 0, byteCount <= remaining else {
            throw EndOfDataError(offset: offset, needed: byteCount, available: remaining)
        }
    }

    private mutating func readUnsigned(byteCount: Int) throws(EndOfDataError) -> UInt64 {
        try requireBytes(byteCount)
        defer { offset += byteCount }
        var value: UInt64 = 0
        for index in 0..<byteCount {
            let byte = UInt64(bytes[offset + index])
            switch byteOrder {
            case .littleEndian: value |= byte << (8 * index)
            case .bigEndian: value = (value << 8) | byte
            }
        }
        return value
    }
}
