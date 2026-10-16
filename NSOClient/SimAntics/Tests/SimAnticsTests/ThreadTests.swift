import Foundation
import Testing
@testable import SimAntics

/// Pushes routine `id` of the chair onto its thread and ticks once.
func runRoutine(_ id: UInt16, on vm: VM, _ chair: Entity) throws -> VMThread {
    let routine = try #require(try vm.routine(opcode: id, codeOwner: chair.object))
    chair.thread.push(StackFrame(thread: chair.thread, routine: routine, caller: chair, callee: chair,
                                 codeOwner: chair.object))
    chair.thread.tick()
    return chair.thread
}

func setTemp(_ index: Int16, to value: Int16, true truePointer: UInt8 = 254, false falsePointer: UInt8 = 255) -> InstructionFixture {
    InstructionFixture(opcode: 2, truePointer: truePointer, falsePointer: falsePointer,
                       operand: expression(.assign, .temps, index, .literal, value))
}

@Suite struct ThreadTests {
    @Test func runsARoutineToItsReturn() throws {
        try withVM(chair: [bhavChunk(id: 4096, [
            setTemp(0, to: 1, true: 1),
            InstructionFixture(opcode: 2, truePointer: 254, operand: expression(.plusEquals, .temps, 0, .literal, 1)),
        ])]) { vm, chair throws in
            let thread = try runRoutine(4096, on: vm, chair)
            #expect(thread.tempRegisters[0] == 2)
            #expect(thread.stack.isEmpty && thread.lastExitCode == .returnTrue && thread.lastError == nil)
        }
    }

    @Test func takesTheFalseBranch() throws {
        try withVM(chair: [bhavChunk(id: 4096, [
            InstructionFixture(opcode: 2, truePointer: 1, falsePointer: 2, operand: expression(.equals, .literal, 1, .literal, 2)),
            setTemp(0, to: 10),
            setTemp(0, to: 20, true: 255),
        ])]) { vm, chair throws in
            let thread = try runRoutine(4096, on: vm, chair)
            #expect(thread.tempRegisters[0] == 20 && thread.lastExitCode == .returnFalse)
        }
    }

    @Test func followsTheOtherBranchFrom253() throws {
        try withVM(chair: [bhavChunk(id: 4096, [
            InstructionFixture(opcode: 2, truePointer: 253, falsePointer: 1, operand: expression(.equals, .literal, 1, .literal, 1)),
            setTemp(0, to: 3),
        ])]) { vm, chair throws in
            #expect(try runRoutine(4096, on: vm, chair).tempRegisters[0] == 3)
        }
    }

    @Test func callsTheGlobalPrivateAndSemiGlobalWithArguments() throws {
        let copyArgument = { (id: UInt16, temp: Int16) in
            bhavChunk(id: id, [InstructionFixture(opcode: 2, operand: expression(.assign, .temps, temp, .parameters, 0))])
        }
        try withVM(chair: [bhavChunk(id: 4096, [
            InstructionFixture(opcode: 256, truePointer: 1, operand: call([7, 0, 0, 0])),
            InstructionFixture(opcode: 4097, truePointer: 2, operand: call([8, 0, 0, 0])),
            InstructionFixture(opcode: 8192, truePointer: 254, operand: call([-1, 1, 0, 0])),
        ]), copyArgument(4097, 2)], semiGlobal: [copyArgument(8192, 3)], global: [copyArgument(256, 1)]) { vm, chair throws in
            chair.thread.tempRegisters[0] = 9
            let thread = try runRoutine(4096, on: vm, chair)
            #expect(thread.lastError == nil)
            #expect(Array(thread.tempRegisters[1...3]) == [7, 8, 9]) // -1 took temp 0 because argument 1 isn't 0
        }
    }

    @Test func unwindsTheWholeStackWhenACalledRoutineIsMissing() throws {
        try withVM(chair: [
            bhavChunk(id: 4096, [InstructionFixture(opcode: 4097, operand: call([0, 0, 0, 0])), setTemp(0, to: 1)]),
            bhavChunk(id: 4097, [InstructionFixture(opcode: 4200, operand: call([0, 0, 0, 0]))]),
        ]) { vm, chair throws in
            let thread = try runRoutine(4096, on: vm, chair)
            #expect(thread.stack.isEmpty && thread.lastExitCode == .error)
            #expect(thread.tempRegisters[0] == 0)
        }
    }

    @Test func givesLocalsTheLargerOfTheLocalAndArgumentCounts() throws {
        try withVM(chair: [
            bhavChunk(id: 4096, [InstructionFixture(opcode: 4097, operand: call([0, 0, 0, 0]))]),
            bhavChunk(id: 4097, arguments: 6, locals: 2, [
                InstructionFixture(opcode: 2, truePointer: 1, operand: expression(.assign, .local, 5, .literal, 1)),
                InstructionFixture(opcode: 2, operand: expression(.assign, .temps, 0, .parameters, 5)),
            ]),
        ]) { vm, chair throws in
            chair.thread.tempRegisters[0] = 4
            let thread = try runRoutine(4096, on: vm, chair)
            #expect(thread.lastError == nil)
            #expect(thread.tempRegisters[0] == -1) // arguments past 3 are -1
        }
    }

    @Test func stopsARoutineThatCallsAnEmptyRoutineForever() throws {
        // 2017 never pushes an empty routine, so the call repeats until the loop guard.
        try withVM(chair: [
            bhavChunk(id: 4096, [InstructionFixture(opcode: 4097, operand: call([0, 0, 0, 0]))]),
            bhavChunk(id: 4097, []),
        ]) { vm, chair throws in
            let thread = try runRoutine(4096, on: vm, chair)
            #expect(thread.lastError == .infiniteLoop && thread.stack.isEmpty)
        }
    }

    @Test func treatsAMissingPrimitiveAsTrue() throws {
        try withVM(chair: [bhavChunk(id: 4096, [
            InstructionFixture(opcode: 250, truePointer: 1, falsePointer: 255),
            setTemp(0, to: 6),
        ])]) { vm, chair throws in
            #expect(try runRoutine(4096, on: vm, chair).tempRegisters[0] == 6)
        }
    }
}
