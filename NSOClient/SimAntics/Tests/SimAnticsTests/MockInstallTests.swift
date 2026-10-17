import Foundation
import Testing
import TSOContent
@testable import SimAntics

/// `NSOClient/MockInstall`: a made-up install committed for tests, so these always run.
let mockInstall = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("../../../MockInstall/TSOClient").standardizedFileURL
let mockChairGUID: UInt32 = 0x4D4F_4301, mockTableGUID: UInt32 = 0x4D4F_4302
let mockLeftGUID: UInt32 = 0x4D4F_4303, mockRightGUID: UInt32 = 0x4D4F_4304, mockLampGUID: UInt32 = 0x4D4F_4305

/// The VM on the mock install's objects (see its README): init sets object data 42 and 4,
/// and main counts its runs in attribute 0.
@Suite struct MockInstallTests {
    private func vm() throws -> VM {
        try VM(content: try GameContent(.init(gameDirectory: mockInstall)), seed: 1)
    }

    @Test func createsTheChairAndRunsItsInit() throws {
        let vm = try vm()
        let chair = try #require(try vm.createObject(guid: mockChairGUID))
        let entity = try #require(chair.objects.first)
        #expect(!chair.isMultiTile && entity.object.guid == mockChairGUID)
        #expect(entity.objectData[42] == 3 && entity.objectData[4] == 1)
    }

    @Test func createsTheTableAsAGroupOfItsParts() throws {
        let vm = try vm()
        let table = try #require(try vm.createObject(guid: mockTableGUID))
        #expect(table.isMultiTile)
        #expect(table.objects.map(\.object.guid) == [mockLeftGUID, mockRightGUID])
        #expect(table.offsets == [LotPosition(x: 0, y: 0, level: 0), LotPosition(x: 16, y: 0, level: 0)])
        #expect(table.leadObject?.object.guid == mockLeftGUID)
    }

    /// The lamp's main makes itself the stack object and runs its "mock tree" (attribute 1 += 1)
    /// with Run Tree By Name on its own stack, on the stack object's, and pushed, and looks up a
    /// name it doesn't have.
    @Test func theLampRunsItsTreeByNameThreeWaysEachTick() throws {
        let vm = try vm()
        let lamp = try #require(try vm.createObject(guid: mockLampGUID)?.objects.first)
        for _ in 0..<4 { vm.tick() }
        #expect(lamp.attributes.count > 1 && lamp.attributes[1] == 12)
        #expect(vm.reportedErrors.isEmpty)
    }

    @Test func aTreeRunOnAnIdleThreadDoesNothingAndLeavesItACheckThread() throws {
        let vm = try vm()
        let lamp = try #require(try vm.createObject(guid: mockLampGUID)?.objects.first)
        let chair = try #require(try vm.createObject(guid: mockChairGUID)?.objects.first)
        let routine = try #require(vm.routine(named: "mock tree", in: lamp.object))
        chair.thread.stack.removeAll()
        // FreeSO's RunInMyStack takes out the routine it just pushed when nothing else was running.
        #expect(try chair.thread.runInMyStack(routine, codeOwner: lamp.object, arguments: [0, 0, 0, 0], stackObject: lamp) == false)
        #expect(chair.thread.isCheck && chair.thread.stack.isEmpty)
        vm.tick()
        #expect(chair.thread.stack.isEmpty)       // a check thread doesn't push main
    }

    @Test func anInterruptBringsAFutureRunForwardToTheNextTick() throws {
        let vm = try vm()
        let chair = try #require(try vm.createObject(guid: mockChairGUID)?.objects.first)
        vm.tick()
        vm.scheduler.descheduleTick(for: chair)
        vm.scheduler.scheduleTick(for: chair, on: vm.scheduler.currentTick + 50)
        vm.scheduler.rescheduleInterrupt(chair)
        #expect(vm.scheduler.scheduledObjectIDs(on: vm.scheduler.currentTick + 50).isEmpty)
        #expect(vm.scheduler.scheduledObjectIDs(on: vm.scheduler.currentTick + 1) == [chair.objectID])
        // One due this tick is left alone.
        vm.scheduler.descheduleTick(for: chair)
        vm.scheduler.scheduleTick(for: chair, on: vm.scheduler.currentTick)
        vm.scheduler.rescheduleInterrupt(chair)
        #expect(chair.thread.scheduledTick == vm.scheduler.currentTick)
    }

    @Test func mainCountsItsRuns() throws {
        let vm = try vm()
        let entity = try #require(try vm.createObject(guid: mockChairGUID)?.objects.first)
        for _ in 0..<10 { vm.tick() }
        #expect(entity.attributes.first == 10)  // main returns and runs again each tick, as in FreeSO
    }
}

