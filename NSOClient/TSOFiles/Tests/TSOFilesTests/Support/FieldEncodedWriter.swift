import Foundation

/// Encodes values in the field-encoded layout, so tests can build field-encoded chunks.
///
/// Each value is written with the smallest width that holds it as a signed number,
/// which is one valid encoding; the reader accepts any width.
struct FieldEncodedWriter {
    private static let shortWidths = [5, 8, 13, 16]
    private static let longWidths = [6, 11, 21, 32]

    private var bits: [UInt8] = []

    mutating func short(_ value: Int64) { field(value, widths: Self.shortWidths) }
    mutating func long(_ value: Int64) { field(value, widths: Self.longWidths) }

    /// The packed bytes, padded with zero bits.
    var bytes: Data {
        var data = Data()
        var index = 0
        while index < bits.count {
            var byte: UInt8 = 0
            for bit in 0..<8 where index + bit < bits.count {
                byte |= bits[index + bit] << (7 - bit)
            }
            data.append(byte)
            index += 8
        }
        return data
    }

    private mutating func field(_ value: Int64, widths: [Int]) {
        guard value != 0 else { bits.append(0); return }
        bits.append(1)
        let code = widths.firstIndex { width in
            let limit = Int64(1) << (width - 1)
            return value >= -limit && value < limit
        } ?? widths.count - 1
        bits.append(UInt8(code >> 1 & 1))
        bits.append(UInt8(code & 1))
        let width = widths[code]
        let pattern = UInt64(bitPattern: value)
        for shift in stride(from: width - 1, through: 0, by: -1) {
            bits.append(UInt8(pattern >> UInt64(shift) & 1))
        }
    }
}
