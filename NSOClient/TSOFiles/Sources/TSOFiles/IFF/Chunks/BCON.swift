import Foundation

/// Behavior constants that SimAntics code reads by index.
///
/// Ports FreeSO's `BCON`. Labels for the constants live in a ``TRCN`` chunk
/// with the same ID.
public struct BCON: IFFChunk {
    public static let typeCode = "BCON"

    public let id: UInt16
    public let label: String
    public let flags: UInt8
    /// The constants, read as unsigned and reinterpreted by the VM where needed.
    public let constants: [UInt16]

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (flags, constants) = try record.parse(byteOrder: .littleEndian) { reader in
            let count = Int(try reader.readUInt8())
            let flags = try reader.readUInt8()
            var constants: [UInt16] = []
            for _ in 0..<count {
                constants.append(try reader.readUInt16())
            }
            return (flags, constants)
        }
    }
}
