import Foundation
import Testing
@testable import TSOFiles

/// Builds a chunk record from little-endian bytes written by `build`.
func record(_ typeCode: String, id: UInt16 = 1, label: String = "", _ build: (inout ByteWriter) -> Void) -> IFFChunkRecord {
    var writer = ByteWriter()
    build(&writer)
    return IFFChunkRecord(typeCode: typeCode, id: id, flags: 0, label: label, data: writer.bytes)
}

@Suite struct BHAVTests {
    func instruction(_ writer: inout ByteWriter, opcode: UInt16, true truePointer: UInt8, false falsePointer: UInt8) {
        writer.uint16(opcode)
        writer.uint8(truePointer)
        writer.uint8(falsePointer)
        writer.raw([1, 2, 3, 4, 5, 6, 7, 8])
    }

    @Test func readsVersion8003() throws {
        let bhav = try BHAV(record: record("BHAV", id: 4096, label: "main") { writer in
            writer.uint16(0x8003)
            writer.uint8(3)  // type
            writer.uint8(2)  // arguments
            writer.uint8(5)  // locals, one byte in this version
            writer.raw([0, 0])
            writer.uint16(0x0010) // flags
            writer.uint32(2)
            instruction(&writer, opcode: 2, true: 1, false: 254)
            instruction(&writer, opcode: 0x1001, true: 254, false: 255)
        })

        #expect(bhav.id == 4096 && bhav.label == "main")
        #expect((bhav.type, bhav.argumentCount, bhav.localCount, bhav.flags) == (3, 2, 5, 0x0010))
        #expect(bhav.instructions.map(\.opcode) == [2, 0x1001])
        #expect(bhav.instructions[0].truePointer == 1 && bhav.instructions[0].falsePointer == 254)
        #expect(bhav.instructions[1].operand == Data([1, 2, 3, 4, 5, 6, 7, 8]))
    }

    @Test func readsVersion8002() throws {
        let bhav = try BHAV(record: record("BHAV") { writer in
            writer.uint16(0x8002)
            writer.uint16(1)
            writer.uint8(1)
            writer.uint8(4)
            writer.uint16(300) // locals, two bytes in this version
            writer.uint16(7)
            writer.raw([0, 0])
            instruction(&writer, opcode: 9, true: 254, false: 255)
        })
        #expect((bhav.argumentCount, bhav.localCount, bhav.flags) == (4, 300, 7))
        #expect(bhav.instructions.count == 1)
    }

    @Test(arguments: [UInt16(0x8000), 0x8001])
    func readsOldVersionsWithoutHeaderFields(version: UInt16) throws {
        let bhav = try BHAV(record: record("BHAV") { writer in
            writer.uint16(version)
            writer.uint16(1)
            writer.raw(repeatElement(UInt8(0xEE), count: 8))
            instruction(&writer, opcode: 3, true: 254, false: 255)
        })
        #expect(bhav.instructions.map(\.opcode) == [3])
        #expect((bhav.type, bhav.argumentCount, bhav.localCount) == (0, 0, 0))
    }

    @Test func leavesUnknownVersionsEmptyLikeFreeSO() throws {
        let bhav = try BHAV(record: record("BHAV") { $0.uint16(0x1234); $0.uint16(5) })
        #expect(bhav.instructions.isEmpty)
    }

    @Test func rejectsATruncatedInstruction() {
        let truncated = record("BHAV", id: 7) { writer in
            writer.uint16(0x8000)
            writer.uint16(2)
            writer.raw(repeatElement(UInt8(0), count: 8))
            instruction(&writer, opcode: 3, true: 254, false: 255)
            writer.uint16(4) // second instruction cut short
        }
        #expect(throws: IFFChunkError.self) { try BHAV(record: truncated) }
    }
}

@Suite struct ConstantChunkTests {
    @Test func readsBCON() throws {
        let bcon = try BCON(record: record("BCON") { writer in
            writer.uint8(3)
            writer.uint8(0x80)
            writer.uint16(10); writer.uint16(0xFFFF); writer.uint16(500)
        })
        #expect(bcon.flags == 0x80)
        #expect(bcon.constants == [10, 0xFFFF, 500])
    }

