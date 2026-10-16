import Foundation
import Testing
@testable import TSOFiles

/// Encodes bytes as a literal-only RefPack stream, enough for tests that need compressed input.
func refPackLiterals(_ bytes: [UInt8]) -> Data {
    var stream: [UInt8] = []
    var index = 0
    while bytes.count - index >= 4 {
        let run = min(112, (bytes.count - index) / 4 * 4)
        stream.append(UInt8(0xE0 + run / 4 - 1))
        stream.append(contentsOf: bytes[index..<(index + run)])
        index += run
    }
    stream.append(UInt8(0xFC + (bytes.count - index)))
    stream.append(contentsOf: bytes[index...])
    return Data(stream)
}

@Suite struct OTFFileTests {
    @Test func readsTablesAndKeysSkippingComments() throws {
        let otf = try OTFFile(bytes: Data("""
            <?xml version="1.0"?>
            <M>
              <!-- tuning -->
              <T i="4096" n="Chair">
                <K i="0" l="comfort" v=" 25 "/>
                <!-- note -->
                <K i="1" l="cost" v="-3"/>
              </T>
              <Group><T i="7" n="Nested"/></Group>
            </M>
            """.utf8))

        #expect(otf.tables.map(\.name) == ["Chair", "Nested"], "T elements anywhere count")
        let chair = try #require(otf.table(id: 4096))
        #expect(chair.keys == [.init(id: 0, label: "comfort", value: 25), .init(id: 1, label: "cost", value: -3)])
        #expect(chair.key(id: 1)?.value == -3)
    }

    @Test func rejectsBadDocuments() {
        #expect(throws: OTFError.self) { try OTFFile(bytes: Data("<M><T i=\"1\">".utf8)) }
        #expect(throws: OTFError.missingAttribute(element: "T", attribute: "n")) {
            try OTFFile(bytes: Data("<M><T i=\"1\"/></M>".utf8))
        }
        #expect(throws: OTFError.invalidNumber(element: "K", attribute: "v", "lots")) {
            try OTFFile(bytes: Data("<M><T i=\"1\" n=\"a\"><K i=\"0\" l=\"x\" v=\"lots\"/></T></M>".utf8))
        }
        #expect(throws: OTFError.unexpectedContent(table: "a")) {
            try OTFFile(bytes: Data("<M><T i=\"1\" n=\"a\">text</T></M>".utf8))
        }
    }
}

@Suite struct TuningFileTests {
    /// Writes a 7-bit length and the string with 13 added to each byte.
    func obfuscated(_ writer: inout ByteWriter, _ text: String) {
        writer.uint8(UInt8(text.utf8.count))
        writer.raw(text.utf8.map { $0 &+ 13 })
    }

    func tuningFile(bodyType: UInt8 = 1, compressionID: UInt16 = 0xFB10, _ body: (inout ByteWriter) -> Void) -> Data {
        var bodyWriter = ByteWriter()
        body(&bodyWriter)
        let stream = refPackLiterals(Array(bodyWriter.bytes))
        var writer = ByteWriter()
        writer.uint8(bodyType)
        writer.uint32(UInt32(bodyWriter.count))
        writer.uint32(UInt32(stream.count))
        writer.uint32(UInt32(stream.count))
        writer.uint16(compressionID)
        writer.raw([0, 0, 0])
        writer.raw(stream)
        return writer.bytes
    }

    @Test func readsObfuscatedEntriesAfterDecompressing() throws {
        let tuning = try TuningFile(bytes: tuningFile { writer in
            writer.uint32(2)
            obfuscated(&writer, "MotiveDecay"); writer.uint32(2)
            obfuscated(&writer, "hunger"); obfuscated(&writer, "0.25")
            obfuscated(&writer, "energy"); obfuscated(&writer, "1")
            obfuscated(&writer, "Empty"); writer.uint32(0)
        })

        let decay = try #require(tuning.entry(named: "motivedecay"), "names match without case")
        #expect(decay.value(forKey: "hunger") == "0.25")
        #expect(decay.number(forKey: "hunger") == 0.25)
        #expect(tuning.entries.map(\.name) == ["MotiveDecay", "Empty"])
    }

