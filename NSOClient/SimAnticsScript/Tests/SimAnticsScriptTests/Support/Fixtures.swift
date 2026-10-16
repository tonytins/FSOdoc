import Foundation
import SimAntics
import SimAnticsScript
import TSOContent
import TSOFiles

/// A temporary folder laid out like an install, deleted when released.
final class FakeInstall {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("simanticsscript-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func write(_ data: Data, to relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}

func makeIFF(_ chunks: [(type: String, id: UInt16, label: String, contents: Data)]) -> Data {
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

func makeFAR1(_ files: [(name: String, contents: Data)]) -> Data {
    var writer = ByteWriter()
    writer.ascii("FAR!byAZ")
    writer.uint32(1)
    writer.uint32(0)
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

/// A version 142 OBJD that uses a function table (word 20), with GUID 0x100.
func functionTableOBJD() -> Data {
    var writer = ByteWriter()
    writer.uint32(142)
    for index in 0..<103 {
        switch index {
        case 12: writer.uint16(0x100)
        case 20: writer.uint16(1)
        default: writer.uint16(0)
        }
    }
    return writer.bytes
}

/// Compiles a script into an object, loads it in a VM, initializes it, ticks it, and runs
/// `check` on the entity while its install still exists.
func run(_ source: String, ticks: Int = 1, _ check: (VM, Entity) throws -> Void) throws {
    let compiled = try ScriptCompiler.compile(source)
    let install = try FakeInstall()
    try install.write(Data(#"<ObjectInfoTable><I g="0x100" n="scripted" m="0" i="0"/></ObjectInfoTable>"#.utf8),
                      to: "packingslips/objecttable.xml")
    let iff = makeIFF([("OBJD", 128, "scripted", functionTableOBJD()), ("OBJf", 128, "", compiled.functionTableData())]
                      + compiled.routines.map { ("BHAV", $0.id, $0.label, $0.encoded()) })
    try install.write(makeFAR1([(name: "scripted.iff", contents: iff)]), to: "objectdata/objects/objiff.far")
    try install.write(makeFAR1([]), to: "objectdata/objects/objotf.far")
    try install.write(makeIFF([]), to: "objectdata/globals/global.iff")
    try withExtendedLifetime(install) {
        let vm = try VM(content: try GameContent(.init(gameDirectory: install.root)), seed: 1)
        let entity = try vm.addObject(guid: 0x100, id: 1)
        try entity.initialize()
        for _ in 0..<ticks { vm.tick() }
        try check(vm, entity)
    }
}
