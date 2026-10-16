import Foundation
import Testing
import TSOFiles
@testable import SimAntics

/// A multi-tile table (master 0x200) with two parts, a part of another object, and a lone lamp.
private let tableGUID: UInt32 = 0x200, leftGUID: UInt32 = 0x201, rightGUID: UInt32 = 0x202
private let otherPartGUID: UInt32 = 0x203, lampGUID: UInt32 = 0x300
private let masterID = 8, subIndex = 9, levelOffset = 54, myLeadObject = 61

private func withTable(rightLeads: Bool = false, _ body: (VM, Entity) throws -> Void) throws {
    try withVM(chair: [
        objdChunk(label: "table", guid: tableGUID, words: [masterID: 5, subIndex: 0xFFFF], id: 129),
        objdChunk(label: "table left", guid: leftGUID, words: [masterID: 5, subIndex: 0x0000], id: 130),
        objdChunk(label: "table right", guid: rightGUID,
                  words: [masterID: 5, subIndex: 0x0100, levelOffset: 1, myLeadObject: rightLeads ? 1 : 0], id: 131),
        objdChunk(label: "other part", guid: otherPartGUID, words: [masterID: 6, subIndex: 0x0001], id: 132),
        objdChunk(label: "lamp", guid: lampGUID, id: 133),
    ], objects: [tableGUID, leftGUID, rightGUID, otherPartGUID, lampGUID], body)
}

@Suite struct GroupTests {
    @Test func createsEveryPartOfAMultiTileObject() throws {
        try withTable { vm, _ throws in
            let table = try #require(try vm.createObject(guid: tableGUID))
            #expect(table.isMultiTile)
            #expect(table.objects.map(\.objectID) == [2, 3])        // the chair is 1
            #expect(table.objects.map(\.object.guid) == [leftGUID, rightGUID])
            #expect(table.objects.allSatisfy { $0.masterDefinition?.guid == tableGUID && $0.group === table })
            #expect(table.offsets == [LotPosition(x: 0, y: 0, level: 0), LotPosition(x: 16, y: 0, level: 1)])
            #expect(table.leadObject?.objectID == 2)                 // the part at offset zero
            #expect(table.objects.allSatisfy { $0.leadObject === table.leadObject && $0.position.isOutOfWorld })
            #expect(vm.entities.map(\.objectID) == [1, 2, 3])
        }
    }

    @Test func aPartThatSaysItLeadsLeads() throws {
        try withTable(rightLeads: true) { vm, _ throws in
            let table = try #require(try vm.createObject(guid: tableGUID))
            #expect(table.leadObject?.object.guid == rightGUID)
        }
    }

    @Test func aLoneObjectIsAGroupOfOne() throws {
        try withTable { vm, chair throws in
            #expect(!chair.group.isMultiTile && chair.group.objects.count == 1 && chair.leadObject === chair)
            let lamp = try #require(try vm.createObject(guid: lampGUID, facing: .east))
            #expect(!lamp.isMultiTile && lamp.objects.map(\.objectID) == [2])
            #expect(lamp.objects[0].direction == .east && lamp.objects[0].masterDefinition == nil)
            #expect(try vm.createObject(guid: 0x9999) == nil)
        }
    }