    @Test func readsTRCNVersionZeroWithDefaultRanges() throws {
        let trcn = try TRCN(record: record("TRCN") { writer in
            writer.int32(0); writer.int32(0); writer.uint32(0x5452_434E); writer.int32(1)
            writer.int32(0); writer.int32(0)
            writer.raw(Array("Caf\u{E9}".unicodeScalars.map { UInt8($0.value) }) + [0]) // Latin-1
            writer.raw([0])
        })
        let entry = try #require(trcn.entries.first)
        #expect(entry.label == "Café")
        #expect(entry.comment.isEmpty)
        #expect((entry.rangeEnabled, entry.lowRange, entry.highRange) == (0, 0, 100))
    }

    @Test func readsTRCNVersionTwoWithDotNetStrings() throws {
        let label = String(repeating: "x", count: 200) // needs a two-byte length prefix
        let trcn = try TRCN(record: record("TRCN") { writer in
            writer.int32(0); writer.int32(2); writer.uint32(0); writer.int32(1)
            writer.int32(5); writer.int32(6)
            writer.raw([0xC8, 0x01]); writer.ascii(label)   // 200 as a 7-bit encoded length
            writer.raw([0x02]); writer.raw("é".utf8)         // UTF-8
            writer.uint8(1); writer.int16(-5); writer.int16(50)
        })
        let entry = try #require(trcn.entries.first)
        #expect(entry.label == label)
        #expect(entry.comment == "é")
        #expect((entry.flags, entry.rangeEnabled, entry.lowRange, entry.highRange) == (5, 1, -5, 50))
    }

    @Test func rejectsANegativeCount() {
        let bad = record("TRCN") { writer in
            writer.int32(0); writer.int32(2); writer.uint32(0); writer.int32(-1)
        }
        #expect(throws: IFFChunkError.invalid(typeCode: "TRCN", id: 1, reason: "negative count -1")) {
            try TRCN(record: bad)
        }
    }

    @Test(arguments: [(Int32(5), true), (4, false)])
    func readsTPRPNames(version: Int32, pascal: Bool) throws {
        let tprp = try TPRP(record: record("TPRP") { writer in
            writer.int32(0); writer.int32(version); writer.ascii("PRPT"); writer.int32(1); writer.int32(2)
            for name in ["object", "count", "i"] {
                if pascal { writer.uint8(UInt8(name.count)); writer.ascii(name) } else { writer.ascii(name + "\0") }
            }
        })
        #expect(tprp.parameterNames == ["object"])
        #expect(tprp.localNames == ["count", "i"])
    }
}

@Suite struct BHAVEncodingTests {
    static let instructions = [
        BHAV.Instruction(opcode: 2, truePointer: 1, falsePointer: 255, operand: Data([1, 2, 3, 4, 5, 6, 7, 8])),
        BHAV.Instruction(opcode: 4097, truePointer: 254, falsePointer: 253, operand: Data([9, 0, 0, 0, 0, 0, 0, 0])),
    ]

    @Test(arguments: [UInt16(0x8000), 0x8001, 0x8002, 0x8003])
    func readsBackWhatItWrites(version: UInt16) throws {
        let isVersion2or3 = version >= 0x8002
        let original = BHAV(id: 4096, label: "main", version: version, type: isVersion2or3 ? 3 : 0,
                            argumentCount: isVersion2or3 ? 2 : 0, localCount: isVersion2or3 ? 5 : 0,
                            flags: isVersion2or3 ? 0x10 : 0, instructions: Self.instructions)
        let read = try BHAV(record: IFFChunkRecord(typeCode: "BHAV", id: 4096, flags: 0, label: "main", data: original.encoded()))
        #expect(read.version == version && read.type == original.type && read.argumentCount == original.argumentCount)
        #expect(read.localCount == original.localCount && read.flags == original.flags)
        #expect(read.instructions == Self.instructions)
    }

    @Test func writesAnUnknownVersionAsEmpty() throws {
        let original = BHAV(id: 1, label: "", version: 7, instructions: Self.instructions)
        let read = try BHAV(record: IFFChunkRecord(typeCode: "BHAV", id: 1, flags: 0, label: "", data: original.encoded()))
        #expect(read.instructions.isEmpty)
    }
}
