import Foundation
import Testing
@testable import TSOFiles

@Suite struct OBJDTests {
    /// Writes an OBJD with words set by position; every other word is zero.
    func objd(version: UInt32, words wordValues: [Int: UInt16]) -> IFFChunkRecord {
        record("OBJD") { writer in
            writer.uint32(version)
            for index in 0..<OBJD.wordCount(forVersion: version) {
                writer.uint16(wordValues[index] ?? 0)
            }
        }
    }

    @Test(arguments: [(UInt32(136), 78), (138, 93), (139, 94), (140, 95), (141, 95), (142, 103), (999, 78)])
    func storesTheWordCountOfEachVersion(version: UInt32, count: Int) throws {
        let object = try OBJD(record: objd(version: version, words: [:]))
        #expect(object.words.count == count)
    }

    @Test func readsNamedFieldsFromTheirWords() throws {
        let object = try OBJD(record: objd(version: 142, words: [
            3: 0x1000, 5: 129, 7: 4, 9: 0xFFFF, 12: 0x5678, 13: 0x1234, 16: 250, 39: 300, 77: 9,
        ]))
        #expect(object.bhavMainID == 0x1000)
        #expect(object.treeTableID == 129)
        #expect(object.knownObjectType == .normal)
        #expect(object.subIndex == -1)
        #expect(object.guid == 0x1234_5678, "the low word comes first")
        #expect(object.price == 250)
        #expect(object.catalogStringsID == 300)
        #expect(object.shadowBrightness == 9)
    }

    @Test func fallsBackToTheGUIDForTheTypeAttributeInLongLayouts() throws {
        let long = try OBJD(record: objd(version: 142, words: [12: 7]))
        #expect(long.typeAttributeGUID == 7)
        let stored = try OBJD(record: objd(version: 142, words: [12: 7, 90: 9]))
        #expect(stored.typeAttributeGUID == 9)
        let short = try OBJD(record: objd(version: 136, words: [12: 7]))
        #expect(short.typeAttributeGUID == 0, "version 136 has no type attribute field and no fallback")
        #expect(short.ratingHunger == 0, "fields past a version's words read as zero")
    }

    @Test func rejectsATruncatedObject() {
        let truncated = record("OBJD") { $0.uint32(142); $0.uint16(1) }
        #expect(throws: IFFChunkError.self) { try OBJD(record: truncated) }
    }
}

@Suite struct SmallObjectChunkTests {
    @Test func readsOBJf() throws {
        let table = try OBJf(record: record("OBJf") { writer in
            writer.uint32(0); writer.uint32(0); writer.ascii("fJBO"); writer.uint32(2)
            writer.uint16(0); writer.uint16(0x1001)
            writer.uint16(0x1002); writer.uint16(0x1003)
        })
        #expect(table.functions == [.init(conditionFunction: 0, actionFunction: 0x1001),
                                    .init(conditionFunction: 0x1002, actionFunction: 0x1003)])
    }

    @Test func readsGLOBAsAPascalString() throws {
        let glob = try GLOB(record: record("GLOB") { $0.uint8(7); $0.ascii("counter") })
        #expect(glob.name == "counter")
    }

    @Test func readsGLOBAsACStringThatMayEndWithoutANUL() throws {
        let terminated = try GLOB(record: record("GLOB") { $0.ascii("chairs\0junk") })
        #expect(terminated.name == "chairs")
        let unterminated = try GLOB(record: record("GLOB") { $0.ascii("tables") })
        #expect(unterminated.name == "tables")
    }

    @Test func readsFWAV() throws {
        let sound = try FWAV(record: record("FWAV") { $0.ascii("piano_play\0") })
        #expect(sound.name == "piano_play")
    }
}

@Suite struct SLOTTests {
    func slotHeader(_ writer: inout ByteWriter, version: UInt32, count: UInt32) {
        writer.uint32(0); writer.uint32(version); writer.ascii("TOLS"); writer.uint32(count)
    }

    func slotBase(_ writer: inout ByteWriter, type: UInt16) {
        writer.uint16(type)
        for value: Float in [1.5, -2, 0.25] { writer.uint32(value.bitPattern) }
        writer.int32(10); writer.int32(20); writer.int32(30)
        writer.int32(SLOT.Flags.north.union(.absolute).rawValue)
        writer.int32(-1)
    }

