import Foundation
import Testing
import TSOFiles

/// Streams are built by hand from the command layouts in `Decompresser.cs`.
@Suite struct RefPackTests {
    @Test func expandsAShortBackReference() throws {
        // 0x0E: 2 literal bytes, copy 6 from 2 back (0x00-0x7F form). Padded past 6 bytes with 0xFC.
        let stream = Data([0x0E, 0x01, 0x61, 0x62, 0xFC, 0x00, 0x00])
        let output = try RefPack.decompress(stream, decompressedSize: 8)
        #expect(String(decoding: output, as: UTF8.self) == "abababab")
    }

    @Test func expandsAMediumBackReference() throws {
        // 0x82 0xC0 0x02: 3 literal bytes, copy 6 from 3 back (0x80-0xBF form).
        let stream = Data([0x82, 0xC0, 0x02, 0x61, 0x62, 0x63, 0xFC])
        let output = try RefPack.decompress(stream, decompressedSize: 9)
        #expect(String(decoding: output, as: UTF8.self) == "abcabcabc")
    }

    @Test func expandsALongBackReference() throws {
        // 0xC1 0x00 0x00 0x00: 1 literal byte, copy 5 from 1 back (0xC0-0xDF form).
        let stream = Data([0xC1, 0x00, 0x00, 0x00, 0x7A, 0xFC, 0x00])
        let output = try RefPack.decompress(stream, decompressedSize: 6)
        #expect(String(decoding: output, as: UTF8.self) == "zzzzzz")
    }

    @Test func continuesAfterFDAndStopsAtFC() throws {
        // 0xE0: 4 literal bytes. 0xFD: 1 more literal and keep going. 0xFC: end, so 0xFF is never read.
        let stream = Data([0xE0, 0x31, 0x32, 0x33, 0x34, 0xFD, 0x35, 0xFC, 0xFF])
        let output = try RefPack.decompress(stream, decompressedSize: 6)
        #expect(output == Data("12345".utf8) + [0x00], "unwritten output stays zero")
    }

    @Test func returnsShortInputUnchanged() throws {
        let stream = Data([0x0E, 0x01, 0x61, 0x62])
        #expect(try RefPack.decompress(stream, decompressedSize: 8) == stream)
    }

    @Test func growsOutputPastTheDeclaredSize() throws {
        let stream = Data([0xE0, 0x31, 0x32, 0x33, 0x34, 0xFC, 0x00])
        #expect(try RefPack.decompress(stream, decompressedSize: 2).count == 4)
    }

    @Test func rejectsABackReferenceBeforeTheStart() {
        let stream = Data([0x0E, 0x05, 0x61, 0x62, 0xFC, 0x00, 0x00])
        #expect(throws: RefPackError.invalidBackReference(offset: 6, outputPosition: 2)) {
            try RefPack.decompress(stream, decompressedSize: 8)
        }
    }

    @Test func rejectsATruncatedLiteralRun() {
        let stream = Data([0xE4, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36])
        #expect(throws: RefPackError.truncatedInput(offset: 1)) {
            try RefPack.decompress(stream, decompressedSize: 8)
        }
    }
}