    @Test func rejectsOtherContainers() {
        #expect(throws: TuningError.notATuningFile) { try TuningFile(bytes: tuningFile(bodyType: 2) { $0.uint32(0) }) }
        #expect(throws: TuningError.notATuningFile) { try TuningFile(bytes: tuningFile(compressionID: 1) { $0.uint32(0) }) }
    }

    @Test func rejectsANameRepeatedInAnotherCase() {
        #expect(throws: TuningError.repeatedEntry("a")) {
            try TuningFile(bytes: tuningFile { writer in
                writer.uint32(2)
                obfuscated(&writer, "A"); writer.uint32(0)
                obfuscated(&writer, "a"); writer.uint32(0)
            })
        }
    }
}

@Suite struct DataDefinitionTests {
    func definition(structNames: [String], derivedParent: UInt32 = 1) -> Data {
        var writer = ByteWriter()
        writer.uint32(0xABCD)
        // list 1: structs with typed fields
        writer.uint32(UInt32(structNames.count))
        for index in structNames.indices {
            writer.uint32(UInt32(index + 1))   // name string ID
            writer.uint32(1)                   // one field
            writer.uint32(100); writer.uint8(2); writer.uint32(0x55)
        }
        writer.uint32(0)                       // list 2: empty
        writer.uint32(1)                       // list 3: one derived struct
        writer.uint32(50); writer.uint32(derivedParent); writer.uint32(1)
        writer.uint32(100); writer.uint8(1)
        let strings = structNames.enumerated().map { (UInt32($0.offset + 1), $0.element) } + [(100, "Name"), (50, "Avatar_Small")]
        writer.uint32(UInt32(strings.count))
        for (id, text) in strings {
            writer.uint32(id); writer.ascii(text + "\0"); writer.uint8(0)
        }
        return writer.bytes
    }

    @Test func readsStructsFieldsAndDerivedMasks() throws {
        let definition = try DataDefinition(bytes: definition(structNames: ["Avatar"]))
        let avatar = try #require(definition.structure(named: "Avatar"))
        #expect(avatar.fields == [.init(id: 100, name: "Name", classificationValue: 2, typeID: 0x55, parentID: 1)])
        #expect(avatar.fields.first?.classification == .list)
        let small = try #require(definition.derivedStructs.first)
        #expect(small.name == "Avatar_Small" && small.parentID == 1)
        #expect(small.fieldMasks.first?.type == .keep)
    }

    @Test func rejectsRepeatedStructNames() {
        #expect(throws: DataDefinitionError.repeatedStructName("Lot")) {
            try DataDefinition(bytes: definition(structNames: ["Lot", "Lot"]))
        }
    }
}

@Suite struct INIFileTests {
    @Test func readsSectionsKeysAndComments() throws {
        let ini = try INIFile(bytes: Data("\u{FEFF}orphan=1\r\n; comment\r\n[Server]\r\n  host = auth.example \r\nport=80\nport=443\nempty=\n=novalue\r[Other]\nk=v".utf8))

        #expect(ini.sections.map(\.name) == ["Server", "Other"])
        let server = try #require(ini.section(named: "Server"))
        #expect(server.value(forKey: "host") == "auth.example ", "values keep trailing space, as in FreeSO")
        #expect(server.value(forKey: "port") == "443", "a repeated key keeps its last value")
        #expect(server.value(forKey: "empty") == nil)
        #expect(server.values.count == 2)
        #expect(ini.section(named: "Other")?.value(forKey: "k") == "v")
    }

    @Test func rejectsWhatFreeSOsReaderRejects() {
        #expect(throws: INIError.unclosedSection(line: 1)) { try INIFile(bytes: Data("[open".utf8)) }
        #expect(throws: INIError.repeatedSection("a")) { try INIFile(bytes: Data("[a]\n[a]".utf8)) }
    }
}
