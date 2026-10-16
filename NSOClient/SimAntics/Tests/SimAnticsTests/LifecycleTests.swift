import Foundation
import Testing
import TSOFiles
@testable import SimAntics

/// OBJD words for the entry points these tests use.
let mainWord = 3, initWord = 41, cleanupWord = 50

func addToAttribute(_ index: Int16, _ amount: Int16, true truePointer: UInt8 = 254) -> InstructionFixture {
    InstructionFixture(opcode: 2, truePointer: truePointer, operand: expression(.plusEquals, .myObjectAttributes, index, .literal, amount))
}

@Suite struct SchedulerTests {
    @Test func keepsListsInObjectIDOrder() throws {
        try withVM { vm, chair throws in
            for id in [5, 3, 2, 4] as [Int16] { try vm.addObject(guid: chairGUID, id: id) }
            #expect(vm.entities.map(\.objectID) == [1, 2, 3, 4, 5])
            for entity in vm.entities.reversed() { vm.scheduler.scheduleTick(for: entity, in: 2) }
            #expect(vm.scheduler.scheduledObjectIDs(on: 2) == [1, 2, 3, 4, 5])
            #expect(chair.thread.scheduledTick == 2)
        }
    }
}

@Suite struct LifecycleTests {
    @Test func initializeRunsInitToCompletionAndPushesMain() throws {
        try withVM(chair: [
            bhavChunk(id: 4096, [addToAttribute(0, 1)]),
            bhavChunk(id: 4097, [InstructionFixture(opcode: 2, truePointer: 1, operand: expression(.assign, .temps, 0, .literal, 9)),
                                 addToAttribute(1, 5)]),
        ], chairWords: [mainWord: 4096, initWord: 4097]) { vm, chair throws in
            try chair.initialize()
            #expect(chair.attributes == [0, 5])            // init ran to completion
            #expect(chair.thread.tempRegisters[0] == 0)    // on a copy of the temps, outside a tick
            #expect(chair.thread.stack.map(\.routine.id) == [4096])
            #expect(vm.scheduler.scheduledObjectIDs(on: 1) == [1])
        }
    }

    @Test func runsMainAgainEachTickAfterItReturns() throws {
        try withVM(chair: [bhavChunk(id: 4096, [addToAttribute(0, 1)])], chairWords: [mainWord: 4096]) { vm, chair throws in
            try chair.initialize()
            for _ in 0..<3 { vm.tick() }
            #expect(chair.attribute(at: 0) == 3)
            #expect(vm.scheduler.currentTick == 3)
            #expect(vm.scheduler.scheduledObjectIDs(on: 4) == [1])
            #expect(vm.reportedErrors.isEmpty)
        }
    }

    @Test func advancesTheClockGlobalsAndSeedEachTick() throws {
        try withVM(seed: 10) { vm, _ throws in
            for _ in 0..<150 { vm.tick() }
            #expect(vm.clock.minutes == 1 && vm.clock.minuteFractions == 0)
            #expect(vm.globalState[5] == 1 && vm.globalState[6] == 0)
            #expect(vm.random.seed == 10 + 150) // one entity: the seed rises by 1 a tick
            vm.tick()
            #expect(vm.globalState[6] == 0) // 1 * 60 / 150 rounds down
        }
    }

    @Test func resetsAFailingEntityAndReportsOnlyOnceInTheCooldown() throws {
        var failing = expression(.assign, .temps, 0, .literal, 1)
        failing[5] = 20 // no such operator
        try withVM(chair: [
            bhavChunk(id: 4096, [InstructionFixture(opcode: 2, operand: failing)]),
            bhavChunk(id: 4098, [addToAttribute(2, 1)]),
        ], chairWords: [mainWord: 4096, cleanupWord: 4098]) { vm, chair throws in
            try chair.initialize()
            vm.tick()
            #expect(vm.reportedErrors == [.init(objectID: 1, tick: 1, error: .simantics("Unknown expression type"))])
            // Cleanup ran twice: 2017 resets the callee and then the caller, here the same entity.
            #expect(chair.attribute(at: 2) == 2)
            #expect(chair.thread.stack.map(\.routine.id) == [4096])  // and main was pushed again
            vm.tick()
            // Failing again within 10 ticks: 2017 deletes the object, which isn't ported yet.
            #expect(vm.reportedErrors.count == 2)
            #expect(vm.reportedErrors.last?.error == .unsupported("deleting an object that keeps failing"))
        }
    }

