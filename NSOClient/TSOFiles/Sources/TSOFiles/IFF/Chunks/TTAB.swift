import Foundation

/// An object's interactions: what appears in its pie menu and the routines behind each entry.
///
/// Ports FreeSO's `TTAB`. Pie menu text lives in the ``TTAs`` chunk with the
/// same ID. Versions 9 and 10 (TSO's) are field-encoded; earlier versions are
/// plain little-endian. Flags are kept as raw values, as stored.
public struct TTAB: IFFChunk {
    public static let typeCode = "TTAB"

    /// How one interaction affects one motive.
    public struct MotiveEntry: Sendable, Equatable {
        /// Version 7 and up.
        public var effectRangeMinimum: Int16 = 0
        public var effectRangeMaximum: Int16 = 0
        /// Version 7 and up.
        public var personalityModifier: UInt16 = 0
    }

    /// One pie menu entry.
    public struct Interaction: Sendable, Equatable {
        /// The BHAV that runs the interaction.
        public var actionFunction: UInt16
        /// The BHAV that checks whether the interaction is available.
        public var testFunction: UInt16
        public var motiveEntries: [MotiveEntry]
        /// The `TTABFlags` bits.
        public var flags: UInt32
        /// The index of the interaction's string in the matching ``TTAs``.
        public var ttaIndex: UInt32
        /// Version 7 and up.
        public var attenuationCode: UInt32 = 0
        public var attenuationValue: Float
        public var autonomyThreshold: UInt32
        public var joiningIndex: Int32
        /// The `TSOFlags` bits, version 10 and up. Earlier versions get 0x1F, as in 2017.
        public var tsoFlags: UInt32 = 0x1F
    }

    public let id: UInt16
    public let label: String
    /// The format version, or `nil` when the table is empty (the 2017 reader stops before it).
    public let version: UInt16?
    public let interactions: [Interaction]

    /// The interaction with the given string index.
    public func interaction(ttaIndex: UInt32) -> Interaction? {
        interactions.first { $0.ttaIndex == ttaIndex }
    }

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        (version, interactions) = try record.parse(byteOrder: .littleEndian) { reader in
            let count = Int(try reader.readUInt16())
            guard count > 0 else { return (nil, []) }
            let version = try reader.readUInt16()

            var interactions: [Interaction]
            if version == 9 || version == 10 {
                let compressionCode = try reader.readUInt8()
                guard compressionCode == 1 else {
                    throw ChunkFormatError(reason: "unknown field encoding \(compressionCode)")
                }
                var values = try FieldEncodedReader(reader)
                interactions = try Self.readInteractions(count: count, version: version, from: &values)
            } else {
                var values = PlainValueReader(reader: reader)
                interactions = try Self.readInteractions(count: count, version: version, from: &values)
            }

            // The 2017 reader indexes interactions by string index and fails on a repeat.
            var seen = Set<UInt32>()
            for interaction in interactions where !seen.insert(interaction.ttaIndex).inserted {
                throw ChunkFormatError(reason: "repeated TTA index \(interaction.ttaIndex)")
            }
            return (version, interactions)
        }
    }

    private static func readInteractions<Values: TTABValueReading>(
        count: Int, version: UInt16, from values: inout Values
    ) throws -> [Interaction] {
        var interactions: [Interaction] = []
        for _ in 0..<count {
            let actionFunction = try values.readUInt16()
            let testFunction = try values.readUInt16()
            let motiveCount = Int(try values.readUInt32())
            // Field-encoded reads past the end return zeros, so a corrupt count could
            // spin for billions of entries. Each entry needs at least one bit.
            guard motiveCount <= values.bitsRemaining else {
                throw ChunkFormatError(reason: "motive count \(motiveCount) exceeds the chunk data")
            }
            var interaction = Interaction(
                actionFunction: actionFunction,
                testFunction: testFunction,
                motiveEntries: [],
                flags: try values.readUInt32(),
                ttaIndex: try values.readUInt32(),
                attenuationValue: 0,
                autonomyThreshold: 0,
                joiningIndex: 0)
            if version > 6 { interaction.attenuationCode = try values.readUInt32() }
            interaction.attenuationValue = try values.readFloat()
            interaction.autonomyThreshold = try values.readUInt32()
            interaction.joiningIndex = try values.readInt32()

            for _ in 0..<motiveCount {
                var motive = MotiveEntry()
                if version > 6 { motive.effectRangeMinimum = try values.readInt16() }
                motive.effectRangeMaximum = try values.readInt16()
                if version > 6 { motive.personalityModifier = try values.readUInt16() }
                interaction.motiveEntries.append(motive)
            }
            if version > 9 { interaction.tsoFlags = try values.readUInt32() }
            interactions.append(interaction)
        }
        return interactions
    }
}

/// The value reads `TTAB` needs, from either the plain or the field-encoded layout.
protocol TTABValueReading {
    var bitsRemaining: Int { get }
    mutating func readUInt16() throws -> UInt16
    mutating func readInt16() throws -> Int16
    mutating func readUInt32() throws -> UInt32
    mutating func readInt32() throws -> Int32
    mutating func readFloat() throws -> Float
}

extension FieldEncodedReader: TTABValueReading {}

/// Plain little-endian values, with floats read as IEEE 754 bit patterns.
struct PlainValueReader: TTABValueReading {
    var reader: ByteReader

    var bitsRemaining: Int { reader.remaining * 8 }
    mutating func readUInt16() throws -> UInt16 { try reader.readUInt16() }
    mutating func readInt16() throws -> Int16 { try reader.readInt16() }
    mutating func readUInt32() throws -> UInt32 { try reader.readUInt32() }
    mutating func readInt32() throws -> Int32 { try reader.readInt32() }
    mutating func readFloat() throws -> Float { Float(bitPattern: try reader.readUInt32()) }
}
