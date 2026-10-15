import Foundation

/// An object's event table: which BHAVs handle each object event.
///
/// Ports FreeSO's `OBJf`. The events are listed in `behavior.iff` chunk 0x00F5;
/// entry `n` here handles event `n`.
public struct OBJf: IFFChunk {
    public static let typeCode = "OBJf"

    /// The routines for one event. 0 means none.
    public struct Function: Sendable, Equatable {
        public var conditionFunction: UInt16
        public var actionFunction: UInt16
    }

    public let id: UInt16
    public let label: String
    public let version: UInt32
    public let functions: [Function]

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (version, functions) = try record.parse(byteOrder: .littleEndian) { reader in
            _ = try reader.readUInt32() // padding
            let version = try reader.readUInt32()
            _ = try reader.readASCII(length: 4) // magic
            let count = try reader.readUInt32()
            var functions: [Function] = []
            for _ in 0..<count {
                functions.append(Function(conditionFunction: try reader.readUInt16(),
                                          actionFunction: try reader.readUInt16()))
            }
            return (version, functions)
        }
    }
}
