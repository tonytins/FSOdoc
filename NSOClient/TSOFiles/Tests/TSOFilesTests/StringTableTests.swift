import Foundation
import Testing
@testable import TSOFiles

@Suite struct StringTableTests {
    func latin1(_ text: String) -> [UInt8] { text.unicodeScalars.map { UInt8($0.value) } + [0] }

    @Test func readsPascalStrings() throws {
        let table = try STR(record: record("STR#") { writer in
            writer.int16(0); writer.uint16(2)
            writer.uint8(5); writer.ascii("Chair")
            writer.uint8(4); writer.ascii("Sofa")
        }).table
        #expect(table.formatCode == 0)
        #expect(table.count == 2)
        #expect(table.string(at: 1) == "Sofa")
        #expect(table.strings(for: .englishUS).first?.comment == nil)
        #expect(table.languageSets.count == 20)
    }

    @Test func readsUTF8CStrings() throws {
        let table = try STR(record: record("STR#") { writer in
            writer.int16(-1); writer.uint16(1); writer.raw(Array("naïve".utf8) + [0])
        }).table
        #expect(table.string(at: 0) == "naïve")
    }

    @Test func readsLatin1Pairs() throws {
        let table = try CTSS(record: record("CTSS") { writer in
            writer.int16(-2); writer.uint16(1); writer.raw(latin1("Caf\u{E9}")); writer.raw(latin1("comment"))
        }).table
        let item = try #require(table.strings(for: .englishUS).first)
        #expect(item.value == "Café")
        #expect(item.comment == "comment")
    }

    @Test func sortsLanguageCodedPairsIntoSets() throws {
        let table = try STR(record: record("STR#") { writer in
            writer.int16(-3); writer.uint16(4)
            for (code, text) in [(UInt8(0), "zero"), (1, "english"), (3, "français"), (21, "dropped")] {
                writer.uint8(code); writer.raw(latin1(text)); writer.raw(latin1(""))
            }
        }).table

        #expect(table.strings(for: .englishUS).map(\.value) == ["zero", "english"])
        #expect(table.strings(for: .englishUS).first?.languageCode == 0, "code 0 files under English but keeps its code")
        #expect(table.string(at: 0, language: .french) == "français")
        #expect(table.string(at: 0, language: .german) == "zero", "an empty language falls back to English")
        #expect(table.languageSets.joined().count == 3, "codes above 20 are dropped")
    }

    @Test func readsTSOLanguageSets() throws {
        let table = try TTAs(record: record("TTAs") { writer in
            writer.int16(-4)
            writer.uint8(2) // two sets
            writer.uint16(1); writer.uint8(0); writer.raw([4]); writer.ascii("Push"); writer.raw([0])
            writer.uint16(1); writer.uint8(1); writer.raw([6]); writer.ascii("Pousse"); writer.raw([0])
        }).table

        #expect(table.languageSets.count == 2)
        #expect(table.strings(for: .englishUS).first?.languageCode == 1, "stored codes are one less")
        #expect(table.string(at: 0, language: .englishUK) == "Pousse")
        #expect(table.string(at: 0, language: .korean) == "Push", "a language past the stored sets falls back")
    }

    @Test func resolvesTheDefaultLanguage() throws {
        let table = try STR(record: record("STR#") { writer in
            writer.int16(-3); writer.uint16(2)
            writer.uint8(1); writer.raw(latin1("hello")); writer.raw(latin1(""))
            writer.uint8(4); writer.raw(latin1("hallo")); writer.raw(latin1(""))
        }).table
        #expect(table.string(at: 0) == "hello")
        #expect(table.string(at: 0, defaultLanguage: .german) == "hallo")
        #expect(table.string(at: 5) == nil)
    }

    @Test func treatsATableWithNoCountAsEmpty() throws {
        let table = try STR(record: record("STR#") { $0.int16(0); $0.uint8(9) }).table
        #expect(table.count == 0)
        #expect(table.languageSets.count == 20)
    }

    @Test func rejectsAnUnknownFormat() {
        let bad = record("STR#", id: 3) { $0.int16(-9); $0.uint16(0) }
        #expect(throws: IFFChunkError.invalid(typeCode: "STR#", id: 3, reason: "unknown string table format -9")) {
            try STR(record: bad)
        }
    }

    @Test func rejectsAnInvalidLengthPrefix() {
        let bad = record("STR#") { writer in
            writer.int16(-4); writer.uint8(1); writer.uint16(1); writer.uint8(0)
            writer.raw([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
        }
        #expect(throws: IFFChunkError.self) { try STR(record: bad) }
    }
}

@Suite struct ByteReaderStringTests {
    @Test func readsDotNetStringsAndRejectsLongPrefixes() throws {
        var good = ByteReader(Data([0x03]) + Data("abc".utf8), byteOrder: .littleEndian)
        #expect(try good.readDotNetString() == "abc")
        var bad = ByteReader(Data([0x80, 0x80, 0x80, 0x80, 0x80, 0x01]), byteOrder: .littleEndian)
        #expect(try bad.readDotNetString() == nil)
    }

    @Test func returnsNilForANegativeLongPascalLength() throws {
        var reader = ByteReader(Data([0xFF, 0xFF]), byteOrder: .littleEndian)
        #expect(try reader.readLongPascalString() == nil)
    }

    @Test func throwsWhenACStringNeverEnds() {
        var reader = ByteReader(Data("abc".utf8), byteOrder: .littleEndian)
        #expect(throws: EndOfDataError.self) { try reader.readNullTerminatedLatin1() }
    }
}
