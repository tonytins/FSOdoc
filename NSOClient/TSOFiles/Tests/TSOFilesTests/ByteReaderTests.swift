import Foundation
import Testing
@testable import TSOFiles

@Suite struct ByteReaderTests {
    @Test(arguments: zip([ByteOrder.littleEndian, .bigEndian], [UInt32(0x0403_0201), 0x0102_0304]))
    func readsIntegersInEitherByteOrder(order: ByteOrder, expected: UInt32) throws {
        var reader = ByteReader(Data([1, 2, 3, 4]), byteOrder: order)
        #expect(try reader.readUInt32() == expected)
        #expect(reader.remaining == 0)
    }

    @Test func readsSignedValuesByBitPattern() throws {
        var reader = ByteReader(Data([0xFF, 0xFF, 0xFE, 0xFF, 0xFF, 0xFF]), byteOrder: .littleEndian)
        #expect(try reader.readInt16() == -1)
        #expect(try reader.readInt32() == -2)
    }

    @Test func readsTwentyFourBitValues() throws {
        var reader = ByteReader(Data([0x01, 0x02, 0x03]), byteOrder: .bigEndian)
        #expect(try reader.readUInt24() == 0x01_0203)
    }

    @Test func throwsInsteadOfReadingPastTheEnd() {
        var reader = ByteReader(Data([1, 2, 3]), byteOrder: .littleEndian)
        #expect(throws: EndOfDataError(offset: 0, needed: 4, available: 3)) {
            try reader.readUInt32()
        }
        #expect(reader.offset == 0, "a failed read must not move the position")
    }

    @Test func readsUpToTheEndLikeDotNet() {
        var reader = ByteReader(Data([1, 2, 3]), byteOrder: .littleEndian)
        #expect(reader.readBytes(upTo: 10) == Data([1, 2, 3]))
        #expect(reader.remaining == 0)
    }

    @Test func rebasesDataSlices() throws {
        let slice = Data([9, 9, 0x2A, 0x00])[2...]
        var reader = ByteReader(slice, byteOrder: .littleEndian)
        #expect(try reader.readUInt16() == 42)
    }

    @Test func decodesASCIIWithDotNetReplacement() throws {
        var reader = ByteReader(Data([0x41, 0xE9, 0x00, 0x42]), byteOrder: .littleEndian)
        #expect(try reader.readASCII(length: 4) == "A?\0B")
    }
}
