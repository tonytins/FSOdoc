import Foundation
import Testing
import SimAntics
@testable import SimsScript

/// Attributes after initialize runs (and `ticks` ticks of main).
func attributes(after source: String, ticks: Int = 0) throws -> [Int16] {
    var result: [Int16] = []
    try run(source, ticks: ticks) { vm, entity throws in
        #expect(vm.reportedErrors.isEmpty, "\(vm.reportedErrors)")
        result = entity.attributes
    }
    return result
}

@Suite struct CompilerTests {
    @Test func runsTheExampleFromTheDocumentation() throws {
        let source = """
            integer count;

            add(integer amount) {
                count += amount;
            }

            default {
                initialize() { count = 0; }
                main() {
                    integer i = 3;
                    while (i > 0) { add(2); i -= 1; }
                    if (count >= 6 && !(count == 7)) { count += 100; }
                }
            }
            """
        // Main runs once per tick and returns, so it runs again each tick.
        #expect(try attributes(after: source, ticks: 1) == [106])
        #expect(try attributes(after: source, ticks: 2) == [212])
    }

    @Test(arguments: [
        ("a = 2 + 3 * 4;", 14), ("a = (2 + 3) * 4;", 20), ("a = 20 - 3 - 2;", 15), ("a = 7 / 0;", -1),
        ("a = 7 % 0;", 7), ("a = -7 % 3;", 2), ("a = 6 & 3;", 2), ("a = -(4 + 1);", -5), ("a = 32767 + 1;", -32768),
        ("a = -32768;", -32768), ("b = 10; a = b - (a + b);", 0), ("a = 5; a = 1 - a;", -4),
    ])
    func computesLikeSimAntics(statements: String, result: Int16) throws {
        let values = try attributes(after: "integer a; integer b; default { initialize() { \(statements) } }")
        #expect(values.first == result)
    }

    @Test(arguments: [
        ("1 < 2 && 2 < 3", true), ("1 < 2 && 3 < 2", false), ("2 < 1 || 2 < 3", true), ("2 < 1 || 3 < 2", false),
        ("!(1 == 1)", false), ("!(1 != 1) && (1 >= 1 || 0)", true), ("TRUE", true), ("FALSE", false), ("0", false),
        ("5", true), ("x", false), ("x + 1", true), ("yes()", true), ("no()", false), ("!no() && yes()", true),
    ])
    func branchesLikeConditionsShould(condition: String, isTrue: Bool) throws {
        let source = """
            integer result; integer x;
            yes() { return TRUE; }
            no() { return FALSE; }
            default { initialize() { if (\(condition)) { result = 1; } else { result = 2; } } }
            """
        #expect(try attributes(after: source).first == (isTrue ? 1 : 2))
    }

    @Test func passesVariableArgumentsThroughTemps() throws {
        let source = """
            integer total;
            add3(integer a, integer b, integer c) { total = a * 100 + b * 10 + c; }
            default { initialize() { integer x = 4; add3(x + 1, -1, 0); } }
            """
        #expect(try attributes(after: source).first == 490)
        let literal = "integer total; one(integer a) { total = a; } default { initialize() { one(7); } }"
        #expect(try attributes(after: literal).first == 7)
    }

    @Test func returnsBeforeAnyInstructionWithoutRunningWhatFollows() throws {
        #expect(try attributes(after: "integer a; default { initialize() { return; a = 5; } }") == [])
        #expect(try attributes(after: "integer a; default { initialize() { if (FALSE) { a = 1; } a += 10; } }").first == 10)
        #expect(try attributes(after: "integer a; default { initialize() { while (a < 3) { a += 1; } } }").first == 3)
    }

    @Test func writesTheCompiledRoutinesAsAssembly() throws {
        let compiled = try ScriptCompiler.compile("integer a; default { main() { if (a < 2) { a += 1; } } }")
        #expect(compiled.entryPoints[Entity.EntryPointIndex.main.rawValue] == 4096)
        #expect(compiled.assembly == """
            bhav 4096 "main" version 0x8002 type 0 arguments 0 locals 0 flags 0x0000
              0: expression myObjectAttributes 0 < literal 2 -> 1 / return-true
              1: expression myObjectAttributes 0 += literal 1 -> return-true / return-true

            """)
    }

    @Test(arguments: [
        ("default { initialize() { a = 1; } }", 1, 26, "a isn't declared"),
        ("f(integer a, integer b, integer c, integer d, integer e) { } default { }", 1, 1, "a function takes at most 4 parameters"),
        ("f(integer a) { } default { initialize() { f(); } }", 1, 43, "f takes 1 arguments, not 0"),
        ("default { jump() { } }", 1, 11, "jump isn't an event; events are" ),
        ("integer a; default { initialize() { a = 1 < 2; } }", 1, 43, "< gives true or false; use it in an if or while"),
        ("integer a; default { initialize() { a = 40000; } }", 1, 41, "40000 is out of range"),
        ("integer a; default { initialize() { a = 1 } }", 1, 43, "expected ;, found }"),
        ("integer a;", 1, 11, "a script needs a default block with its events"),
    ])
    func reportsMistakesWhereTheyAre(source: String, line: Int, column: Int, message: String) {
        do {
            _ = try ScriptCompiler.compile(source)
            Issue.record("expected an error")
        } catch {
            #expect(error.line == line && error.column == column, "\(error)")
            #expect(error.message.hasPrefix(message), "\(error)")
        }
    }

    @Test func rejectsARoutineTooLongForSimAntics() {
        let body = String(repeating: "a += 1; ", count: 260)
        #expect(throws: ScriptError.self) { try ScriptCompiler.compile("integer a; default { initialize() { \(body) } }") }
    }
}
