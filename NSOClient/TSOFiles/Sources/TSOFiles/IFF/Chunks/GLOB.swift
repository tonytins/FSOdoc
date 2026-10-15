import Foundation

/// The name of the semi-global IFF an object uses for shared behavior.
///
/// Ports FreeSO's `GLOB`. The name is either a Pascal string or a C string:
/// a first byte below 48 (`0`, the lowest valid file name character) is
/// read as a length.
public struct GLOB: IFFChunk {
    public static let typeCode = "GLOB"

    public let id: UInt16
    public let label: String
    /// The semi-global file's name, without extension.
    public let name: String

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        name = try record.parse(byteOrder: .littleEndian) { reader in
            let first = try reader.readUInt8()
            if first < 48 {
                return try reader.readASCII(length: Int(first))
            }
            // A C string whose first byte was already read. It may end without a NUL.
            var scalars = String.UnicodeScalarView([Unicode.Scalar(first)])
            while reader.remaining > 0 {
                let byte = try reader.readUInt8()
                if byte == 0 { break }
                scalars.append(Unicode.Scalar(byte))
            }
            return String(scalars)
        }
    }
}
