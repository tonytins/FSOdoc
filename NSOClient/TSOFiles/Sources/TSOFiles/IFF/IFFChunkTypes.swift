import Foundation

/// The chunk types this package can parse.
public enum IFFChunkTypes {
    /// Every typed chunk, in no particular order.
    public static let all: [any IFFChunk.Type] = [
        BHAV.self, BCON.self, TRCN.self, TPRP.self,
        STR.self, CTSS.self, TTAs.self,
        OBJD.self, OBJf.self, TTAB.self, SLOT.self, GLOB.self, FWAV.self,
        PIFF.self,
    ]

    /// The parser for a type code, or `nil` if the type isn't supported yet.
    public static func type(forCode typeCode: String) -> (any IFFChunk.Type)? {
        all.first { $0.typeCode == typeCode }
    }
}
