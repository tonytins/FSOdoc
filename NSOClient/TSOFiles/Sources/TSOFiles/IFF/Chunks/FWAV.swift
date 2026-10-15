import Foundation

/// The name of a sound event an object plays, such as `piano_play`.
///
/// Ports FreeSO's `FWAV`. The name is a NUL-terminated Latin-1 string.
public struct FWAV: IFFChunk {
    public static let typeCode = "FWAV"

    public let id: UInt16
    public let label: String
    public let name: String

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        name = try record.parse(byteOrder: .littleEndian) { try $0.readNullTerminatedLatin1() }
    }
}