/// Loading `NSOClient/MockInstall/Lots/mock-lot.xml`, which `fso-oracle run-lot` matches tick for tick.
@Suite struct MockLotTests {
    private let lotFile = mockInstall.deletingLastPathComponent().appendingPathComponent("Lots/mock-lot.xml")

    @Test func loadsEveryObjectItHasAndLeavesOutTheRest() throws {
        let vm = try VM(content: try GameContent(.init(gameDirectory: mockInstall)), seed: 1)
        let lot = try Blueprint(xml: try Data(contentsOf: lotFile))
        let leftOut = try vm.load(lot)
        #expect(leftOut.map(\.object.guid) == [0x4D4F_43FF])
        #expect(vm.entities.last?.object.guid == mockLampGUID)
        #expect(vm.globalState[11] == -1)                                   // the job level
        #expect(vm.entities.map(\.object.guid) == [mockChairGUID, mockChairGUID, mockLeftGUID, mockRightGUID, mockLeftGUID, mockRightGUID,
                                                  mockLampGUID])

        let (outside, inside) = (vm.entities[0], vm.entities[1])
        #expect(outside.position.isOutOfWorld)                              // level 0 stays out of the world
        #expect(inside.position == .center(ofTileX: 3, y: 3, level: 1) && inside.direction == .east)
        #expect(inside.objectData[Int(ObjectVariable.room.rawValue)] == 2)  // the walled room
        // The table facing south: its right part turned to the left of its lead part.
        #expect(vm.entities[2].position == .center(ofTileX: 7, y: 3, level: 1) && vm.entities[3].position.x == 104)
        #expect(vm.entities[2...3].allSatisfy { $0.objectData[Int(ObjectVariable.groupID.rawValue)] == 9 })
        #expect(vm.entities[4...5].allSatisfy { $0.objectData[Int(ObjectVariable.groupID.rawValue)] == 0 })
    }

    /// The chair (tile 3, 3) and the lamp (tile 4, 2) are a tile apart diagonally: one tile away,
    /// the lamp is northeast (1) of the chair, and the chair southwest (5) of the lamp.
    @Test func measuresDistanceAndDirectionBetweenLotObjects() throws {
        let vm = try VM(content: try GameContent(.init(gameDirectory: mockInstall)), seed: 1)
        try vm.load(try Blueprint(xml: try Data(contentsOf: lotFile)))
        let chair = vm.entities[1], lamp = try #require(vm.entities.last)
        #expect(chair.position == .center(ofTileX: 3, y: 3, level: 1) && lamp.position == .center(ofTileX: 4, y: 2, level: 1))
        let toLamp = try vm.makePrimitiveFrame(opcode: 12, operand: Primitives.GetDirectionTo.Operand(
            result: Variable(.temps, 0), flags: 0, object: Variable(.literal, 0)).encoded(), caller: chair, stackObjectID: lamp.objectID)
        #expect(try toLamp.0.execute(in: toLamp.1) == .gotoTrue && chair.thread.tempRegisters[0] == 1)
        let toChair = try vm.makePrimitiveFrame(opcode: 12, operand: Primitives.GetDirectionTo.Operand(
            result: Variable(.temps, 1), flags: 1, object: Variable(.literal, lamp.objectID)).encoded(), caller: chair,
            stackObjectID: chair.objectID)
        #expect(try toChair.0.execute(in: toChair.1) == .gotoTrue && chair.thread.tempRegisters[1] == 5)
        let distance = try vm.makePrimitiveFrame(opcode: 11, operand: Primitives.GetDistanceTo.Operand(
            temp: 2, flags: 0, object: Variable(.literal, 0)).encoded(), caller: chair, stackObjectID: lamp.objectID)
        #expect(try distance.0.execute(in: distance.1) == .gotoTrue && chair.thread.tempRegisters[2] == 1)
        let tooFar = try vm.makePrimitiveFrame(opcode: 11, operand: Primitives.GetDistanceTo.Operand(
            temp: 20, flags: 0, object: Variable(.literal, 0)).encoded(), caller: chair, stackObjectID: lamp.objectID)
        #expect(throws: SimAnticsError.self) { try tooFar.0.execute(in: tooFar.1) }
    }

    @Test func roundsDirectionsAsFreeSODoes() {
        #expect(Primitives.GetDirectionTo.positiveModulo(-1, 4) == 3)
        #expect(Primitives.GetDirectionTo.normalized(3 * .pi) == .pi)
        #expect(Primitives.GetDirectionTo.normalized(-.pi / 2) == -.pi / 2)
    }
}
