import Foundation
import Testing
@testable import SimAntics

/// Runs an Expression on the test chair with the given temps, returning the exit code and temps after.
func evaluate(_ operator: Primitives.Expression.Operator, _ lhs: VariableScope, _ lhsData: Int16,
              _ rhs: VariableScope, _ rhsData: Int16, temps: [Int16] = [], tempXL: [Int32] = [],
              _ check: (ExitCode, VMThread) throws -> Void) throws {
    try withVM { vm, chair throws in
        for (index, value) in temps.enumerated() { chair.thread.tempRegisters[index] = value }
        for (index, value) in tempXL.enumerated() { chair.thread.tempXL[index] = value }
        let (exit, frame) = try vm.runPrimitive(opcode: 2, operand: expression(`operator`, lhs, lhsData, rhs, rhsData),
                                                caller: chair)
        try check(exit, frame.thread)
    }
}

@Suite struct ExpressionTests {
    @Test func assigns() throws {
        try evaluate(.assign, .temps, 0, .literal, 5) { exit, thread throws in
            #expect(exit == .gotoTrue)
            #expect(thread.tempRegisters[0] == 5)
        }
        try evaluate(.assign, .literal, 0, .literal, 5) { exit, _ throws in #expect(exit == .gotoFalse) }
    }

    @Test func truncatesToSixteenBitsAndKeepsThirtyTwoInTempXL() throws {
        try evaluate(.plusEquals, .temps, 0, .literal, 1, temps: [32767]) { _, thread throws in
            #expect(thread.tempRegisters[0] == -32768)
        }
        try evaluate(.multiplyEquals, .tempXL, 0, .literal, 1000, tempXL: [70_000]) { _, thread throws in
            #expect(thread.tempXL[0] == 70_000_000)
        }
        try evaluate(.multiplyEquals, .tempXL, 0, .literal, 2, tempXL: [Int32.max]) { _, thread throws in
            #expect(thread.tempXL[0] == -2) // wraps like C#'s unchecked int
        }
    }

    @Test(arguments: [
        (Primitives.Expression.Operator.divideEquals, Int16(7), Int16(0), Int16(-1)),
        (.divideEquals, -7, 2, -3),
        (.moduloEquals, 7, 0, 7),
        (.moduloEquals, -7, 3, 2),
        (.minusEquals, 3, 5, -2),
        (.andEquals, 6, 3, 2),
    ])
    func doesArithmeticLikeFreeSO(operator: Primitives.Expression.Operator, left: Int16, right: Int16, result: Int16) throws {
        try evaluate(`operator`, .temps, 0, .literal, right, temps: [left]) { exit, thread throws in
            #expect(exit == .gotoTrue)
            #expect(thread.tempRegisters[0] == result)
        }
    }

    @Test(arguments: [Primitives.Expression.Operator.divideEquals, .moduloEquals])
    func failsOnThirtyTwoBitOverflow(operator: Primitives.Expression.Operator) {
        #expect(throws: SimAnticsError.self) {
            try evaluate(`operator`, .tempXL, 0, .literal, -1, tempXL: [Int32.min]) { _, _ throws in }
        }
    }

    @Test func setsTestsAndClearsFlags() throws {
        try evaluate(.setFlag, .temps, 0, .literal, 3, temps: [1]) { _, thread throws in #expect(thread.tempRegisters[0] == 5) }
        try evaluate(.setFlag, .temps, 0, .literal, 33, temps: [0]) { _, thread throws in #expect(thread.tempRegisters[0] == 1) }
        try evaluate(.isFlagSet, .temps, 0, .literal, 3, temps: [4]) { exit, _ throws in #expect(exit == .gotoTrue) }
        try evaluate(.isFlagSet, .temps, 0, .literal, 2, temps: [4]) { exit, _ throws in #expect(exit == .gotoFalse) }
        try evaluate(.clearFlag, .temps, 0, .literal, 3, temps: [7]) { _, thread throws in #expect(thread.tempRegisters[0] == 3) }
    }

    @Test func clearFlagTruncatesItsMaskToSixteenBits() throws {
        // ~(1 << 16) truncated to 16 bits is -1, so clearing bit 17 of a TempXL clears nothing.
        try evaluate(.clearFlag, .tempXL, 0, .literal, 17, tempXL: [0x1_0001]) { _, thread throws in
            #expect(thread.tempXL[0] == 0x1_0001)
        }
        try evaluate(.clearFlag, .tempXL, 0, .literal, 1, tempXL: [0x1_0001]) { _, thread throws in
            #expect(thread.tempXL[0] == 0x1_0000)
        }
    }

    @Test func incrementsAndDecrementsBeforeComparing() throws {
        try evaluate(.incrementAndLessThan, .temps, 0, .literal, 5, temps: [3]) { exit, thread throws in
            #expect(exit == .gotoTrue && thread.tempRegisters[0] == 4)
        }
        try evaluate(.incrementAndLessThan, .temps, 0, .literal, 5, temps: [4]) { exit, _ throws in #expect(exit == .gotoFalse) }
        try evaluate(.decrementAndGreaterThan, .temps, 0, .literal, 0, temps: [1]) { exit, thread throws in
            #expect(exit == .gotoFalse && thread.tempRegisters[0] == 0)
        }
    }

    @Test(arguments: [
        (Primitives.Expression.Operator.greaterThan, Int16(2), Int16(1), true),
        (.lessThan, 2, 1, false), (.equals, 3, 3, true), (.notEqualTo, 3, 3, false),
        (.greaterThanOrEqualTo, 3, 3, true), (.lessThanOrEqualTo, 4, 3, false),
    ])
    func compares(operator: Primitives.Expression.Operator, left: Int16, right: Int16, isTrue: Bool) throws {
        try evaluate(`operator`, .temps, 0, .literal, right, temps: [left]) { exit, _ throws in
            #expect(exit == (isTrue ? .gotoTrue : .gotoFalse))
        }
    }

    @Test func pushesAndPopsTheList() throws {
        try withVM { vm, chair throws in
            func run(_ operand: [UInt8]) throws -> ExitCode { try vm.runPrimitive(opcode: 2, operand: operand, caller: chair).0 }
            #expect(try run(expression(.push, .myList, 1, .literal, 2)) == .gotoTrue)
            #expect(try run(expression(.push, .myList, 0, .literal, 1)) == .gotoTrue)
            #expect(try run(expression(.push, .myList, 7, .literal, 9)) == .gotoTrue) // does nothing
            #expect(chair.list == [1, 2])
            #expect(try run(expression(.pop, .temps, 0, .myList, 1)) == .gotoTrue)
            #expect(chair.thread.tempRegisters[0] == 2)
            chair.thread.tempRegisters[1] = 5
            #expect(try run(expression(.pop, .temps, 1, .myList, 7)) == .gotoTrue) // unknown source sets 0
            #expect(chair.thread.tempRegisters[1] == 0 && chair.list == [1])
            #expect(throws: SimAnticsError.simantics("Unknown list push destination: 2")) {
                try run(expression(.push, .myList, 2, .literal, 1))
            }
            _ = try run(expression(.pop, .temps, 0, .myList, 0))
            #expect(try run(expression(.pop, .temps, 0, .myList, 0)) == .gotoFalse)
        }
    }

    @Test func failsForAnUnknownOperator() throws {
        try withVM { vm, chair throws in
            var operand = expression(.assign, .temps, 0, .literal, 1)
            operand[5] = 20
            #expect(throws: SimAnticsError.simantics("Unknown expression type")) {
                try vm.runPrimitive(opcode: 2, operand: operand, caller: chair)
            }
        }
    }
}