    @Test func appliesTheOldVersionDefaults() throws {
        let slots = try SLOT(record: record("SLOT") { writer in
            slotHeader(&writer, version: 4, count: 1)
            slotBase(&writer, type: 3)
        })
        let slot = try #require(slots.slots.first)
        #expect(slot.offset == SIMD3(1.5, -2, 0.25))
        #expect((slot.standing, slot.sitting, slot.ground) == (10, 20, 30))
        #expect(slot.flags == [.north, .absolute])
        #expect(slot.height == 5, "a missing height becomes 5")
        #expect(slot.facing == SLOT.Facing.towardsObject)
        #expect(slot.resolution == 16)
        #expect(slots.slots(ofType: 3).count == 1)
    }

    @Test func readsVersionTenFieldsAndScalesOlderProximities() throws {
        func make(version: UInt32) throws -> SLOT.Slot {
            let slots = try SLOT(record: record("SLOT") { writer in
                slotHeader(&writer, version: version, count: 1)
                slotBase(&writer, type: 0)
                writer.int32(1); writer.int32(2); writer.int32(3); writer.int32(0); writer.int32(0)
                writer.uint32(Float(0.5).bitPattern)
                writer.int32(8)
                writer.int32(SLOT.Facing.anywhere)
                if version >= 10 { writer.int32(32) }
            })
            return try #require(slots.slots.first)
        }

        let ten = try make(version: 10)
        #expect((ten.minProximity, ten.maxProximity, ten.optimalProximity) == (1, 2, 3))
        #expect((ten.gradient, ten.height, ten.facing, ten.resolution) == (0.5, 8, -3, 32))
        let nine = try make(version: 9)
        #expect((nine.minProximity, nine.maxProximity, nine.optimalProximity) == (16, 32, 48))
    }
}

@Suite struct TTABTests {
    @Test func readsAPlainVersionEightTable() throws {
        let table = try TTAB(record: record("TTAB", id: 129) { writer in
            writer.uint16(1); writer.uint16(8)
            writer.uint16(0x1001); writer.uint16(0x1002)
            writer.uint32(1)               // motive count
            writer.uint32(0x20)            // flags
            writer.uint32(3)               // TTA index
            writer.uint32(2)               // attenuation code (version > 6)
            writer.uint32(Float(0.02).bitPattern)
            writer.uint32(50)
            writer.int32(-1)
            writer.int16(-10); writer.int16(40); writer.uint16(7)
        })

        #expect(table.version == 8)
        let interaction = try #require(table.interaction(ttaIndex: 3))
        #expect((interaction.actionFunction, interaction.testFunction) == (0x1001, 0x1002))
        #expect((interaction.flags, interaction.attenuationCode, interaction.autonomyThreshold) == (0x20, 2, 50))
        #expect(interaction.attenuationValue == 0.02)
        #expect(interaction.joiningIndex == -1)
        #expect(interaction.motiveEntries == [.init(effectRangeMinimum: -10, effectRangeMaximum: 40, personalityModifier: 7)])
        #expect(interaction.tsoFlags == 0x1F, "versions before 10 get the 2017 default")
    }

    @Test func readsAnOldTableWithoutVersionSevenFields() throws {
        let table = try TTAB(record: record("TTAB") { writer in
            writer.uint16(1); writer.uint16(3)
            writer.uint16(1); writer.uint16(2); writer.uint32(1); writer.uint32(0); writer.uint32(0)
            writer.uint32(Float(1).bitPattern); writer.uint32(0); writer.int32(0)
            writer.int16(25)
        })
        let motive = try #require(table.interactions.first?.motiveEntries.first)
        #expect(motive == .init(effectRangeMinimum: 0, effectRangeMaximum: 25, personalityModifier: 0))
    }