    @Test func refusesWhatIsNotPortedYet() throws {
        try withTable { vm, _ throws in
            #expect(throws: SimAnticsError.unsupported("placing an object in the world needs placement")) {
                try vm.createObject(guid: lampGUID, at: .center(ofTileX: 1, y: 1, level: 1))
            }
            #expect(vm.entities.count == 1)
        }
    }

    @Test func deletingFreesTheObjectID() throws {
        try withTable { vm, _ throws in
            let table = try #require(try vm.createObject(guid: tableGUID))
            let lamp = try #require(try vm.createObject(guid: lampGUID)?.objects.first)
            #expect(lamp.objectID == 4)
            let left = table.objects[0]
            vm.delete(left)
            #expect(left.isDead && vm.entity(id: 2) == nil && table.objects.map(\.objectID) == [3])
            vm.delete(left)                                          // twice does nothing
            #expect(vm.entities.map(\.objectID) == [1, 3, 4])
            #expect(try vm.createObject(guid: lampGUID)?.objects.first?.objectID == 2)   // the lowest free ID
            vm.delete(table.objects[0], wholeGroup: true)
            #expect(vm.entities.map(\.objectID) == [1, 2, 4] && table.objects.isEmpty)
            #expect(vm.objects(withGUID: rightGUID) == nil)
        }
    }

    @Test func findsTheNextPartByID() throws {
        try withTable { vm, chair throws in
            _ = try vm.createObject(guid: tableGUID)
            func next(after id: Int16) throws -> (ExitCode, Int16) {
                chair.thread.tempRegisters[3] = id
                let operand = Primitives.SetToNext.Operand(search: 3, targetScope: VariableScope.temps.rawValue, targetData: 3)
                let (exit, _) = try vm.runPrimitive(opcode: 31, operand: operand.encoded(), caller: chair)
                return (exit, chair.thread.tempRegisters[3])
            }
            #expect(try next(after: 2) == (.gotoTrue, 3))
            #expect(try next(after: 3) == (.gotoTrue, 2))            // wraps to the lowest
            #expect(try next(after: 1).0 == .gotoFalse)              // the chair is alone
            #expect(try next(after: 99).0 == .gotoFalse)
        }
    }
}

@Suite struct CreateObjectInstanceTests {
    private func create(_ vm: VM, _ caller: Entity, _ position: Primitives.CreateObjectInstance.Position,
                        flags: Primitives.CreateObjectInstance.Flags = [], guid: UInt32 = lampGUID) throws -> (ExitCode, StackFrame) {
        let operand = Primitives.CreateObjectInstance.Operand(guid: guid, position: position, flags: flags)
        return try vm.runPrimitive(opcode: 42, operand: operand.encoded(), caller: caller)
    }

    @Test func createsOutOfTheWorldAsTheStackObject() throws {
        try withTable { vm, chair throws in
            let (exit, frame) = try create(vm, chair, .outOfWorld)
            #expect(exit == .gotoTrue && frame.stackObjectID == 2 && vm.entity(id: 2)?.object.guid == lampGUID)
            #expect(try create(vm, chair, .outOfWorld, guid: 0x9999).0 == .gotoFalse)
        }
    }

    @Test func deletesWhatItCouldNotPlace() throws {
        try withTable { vm, chair throws in
            // The chair is out of the world, so "underneath me" leaves the lamp unplaced.
            #expect(try create(vm, chair, .underneathMe).0 == .gotoFalse)
            #expect(vm.entities.map(\.objectID) == [1])
        }
    }

    @Test func passesTemp0OrTheCallerToMain() throws {
        try withTable(rightLeads: false) { vm, chair throws in
            chair.thread.tempRegisters[0] = 7
            // The lamp has no main, so check what the entity was given before init cleared it.
            let operand = Primitives.CreateObjectInstance.Operand(guid: lampGUID, position: .outOfWorld,
                                                                  flags: [.passTemp0, .passObjectIDs])
            let (exit, _) = try vm.runPrimitive(opcode: 42, operand: operand.encoded(), caller: chair)
            let lamp = try #require(vm.entity(id: 2))
            #expect(exit == .gotoTrue && lamp.mainParameter == 0 && lamp.mainStackObjectID == 0)
        }
    }

    @Test func failsAs2017Does() throws {
        try withTable { vm, chair throws in
            var operand = Primitives.CreateObjectInstance.Operand(guid: lampGUID, position: .outOfWorld)
            operand.rawPosition = 10
            #expect(throws: SimAnticsError.simantics("Where do I put this??")) {
                try vm.runPrimitive(opcode: 42, operand: operand.encoded(), caller: chair)
            }
            #expect(throws: SimAnticsError.nullReference("no stack object")) { try create(vm, chair, .inFrontOfStackObject) }
            #expect(throws: SimAnticsError.self) { try create(vm, chair, .outOfWorld, flags: .useNeighbor) }
            #expect(vm.entity(id: 2) != nil)                         // the neighbor cast fails after creating
        }
    }
}