    @Test func returnsWhetherAnImmediateEntryPointReturnedTrue() throws {
        try withVM(chair: [
            bhavChunk(id: 4097, [InstructionFixture(opcode: 2, truePointer: 254, falsePointer: 255,
                                                    operand: expression(.equals, .parameters, 0, .literal, 1))]),
        ], chairWords: [initWord: 4097]) { _, chair throws in
            #expect(try chair.executeEntryPoint(.initialize, runImmediately: true, arguments: [1, 0, 0, 0]))
            #expect(try !chair.executeEntryPoint(.initialize, runImmediately: true, arguments: [2, 0, 0, 0]))
            #expect(try !chair.executeEntryPoint(.main, runImmediately: true)) // no routine
        }
    }

    @Test func startsWithTheChairFacingFlag() throws {
        try withVM { _, chair throws in #expect(chair.objectData[8] == 256) }
    }
}

@Suite struct DefinitionVariableTests {
    @Test func keepsThe2017Quirks() throws {
        try withVM(chairWords: [52: 77]) { _, chair throws in
            let definition = chair.object.definition
            #expect(try DefinitionVariable.value(DefinitionVariable.guid1.rawValue, of: definition) == Int16(0x100 % 0xFFFF))
            #expect(try DefinitionVariable.value(DefinitionVariable.ratingComfort.rawValue, of: definition) == 77)
            #expect(try DefinitionVariable.value(DefinitionVariable.servingSurfaceTreeID.rawValue, of: definition) == 77)
            #expect(try DefinitionVariable.value(97, of: definition) == 0)
            #expect(throws: SimAnticsError.simantics("Not Implemented!")) {
                try DefinitionVariable.value(DefinitionVariable.portalTreeID.rawValue, of: definition)
            }
        }
    }
}

@Suite struct StateDigestTests {
    /// FIPS 180-4 test vectors.
    @Test(arguments: [
        ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
        ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
    ])
    func hashesLikeSHA256(message: String, digest: String) {
        let bytes = SHA256.hash(Array(message.utf8))
        #expect(bytes.map { String(format: "%02x", $0) }.joined() == digest)
    }

    @Test func hashesAMillionAs() {
        let bytes = SHA256.hash([UInt8](repeating: 0x61, count: 1_000_000))
        #expect(bytes.map { String(format: "%02x", $0) }.joined() == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    @Test func writesTheVersion0Layout() throws {
        try withVM(seed: 0x0102) { vm, _ throws in
            let bytes = StateDigest.bytes(of: vm)
            #expect(Array(bytes.prefix(12)) == [0x02, 0x01, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]) // seed, entity count
            #expect(Array(bytes[12..<14]) == [1, 0])           // object ID
            #expect(Array(bytes[14..<18]) == [0, 1, 0, 0])     // GUID 0x100
            #expect(Array(bytes[18..<24]) == [0, 0x80, 0, 0x80, 1, 1]) // out of the world, facing north
            #expect(bytes.count == 12 + 2 + 4 + 4 + 1 + 1 + 4 + 160 + 4)
        }
    }
}

@Suite struct SleepTests {
    /// main: parameter 0 := 2, sleep on it, then attribute 0 += 1.
    let main = bhavChunk(id: 4096, [
        InstructionFixture(opcode: 2, truePointer: 1, operand: expression(.assign, .parameters, 0, .literal, 2)),
        InstructionFixture(opcode: 0, truePointer: 2, falsePointer: 255, operand: [0, 0]),
        addToAttribute(0, 1),
    ])

    @Test func wakesWhenTheCountReachesMinusOne() throws {
        try withVM(chair: [main], chairWords: [mainWord: 4096]) { vm, chair throws in
            try chair.initialize()
            vm.tick() // sets 2, sleeps: 2 - 1 = 1, so it runs again on tick 1 + 1 + 1
            #expect(vm.scheduler.scheduledObjectIDs(on: 3) == [1])
            #expect(chair.thread.stack.last?.arguments.first == 1)
            vm.tick()
            #expect(chair.attribute(at: 0) == 0)
            let seed = vm.random.seed
            vm.tick() // 1 - (3 - 1) = -1: awake
            #expect(chair.attribute(at: 0) == 1)
            #expect(vm.random.seed != seed) // the wake draws a random number
            #expect(vm.reportedErrors.isEmpty)
        }
    }

    @Test func endsAtOnceWhenInterrupted() throws {
        try withVM(chair: [main], chairWords: [mainWord: 4096]) { vm, chair throws in
            try chair.initialize()
            vm.tick()
            chair.thread.isInterrupted = true
            vm.scheduler.scheduleTick(for: chair, in: 1)
            vm.tick()
            #expect(chair.attribute(at: 0) == 1)
            #expect(!chair.thread.isInterrupted && chair.thread.idleStartTick == 0)
        }
    }
}

