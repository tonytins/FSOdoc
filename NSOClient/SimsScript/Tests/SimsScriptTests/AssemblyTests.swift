import Foundation
import Testing
import TSOFiles
@testable import SimsScript

let sampleRoutine = BHAV(id: 4096, label: "main \"quoted\"\u{1}", version: 0x8002, type: 3, argumentCount: 2, localCount: 5,
                         flags: 0x10, instructions: [
    BHAV.Instruction(opcode: 2, truePointer: 1, falsePointer: 255, operand: Data([0, 0, 5, 0, 0, 5, 8, 7])),
    BHAV.Instruction(opcode: 4097, truePointer: 254, falsePointer: 253, operand: Data([0xff, 0xff, 2, 0, 0, 0, 0, 0])),
    BHAV.Instruction(opcode: 44, truePointer: 2, falsePointer: 0, operand: Data([0x0a, 0, 0, 1, 0, 0, 0, 0])),
    BHAV.Instruction(opcode: 2, truePointer: 0, falsePointer: 0, operand: Data([1, 0, 2, 0, 9, 99, 3, 7])),
])

@Suite struct AssemblyTests {
    @Test func writesReadableText() {
        #expect(Assembly.text(of: sampleRoutine) == """
            bhav 4096 "main \\"quoted\\"\\u{1}" version 0x8002 type 3 arguments 2 locals 5 flags 0x0010
              0: expression temps 0 := literal 5 -> 1 / return-false
              1: call 4097 -1 2 0 0 -> return-true / follow
              2: primitive 44 0a00000100000000 -> 2 / 0
              3: expression myObject 1 op99 literal 2 signed 9 -> 0 / 0

            """)
    }

    @Test func readsBackWhatItWrites() throws {
        let routines = try Assembly.routines(from: Assembly.text(of: [sampleRoutine, sampleRoutine]))
        #expect(routines.count == 2)
        #expect(routines.allSatisfy { equal($0, sampleRoutine) })
    }

    @Test(arguments: [
        ("  0: expression temps 0 := literal 5 -> 1 / 2", 1, "an instruction outside a bhav"),
        ("bhav 1 \"x\" version 0x8002 type 0 arguments 0 locals 0 flags 0\n  1: call 300 0 0 0 0 -> 0 / 0", 2, "expected instruction 0:"),
        ("bhav 1 \"x\" version 0x8002 type 0 arguments 0 locals 0 flags 0\n  0: expression nowhere 0 := literal 5 -> 0 / 0", 2, "unknown scope nowhere"),
        ("bhav 1 \"x\" version 0x8002 type 0 arguments 0 locals 0 flags 0\n  0: call 300 0 0 0 0 -> 253 / 0", 2,
         "a branch target is 0 to 252, return-true, return-false, or follow"),
        ("bhav 1 x version 0x8002 type 0 arguments 0 locals 0 flags 0", 1, "expected a label in quotes"),
    ])
    func reportsMistakesWithTheirLine(text: String, line: Int, message: String) {
        #expect(throws: ScriptError.self) { try Assembly.routines(from: text) }
        do {
            _ = try Assembly.routines(from: text)
        } catch {
            #expect(error.line == line && error.message == message)
        }
    }
}

func equal(_ left: BHAV, _ right: BHAV) -> Bool {
    left.id == right.id && left.label == right.label && left.version == right.version && left.type == right.type
        && left.argumentCount == right.argumentCount && left.localCount == right.localCount && left.flags == right.flags
        && left.instructions == right.instructions
}
