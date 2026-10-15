import Foundation

/// Decompresses RefPack (QFS) data, the compression FAR3 archives use.
///
/// This follows FreeSO's `Decompresser.Decompress`, which was ported from
/// DBPF4J. The format is described at http://wiki.niotso.org/RefPack.
/// Behavior on valid data matches the 2017 code, including these quirks:
///
/// - Input of 6 bytes or fewer is returned unchanged.
/// - Output grows past `decompressedSize` if the stream writes more.
/// - Control bytes 0xFD to 0xFF copy their literal bytes and keep going;
///   only 0xFC ends the stream.
///
/// Where the 2017 code would index out of bounds, this throws
/// ``RefPackError`` instead.
public enum RefPack {
    /// Decompresses a RefPack stream that starts after its 5-byte header.
    ///
    /// - Parameters:
    ///   - compressed: The compressed bytes.
    ///   - decompressedSize: The expected size, from the header.
    /// - Returns: The decompressed bytes.
    public static func decompress(_ compressed: Data, decompressedSize: Int) throws(RefPackError) -> Data {
        let input = [UInt8](compressed)
        guard input.count > 6 else { return compressed }

        var output = [UInt8](repeating: 0, count: max(0, decompressedSize))
        var outputPosition = 0
        var inputPosition = 0
        var control1 = 0

        while control1 != 0xFC && inputPosition < input.count {
            control1 = Int(input[inputPosition])
            inputPosition += 1
            if inputPosition == input.count { break }

            let plainCount: Int
            var copyOffset = 0
            var copyCount = 0

            switch control1 {
            case 0x00...0x7F:
                let control2 = try byte(input, at: &inputPosition)
                plainCount = control1 & 0x03
                copyOffset = ((control1 & 0x60) << 3) + control2 + 1
                copyCount = ((control1 & 0x1C) >> 2) + 3

            case 0x80...0xBF:
                let control2 = try byte(input, at: &inputPosition)
                let control3 = try byte(input, at: &inputPosition)
                plainCount = (control2 >> 6) & 0x03
                copyOffset = ((control2 & 0x3F) << 8) + control3 + 1
                copyCount = (control1 & 0x3F) + 4

            case 0xC0...0xDF:
                plainCount = control1 & 0x03
                let control2 = try byte(input, at: &inputPosition)
                let control3 = try byte(input, at: &inputPosition)
                let control4 = try byte(input, at: &inputPosition)
                copyOffset = ((control1 & 0x10) << 12) + (control2 << 8) + control3 + 1
                copyCount = ((control1 & 0x0C) << 6) + control4 + 5

            case 0xE0...0xFB:
                plainCount = ((control1 & 0x1F) << 2) + 4

            default: // 0xFC to 0xFF
                plainCount = control1 & 0x03
            }

            try copyPlain(from: input, at: &inputPosition, count: plainCount, into: &output, at: &outputPosition)
            if outputPosition == output.count { break }

            guard copyCount > 0 else { continue }
            try copyBack(in: &output, offset: copyOffset, count: copyCount, at: &outputPosition)
            if outputPosition == output.count { break }
        }

        return Data(output)
    }

    // MARK: Private

    private static func byte(_ input: [UInt8], at position: inout Int) throws(RefPackError) -> Int {
        guard position < input.count else { throw .truncatedInput(offset: position) }
        defer { position += 1 }
        return Int(input[position])
    }

    /// Copies literal bytes from the input, growing the output if needed.
    private static func copyPlain(
        from input: [UInt8], at inputPosition: inout Int, count: Int,
        into output: inout [UInt8], at outputPosition: inout Int
    ) throws(RefPackError) {
        guard count > 0 else { return }
        guard inputPosition + count <= input.count else { throw .truncatedInput(offset: inputPosition) }
        growIfNeeded(&output, toFit: outputPosition + count)
        output.replaceSubrange(outputPosition..<(outputPosition + count),
                               with: input[inputPosition..<(inputPosition + count)])
        inputPosition += count
        outputPosition += count
    }

    /// Copies earlier output forward. Overlapping copies repeat a pattern, so this copies byte by byte.
    private static func copyBack(
        in output: inout [UInt8], offset: Int, count: Int, at outputPosition: inout Int
    ) throws(RefPackError) {
        let source = outputPosition - offset
        guard source >= 0 else { throw .invalidBackReference(offset: offset, outputPosition: outputPosition) }
        growIfNeeded(&output, toFit: outputPosition + count)
        for index in 0..<count {
            output[outputPosition + index] = output[source + index]
        }
        outputPosition += count
    }

    private static func growIfNeeded(_ output: inout [UInt8], toFit length: Int) {
        if output.count < length {
            output.append(contentsOf: repeatElement(0, count: length - output.count))
        }
    }
}

/// An error from decompressing RefPack data.
public enum RefPackError: Error, Equatable, Sendable {
    /// The stream ended in the middle of a command.
    case truncatedInput(offset: Int)
    /// A copy command pointed before the start of the output.
    case invalidBackReference(offset: Int, outputPosition: Int)
}