@Suite struct TestObjectTypeTests {
    func test(guid: UInt32, id: Int16) throws -> ExitCode {
        var exit = ExitCode.error
        try withVM { vm, chair throws in
            let operand = Primitives.TestObjectType.Operand(guid: guid, idScope: VariableScope.literal.rawValue, idData: id)
            exit = try vm.runPrimitive(opcode: 32, operand: operand.encoded(), caller: chair).0
        }
        return exit
    }

    @Test func comparesTheObjectsGUID() throws {
        #expect(try test(guid: chairGUID, id: 1) == .gotoTrue)
        #expect(try test(guid: 0x101, id: 1) == .gotoFalse)
        #expect(try test(guid: chairGUID, id: 7) == .error) // no object 7: an error exit, not an exception
    }

    @Test func encodesItsOperand() {
        let operand = Primitives.TestObjectType.Operand(guid: 0x6271_EFF3, idScope: 8, idData: 3)
        #expect(operand.encoded() == [0xF3, 0xEF, 0x71, 0x62, 3, 0, 8, 0])
        #expect(Primitives.TestObjectType.Operand(bytes: operand.encoded()) == operand)
    }
}

@Suite struct RefreshTests {
    @Test(arguments: [(Int16(0), Int16(0)), (0, 1), (0, 2), (1, 0), (5, 3)])
    func succeedsWhenThereIsATarget(target: Int16, type: Int16) throws {
        try withVM { vm, chair throws in
            let operand = Primitives.Refresh.Operand(target: target, type: type).encoded()
            #expect(try vm.runPrimitive(opcode: 7, operand: operand, caller: chair).0 == .gotoTrue)
        }
    }

    @Test(arguments: [(Int16(1), Int16(1)), (1, 2), (2, 1)])
    func failsToFindTheRoomOfNoObject(target: Int16, type: Int16) throws {
        try withVM { vm, chair throws in
            let operand = Primitives.Refresh.Operand(target: target, type: type).encoded()
            #expect(throws: SimAnticsError.self) { try vm.runPrimitive(opcode: 7, operand: operand, caller: chair) }
        }
    }
}

@Suite struct SetToNextTests {
    func next(after start: Int16, search: UInt8, in vm: VM, caller: Entity, category: Int16 = 0) throws -> (ExitCode, Int16) {
        caller.thread.tempRegisters[3] = start
        let operand = Primitives.SetToNext.Operand(guid: chairGUID, search: search, targetScope: VariableScope.temps.rawValue, targetData: 3)
        let (exit, _) = try vm.runPrimitive(opcode: 31, operand: operand.encoded(), caller: caller, arguments: [category, 0, 0, 0])
        return (exit, caller.thread.tempRegisters[3])
    }

    @Test func walksObjectsInIDOrder() throws {
        try withVM { vm, chair throws in
            for id in [7, 3] as [Int16] { try vm.addObject(guid: chairGUID, id: id) }
            #expect(try next(after: 0, search: 0, in: vm, caller: chair) == (.gotoTrue, 1))
            #expect(try next(after: 1, search: 0, in: vm, caller: chair) == (.gotoTrue, 3))
            #expect(try next(after: 3, search: 4, in: vm, caller: chair) == (.gotoTrue, 7)) // of the chair's type
            #expect(try next(after: 7, search: 0, in: vm, caller: chair).0 == .gotoFalse)
            #expect(try next(after: 0, search: 1, in: vm, caller: chair).0 == .gotoFalse) // no Sims
            #expect(try next(after: 0, search: 11, in: vm, caller: chair).0 == .gotoFalse) // closest house
        }
    }

    @Test func findsObjectsOnlyOnceTheirCategoryIsSet() throws {
        try withVM { vm, chair throws in
            let other = try vm.addObject(guid: chairGUID, id: 2)
            #expect(try next(after: 0, search: 6, in: vm, caller: chair, category: 0).0 == .gotoFalse)
            try other.setValue(5, of: ObjectVariable.category.rawValue)
            #expect(try next(after: 0, search: 6, in: vm, caller: chair, category: 5) == (.gotoTrue, 2))
            try other.setValue(6, of: ObjectVariable.category.rawValue)
            #expect(try next(after: 0, search: 6, in: vm, caller: chair, category: 5).0 == .gotoFalse)
        }
    }

    @Test func usesTheStackObjectWithoutTheTargetFlag() {
        var bytes = Primitives.SetToNext.Operand(search: 0, targetScope: 8, targetData: 3).encoded()
        bytes[4] = 0 // clear the flag bit
        let operand = Primitives.SetToNext.Operand(bytes: bytes)
        #expect(operand.targetScope == VariableScope.stackObjectID.rawValue && operand.targetData == 0)
        #expect(operand.encoded() == bytes) // the stored bytes are kept
    }
}
