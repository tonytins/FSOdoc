import Foundation
import SimAntics
import TSOContent
import TSOFiles

/// A temporary folder laid out like an install, deleted when released.
final class FakeInstall {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("simantics-\(UUID().uuidString)", isDirectory: true)
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

struct ChunkFixture {
    var type: String
    var id: UInt16
    var label: String = ""
    var contents: Data
}

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

/// A FAR 1b archive (TSO's layout).
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

/// An object definition (version 142) with a GUID and any other words set (word 3 is main, 41 init, 50 cleanup).
func objdChunk(label: String, guid: UInt32, words: [Int: UInt16] = [:]) -> ChunkFixture {
    var writer = ByteWriter()
    writer.uint32(142)
    for index in 0..<103 { // version 142 has 105 fields; the version takes the first two
        switch index {
        case 12: writer.uint16(UInt16(truncatingIfNeeded: guid))
        case 13: writer.uint16(UInt16(truncatingIfNeeded: guid >> 16))
        default: writer.uint16(words[index] ?? 0)
        }
    }
    return ChunkFixture(type: "OBJD", id: 128, label: label, contents: writer.bytes)
}

/// One instruction to write into a BHAV.
struct InstructionFixture {
    var opcode: UInt16
    var truePointer: UInt8 = 254
    var falsePointer: UInt8 = 255
    var operand: [UInt8] = []
}

/// A routine (BHAV version 0x8002).
func bhavChunk(id: UInt16, arguments: UInt8 = 4, locals: UInt16 = 0, _ instructions: [InstructionFixture]) -> ChunkFixture {
    var writer = ByteWriter()
    writer.uint16(0x8002)
    writer.uint16(UInt16(instructions.count))
    writer.uint8(0)          // type
    writer.uint8(arguments)
    writer.uint16(locals)
    writer.uint16(0)         // flags
    writer.raw([0, 0])
    for instruction in instructions {
        writer.uint16(instruction.opcode)
        writer.uint8(instruction.truePointer)
        writer.uint8(instruction.falsePointer)
        writer.raw(instruction.operand + [UInt8](repeating: 0, count: 8 - instruction.operand.count))
    }
    return ChunkFixture(type: "BHAV", id: id, label: "routine \(id)", contents: writer.bytes)
}

func bconChunk(id: UInt16, _ constants: [UInt16]) -> ChunkFixture {
    var writer = ByteWriter()
    writer.uint8(UInt8(constants.count))
    writer.uint8(0)
    for constant in constants { writer.uint16(constant) }
    return ChunkFixture(type: "BCON", id: id, contents: writer.bytes)
}

func otf(_ tables: [(id: Int, keys: [(id: Int, value: Int)])]) -> Data {
    let body = tables.map { table in
        #"<T i="\#(table.id)" n="t">"# + table.keys.map { #"<K i="\#($0.id)" l="k" v="\#($0.value)"/>"# }.joined() + "</T>"
    }.joined()
    return Data(#"<?xml version="1.0"?><O>\#(body)</O>"#.utf8)
}

/// An Expression operand.
func expression(_ operator: Primitives.Expression.Operator, _ lhs: VariableScope, _ lhsData: Int16,
                _ rhs: VariableScope, _ rhsData: Int16) -> [UInt8] {
    var writer = ByteWriter()
    writer.int16(lhsData)
    writer.int16(rhsData)
    writer.uint8(0)
    writer.uint8(`operator`.rawValue)
    writer.uint8(lhs.rawValue)
    writer.uint8(rhs.rawValue)
    return [UInt8](writer.bytes)
}

/// A subroutine call operand.
func call(_ arguments: [Int16]) -> [UInt8] {
    var writer = ByteWriter()
    for argument in arguments { writer.int16(argument) }
    return [UInt8](writer.bytes)
}

/// The test object's GUID; it uses the semi-global `testglobals`.
let chairGUID: UInt32 = 0x100

/// Builds an install with one object (`chair`), its semi-global, and the global, loads
/// it, and runs `body` with a VM holding the chair as object 1. The install lives until `body` returns.
func withVM(chair: [ChunkFixture] = [], chairWords: [Int: UInt16] = [:], chairOTF: Data? = nil,
            semiGlobal: [ChunkFixture] = [], global: [ChunkFixture] = [], seed: UInt64 = 1,
            _ body: (VM, Entity) throws -> Void) throws {
    let install = try FakeInstall()
    try install.write(Data(#"<ObjectInfoTable><I g="0x100" n="chair" m="0" i="0"/></ObjectInfoTable>"#.utf8),
                      to: "packingslips/objecttable.xml")
    let chairIFF = makeIFF([objdChunk(label: "chair", guid: chairGUID, words: chairWords),
                            ChunkFixture(type: "GLOB", id: 128, contents: Data("testglobals\0".utf8))] + chair)
    try install.write(makeFAR1([(name: "chair.iff", contents: chairIFF)]), to: "objectdata/objects/objiff.far")
    try install.write(makeFAR1(chairOTF.map { [(name: "chair.otf", contents: $0)] } ?? []),
                      to: "objectdata/objects/objotf.far")
    try install.write(makeIFF(semiGlobal), to: "objectdata/globals/testglobals.iff")
    try install.write(makeIFF(global), to: "objectdata/globals/global.iff")
    try withExtendedLifetime(install) {
        let vm = try VM(content: try GameContent(.init(gameDirectory: install.root)), seed: seed)
        try body(vm, try vm.addObject(guid: chairGUID, id: 1))
    }
}

extension VM {
    /// A one-instruction routine for a primitive, pushed onto `caller`'s thread, as
    /// `fso-oracle run-primitive` builds it.
    func makePrimitiveFrame(opcode: UInt8, operand: [UInt8], caller: Entity, locals: [Int16] = [],
                            arguments: [Int16] = [0, 0, 0, 0],
                            stackObjectID: Int16 = 0) throws(SimAnticsError) -> (PrimitiveTable.Prepared, StackFrame) {
        guard case .primitive(let primitive) = primitives.decode(opcode: UInt16(opcode), operand: operand) else {
            throw .unsupported("opcode \(opcode)")
        }
        let routine = Routine(id: 4096, argumentCount: UInt16(arguments.count), localCount: UInt16(locals.count), instructions: [
            Instruction(index: 0, opcode: UInt16(opcode), truePointer: 254, falsePointer: 255, operand: .primitive(primitive)),
        ])
        let frame = StackFrame(thread: caller.thread, routine: routine, caller: caller, callee: caller,
                               codeOwner: caller.object)
        frame.locals = locals
        frame.arguments = arguments
        frame.stackObjectID = stackObjectID
        caller.thread.stack.append(frame)
        return (primitive, frame)
    }

    /// Runs one primitive directly on a fresh frame and returns its exit code and the frame.
    func runPrimitive(opcode: UInt8, operand: [UInt8], caller: Entity, locals: [Int16] = [],
                      arguments: [Int16] = [0, 0, 0, 0]) throws(SimAnticsError) -> (ExitCode, StackFrame) {
        let (primitive, frame) = try makePrimitiveFrame(opcode: opcode, operand: operand, caller: caller,
                                                        locals: locals, arguments: arguments)
        defer { caller.thread.stack.removeAll() }
        return (try primitive.execute(in: frame), frame)
    }
}
