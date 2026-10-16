import Foundation
import TSOFiles

/// A temporary folder laid out like an install, deleted when released.
final class FakeInstall {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tsocontent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func write(_ data: Data, to relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return url
    }

    func write(_ text: String, to relativePath: String) throws {
        try write(Data(text.utf8), to: relativePath)
    }
}

struct ChunkFixture {
    var type: String
    var id: UInt16
    var label: String = ""
    var contents: Data
}

/// Builds an IFF 2.5 file.
func makeIFF(_ chunks: [ChunkFixture]) -> Data {
    var writer = ByteWriter(bigEndian: true)
    writer.ascii("IFF FILE 2.5:TYPE FOLLOWED BY SIZE\0 JAMIE DOORNBOS & MAXIS 1", paddedTo: 60)
    writer.uint32(0)
    for chunk in chunks {
        writer.ascii(chunk.type, paddedTo: 4)
        writer.uint32(UInt32(chunk.contents.count + 76)) // the 76-byte chunk header counts toward the size
        writer.uint16(chunk.id)
        writer.uint16(0x10)
        writer.ascii(chunk.label, paddedTo: 64)
        writer.raw(chunk.contents)
    }
    return writer.bytes
}

/// Builds a FAR 1b archive (TSO's layout): header, file data, then the manifest.
func makeFAR1(_ files: [(name: String, contents: Data)]) -> Data {
    var writer = ByteWriter()
    writer.ascii("FAR!byAZ")
    writer.uint32(1)
    writer.uint32(0) // manifest offset, patched below
    var offsets: [Int] = []
    for file in files {
        offsets.append(writer.count)
        writer.raw(file.contents)
    }
    writer.patchUInt32(UInt32(writer.count), at: 12)
    writer.uint32(UInt32(files.count))
    for (file, offset) in zip(files, offsets) {
        writer.int32(Int32(file.contents.count))
        writer.int32(Int32(file.contents.count))
        writer.int32(Int32(offset))
        writer.int16(Int16(file.name.utf8.count))
        writer.ascii(file.name)
    }
    return writer.bytes
}

/// An object definition chunk (version 142) with the fields the provider reads.
func objdChunk(id: UInt16 = 128, label: String, guid: UInt32, masterID: UInt16 = 0, subIndex: Int16 = 0) -> ChunkFixture {
    var writer = ByteWriter()
    writer.uint32(142)
    for index in 0..<103 { // version 142 has 105 fields; the version takes the first two
        switch index {
        case 8: writer.uint16(masterID)
        case 9: writer.int16(subIndex)
        case 12: writer.uint16(UInt16(truncatingIfNeeded: guid))
        case 13: writer.uint16(UInt16(truncatingIfNeeded: guid >> 16))
        default: writer.uint16(0)
        }
    }
    return ChunkFixture(type: "OBJD", id: id, label: label, contents: writer.bytes)
}

/// An empty routine (BHAV version 0x8002).
func bhavChunk(id: UInt16, label: String) -> ChunkFixture {
    var writer = ByteWriter()
    writer.uint16(0x8002)
    writer.uint16(0) // instruction count
    writer.raw([0, 0, 0, 0, 0, 0, 0, 0])
    return ChunkFixture(type: "BHAV", id: id, label: label, contents: writer.bytes)
}

/// A semi-global name as a C string.
func globChunk(_ name: String) -> ChunkFixture {
    ChunkFixture(type: "GLOB", id: 128, contents: Data((name + "\0").utf8))
}

/// An OTF with one table holding one key.
func otf(tableID: Int, value: Int) -> Data {
    Data(#"<?xml version="1.0"?><O><T i="\#(tableID)" n="table"><K i="0" l="key" v="\#(value)"/></T></O>"#.utf8)
}

/// A PIFF patch file that changes nothing in `source` and adds `chunks`.
func addingPatch(source: String, chunks: [ChunkFixture]) -> Data {
    var writer = ByteWriter()
    writer.uint16(1) // version
    writer.uint8(UInt8(source.utf8.count))
    writer.ascii(source)
    writer.uint16(0) // entry count
    return makeIFF([ChunkFixture(type: "PIFF", id: 1, contents: writer.bytes)] + chunks)
}

/// An object table line.
func tableEntry(guid: UInt32, file: String, name: String? = nil, group: Int16 = 0, subIndex: Int16 = 0) -> String {
    let nameAttribute = name.map { #" o="\#($0)""# } ?? ""
    return #"<I g="0x\#(String(guid, radix: 16, uppercase: true))" n="\#(file)"\#(nameAttribute) m="\#(group)" f="0" i="\#(subIndex)" l="0"></I>"#
}

func objectTable(_ entries: [String]) -> String {
    "<ObjectInfoTable>\n" + entries.joined(separator: "\n") + "\n</ObjectInfoTable>"
}
