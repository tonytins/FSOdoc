import Foundation

/// Names for a ``BHAV``'s parameters and local variables, with the same ID.
///
/// Ports FreeSO's `TPRP`. Version 5 stores names with a one-byte length;
/// other versions store them NUL-terminated. Trailing flags aren't read,
/// as in FreeSO.
public struct TPRP: IFFChunk {
    public static let typeCode = "TPRP"

    public let id: UInt16
    public let label: String
    public let version: Int32
    public let parameterNames: [String]
    public let localNames: [String]

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (version, parameterNames, localNames) = try record.parse(byteOrder: .littleEndian) { reader in
            _ = try reader.readInt32() // always zero
            let version = try reader.readInt32()
            _ = try reader.readASCII(length: 4) // "PRPT", or four NULs
            let parameterCount = try reader.readCount32()
            let localCount = try reader.readCount32()

            func readName() throws -> String {
                version == 5 ? try reader.readPascalString() : try reader.readNullTerminatedLatin1()
            }
            var parameterNames: [String] = []
            for _ in 0..<parameterCount { parameterNames.append(try readName()) }
            var localNames: [String] = []
            for _ in 0..<localCount { localNames.append(try readName()) }
            return (version, parameterNames, localNames)
        }
    }
}
