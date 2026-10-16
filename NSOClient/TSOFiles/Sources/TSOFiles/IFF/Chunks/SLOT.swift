import Foundation

/// Positions on an object where Sims stand or sit and where other objects go.
///
/// Ports FreeSO's `SLOT`. Later versions add fields; missing ones keep the
/// FreeSO defaults. Like FreeSO, proximities are multiplied by 16 for version 9
/// and below, and a height of 0 becomes 5.
public struct SLOT: IFFChunk {
    public static let typeCode = "SLOT"

    /// Slot flags (`SLOTFlags`), kept with their FreeSO values.
    public struct Flags: OptionSet, Sendable, Hashable {
        public var rawValue: Int32
        public init(rawValue: Int32) { self.rawValue = rawValue }

        public static let north = Self(rawValue: 1)
        public static let northEast = Self(rawValue: 2)
        public static let east = Self(rawValue: 4)
        public static let southEast = Self(rawValue: 8)
        public static let south = Self(rawValue: 16)
        public static let southWest = Self(rawValue: 32)
        public static let west = Self(rawValue: 64)
        public static let northWest = Self(rawValue: 128)
        public static let allowAnyRotation = Self(rawValue: 256)
        public static let absolute = Self(rawValue: 512)
        public static let facingAwayFromObject = Self(rawValue: 1024)
        public static let ignoreRooms = Self(rawValue: 2048)
        public static let snapToDirection = Self(rawValue: 4096)
        public static let randomScoring = Self(rawValue: 8192)
        /// 16385 in FreeSO, which also sets `north`; likely meant to be 16384. Kept as is.
        public static let allowFailureTrees = Self(rawValue: 16385)
        public static let allowDifferentAlts = Self(rawValue: 32768)
        public static let useAverageObjectLocation = Self(rawValue: 65536)
    }

    /// The special facing values (`SLOTFacing`). Others are direction indices.
    public enum Facing {
        public static let anywhere: Int32 = -3
        public static let towardsObject: Int32 = -2
        public static let awayFromObject: Int32 = -1
    }

    /// One slot.
    public struct Slot: Sendable, Equatable {
        public var type: UInt16
        /// Offset from the object, x, y, z.
        public var offset: SIMD3<Float>
        public var standing: Int32 = 1
        public var sitting: Int32 = 0
        public var ground: Int32 = 0
        public var flags: Flags = []
        public var snapTargetSlot: Int32 = -1
        public var minProximity: Int32 = 0
        public var maxProximity: Int32 = 0
        public var optimalProximity: Int32 = 0
        /// Version 7 and up.
        public var gradient: Float = 0
        /// Version 8 and up. 0 becomes 5 (use the offset height).
        public var height: Int32 = 0
        /// Version 9 and up. See ``Facing``.
        public var facing: Int32 = Facing.towardsObject
        /// Version 10 and up.
        public var resolution: Int32 = 16
    }

    public let id: UInt16
    public let label: String
    public let version: UInt32
    /// Every slot in file order.
    public let slots: [Slot]

    /// The slots of one type, in file order.
    public func slots(ofType type: UInt16) -> [Slot] {
        slots.filter { $0.type == type }
    }

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (version, slots) = try record.parse(byteOrder: .littleEndian) { reader in
            _ = try reader.readUInt32() // always zero
            let version = try reader.readUInt32()
            try reader.skip(4) // magic
            let count = try reader.readUInt32()

            var slots: [Slot] = []
            for _ in 0..<count {
                var slot = Slot(
                    type: try reader.readUInt16(),
                    offset: SIMD3(try Self.readFloat(&reader), try Self.readFloat(&reader), try Self.readFloat(&reader)))
                slot.standing = try reader.readInt32()
                slot.sitting = try reader.readInt32()
                slot.ground = try reader.readInt32()
                slot.flags = Flags(rawValue: try reader.readInt32())
                slot.snapTargetSlot = try reader.readInt32()
                if version >= 6 {
                    slot.minProximity = try reader.readInt32()
                    slot.maxProximity = try reader.readInt32()
                    slot.optimalProximity = try reader.readInt32()
                    try reader.skip(8) // two unknown values
                }
                if version <= 9 {
                    slot.minProximity &*= 16
                    slot.maxProximity &*= 16
                    slot.optimalProximity &*= 16
                }
                if version >= 7 { slot.gradient = try Self.readFloat(&reader) }
                if version >= 8 { slot.height = try reader.readInt32() }
                if slot.height == 0 { slot.height = 5 }
                if version >= 9 { slot.facing = try reader.readInt32() }
                if version >= 10 { slot.resolution = try reader.readInt32() }
                slots.append(slot)
            }
            return (version, slots)
        }
    }

    private static func readFloat(_ reader: inout ByteReader) throws -> Float {
        Float(bitPattern: try reader.readUInt32())
    }
}