    @Test func readsAFieldEncodedVersionTenTable() throws {
        var fields = FieldEncodedWriter()
        fields.short(0x1001); fields.short(0)            // action, test
        fields.long(2)                                    // motive count
        fields.long(0x24); fields.long(5); fields.long(1) // flags, TTA index, attenuation code
        fields.long(3)                                    // attenuation "float": the integer 3
        fields.long(-20); fields.long(-1)                 // autonomy threshold, joining index
        fields.short(-100); fields.short(100); fields.short(4)
        fields.short(0); fields.short(-1); fields.short(0)
        fields.long(0x40)                                 // TSO flags
        let table = try TTAB(record: record("TTAB") { writer in
            writer.uint16(1); writer.uint16(10); writer.uint8(1); writer.raw(fields.bytes)
        })

        let interaction = try #require(table.interactions.first)
        #expect(interaction.actionFunction == 0x1001)
        #expect((interaction.flags, interaction.ttaIndex, interaction.attenuationCode) == (0x24, 5, 1))
        #expect(interaction.attenuationValue == 3, "field-encoded floats are converted integers, as in 2017")
        #expect(interaction.autonomyThreshold == UInt32(bitPattern: -20))
        #expect(interaction.joiningIndex == -1)
        #expect(interaction.motiveEntries == [.init(effectRangeMinimum: -100, effectRangeMaximum: 100, personalityModifier: 4),
                                              .init(effectRangeMinimum: 0, effectRangeMaximum: -1, personalityModifier: 0)])
        #expect(interaction.tsoFlags == 0x40)
    }

    @Test func leavesAnEmptyTableWithoutAVersion() throws {
        let table = try TTAB(record: record("TTAB") { $0.uint16(0) })
        #expect(table.version == nil && table.interactions.isEmpty)
    }

    @Test func rejectsAnUnknownFieldEncoding() {
        let bad = record("TTAB") { $0.uint16(1); $0.uint16(9); $0.uint8(2); $0.uint8(0) }
        #expect(throws: IFFChunkError.invalid(typeCode: "TTAB", id: 1, reason: "unknown field encoding 2")) {
            try TTAB(record: bad)
        }
    }

    @Test func rejectsAMotiveCountLargerThanTheData() {
        // The real install has orphaned tables like this: 0xA3A30010 motives in a 180-byte chunk.
        let bad = record("TTAB") { writer in
            writer.uint16(1); writer.uint16(2); writer.uint16(1); writer.uint16(2); writer.uint32(0xA3A3_0010)
        }
        #expect(throws: IFFChunkError.self) { try TTAB(record: bad) }
    }

    @Test func rejectsARepeatedTTAIndex() {
        let bad = record("TTAB") { writer in
            writer.uint16(2); writer.uint16(3)
            for _ in 0..<2 {
                writer.uint16(1); writer.uint16(2); writer.uint32(0); writer.uint32(0); writer.uint32(4)
                writer.uint32(0); writer.uint32(0); writer.int32(0)
            }
        }
        #expect(throws: IFFChunkError.invalid(typeCode: "TTAB", id: 1, reason: "repeated TTA index 4")) {
            try TTAB(record: bad)
        }
    }
}

@Suite struct FieldEncodedReaderTests {
    @Test(arguments: [Int64(0), 1, -1, 15, -16, 16, 127, -128, 4095, -4096, 32767, -32768])
    func roundTripsShortValues(value: Int64) throws {
        var writer = FieldEncodedWriter()
        writer.short(value)
        var reader = try FieldEncodedReader(ByteReader(writer.bytes, byteOrder: .littleEndian))
        #expect(Int64(reader.readInt16()) == value)
    }

    @Test(arguments: [Int64(0), 31, -32, 1023, -1024, 1_048_575, -1_048_576, Int64(Int32.max), Int64(Int32.min)])
    func roundTripsLongValues(value: Int64) throws {
        var writer = FieldEncodedWriter()
        writer.long(value)
        var reader = try FieldEncodedReader(ByteReader(writer.bytes, byteOrder: .littleEndian))
        #expect(Int64(reader.readInt32()) == value)
    }

    @Test func readsZerosPastTheEnd() throws {
        var reader = try FieldEncodedReader(ByteReader(Data([0x00]), byteOrder: .littleEndian))
        for _ in 0..<20 { #expect(reader.readUInt32() == 0) }
    }
}
