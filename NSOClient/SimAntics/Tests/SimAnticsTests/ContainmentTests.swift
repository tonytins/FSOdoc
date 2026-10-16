import Foundation
import Testing
import TSOFiles
@testable import SimAntics

private let trayGUID: UInt32 = 0x400
private let slotWord = 18

/// A `SLOT` chunk with one container slot (type 0); version 4 gives it the default height of 5.
private func containerSlotChunk(id: UInt16) -> ChunkFixture {
    var writer = ByteWriter()
    writer.uint32(0); writer.uint32(4); writer.ascii("TOLS"); writer.uint32(1)
    writer.uint16(0)
    for _ in 0..<3 { writer.uint32(Float(0).bitPattern) }
    for value: Int32 in [0, 0, 0, 0, -1] { writer.int32(value) }
    return ChunkFixture(type: "SLOT", id: id, contents: writer.bytes)
}

/// A tray with one container slot, and a lamp, both placeable on bare ground at floor height.
private func withTray(_ body: (VM, Entity, Entity) throws -> Void) throws {
    try withVM(chair: [
        objdChunk(label: "tray", guid: trayGUID, words: [slotWord: 128], id: 140),
        objdChunk(label: "lamp", guid: lampGUID, id: 133),
        containerSlotChunk(id: 128),
    ], objects: [trayGUID, lampGUID]) { vm, _ throws in
        vm.architecture = try Architecture(width: 8, height: 8)
        let tray = try #require(try vm.createObject(guid: trayGUID)?.objects.first)
        let lamp = try #require(try vm.createObject(guid: lampGUID)?.objects.first)
        for entity in [tray, lamp] {
            entity.objectData[Int(ObjectVariable.placementFlags.rawValue)] = PlacementFlags.onTerrain.rawValue
            entity.objectData[Int(ObjectVariable.allowedHeightFlags.rawValue)] = 1
        }
        try body(vm, tray, lamp)
    }
}

private func data(_ entity: Entity, _ variable: ObjectVariable) throws -> Int16 {
    try entity.value(of: variable.rawValue)
}

@Suite struct ContainmentTests {
    @Test func holdsAnObjectInASlot() throws {
        try withTray { vm, tray, lamp throws in
            #expect(tray.totalSlots == 1 && lamp.totalSlots == 0)
            #expect(try data(tray, .slotCount) == 1)
            #expect(try data(lamp, .containerID) == 0 && data(lamp, .slotNumber) == -1)
            #expect(try tray.placeInSlot(lamp, slot: 0, cleanOld: true))
            #expect(tray.slot(0) === lamp && lamp.container === tray)
            #expect(try data(lamp, .containerID) == tray.objectID && data(lamp, .parentID) == tray.objectID)
            #expect(try data(lamp, .slotNumber) == 0)
            #expect(try tray.placeInSlot(lamp, slot: 0, cleanOld: true))   // already there
            #expect(try !lamp.placeInSlot(tray, slot: 0, cleanOld: true))  // no slot, and it would loop
            #expect(try !tray.placeInSlot(tray, slot: 0, cleanOld: true))
            #expect(try !tray.placeInSlot(lamp, slot: 5, cleanOld: false) || tray.slot(5) == nil)
        }
    }

    @Test func slotScopesReadTheHeldObjectsID() throws {
        try withTray { vm, tray, lamp throws in
            try tray.placeInSlot(lamp, slot: 0, cleanOld: true)
            let read = Primitives.Expression.Operand(Variable(.temps, 0), .assign, Variable(.mySlot, 0))
            _ = try vm.runPrimitive(opcode: 2, operand: read.encoded(), caller: tray)
            #expect(tray.thread.tempRegisters[0] == lamp.objectID)
            let empty = Primitives.Expression.Operand(Variable(.temps, 1), .assign, Variable(.mySlot, 3))
            _ = try vm.runPrimitive(opcode: 2, operand: empty.encoded(), caller: tray)
            #expect(tray.thread.tempRegisters[1] == 0)
        }
    }

    @Test func whatASlotHoldsMovesWithIt() throws {
        try withTray { vm, tray, lamp throws in
            try tray.placeInSlot(lamp, slot: 0, cleanOld: true)
            #expect(try vm.place(tray.group, at: .center(ofTileX: 3, y: 3, level: 1), facing: .north).status == .success)
            #expect(lamp.position == tray.position && lamp.footprint == nil && tray.footprint != nil)
            #expect(vm.objects(at: tray.position)?.map(\.objectID) == [tray.objectID, lamp.objectID])
            // Moving the lamp out of the slot frees it.
            try vm.move(lamp, to: .outOfWorld)
            #expect(lamp.container == nil && tray.slot(0) == nil)
        }
    }

    @Test func stacksOntoASlotWhenSlotsAreAccepted() throws {
        try withTray { vm, tray, lamp throws in
            #expect(try vm.place(tray.group, at: .center(ofTileX: 3, y: 3, level: 1), facing: .north).status == .success)
            lamp.objectData[Int(ObjectVariable.allowedHeightFlags.rawValue)] = 1 | 1 << 4   // slot height 5
            tray.objectData[Int(ObjectVariable.supportStrength.rawValue)] = 10
            #expect(try vm.place(lamp.group, at: tray.position, facing: .north).status == .cantIntersectOtherObjects)
            #expect(try vm.place(lamp.group, at: tray.position, facing: .north, flags: .acceptSlots).status == .success)
            #expect(tray.slot(0) === lamp && lamp.position == tray.position)
            lamp.objectData[Int(ObjectVariable.weight.rawValue)] = 20
            try vm.move(lamp, to: .outOfWorld)
            #expect(try vm.place(lamp.group, at: tray.position, facing: .north, flags: .acceptSlots).status == .cantSupportWeight)
        }
    }

    @Test func deletingAContainerPutsWhatItHeldNearby() throws {
        try withTray { vm, tray, lamp throws in
            try vm.place(tray.group, at: .center(ofTileX: 3, y: 3, level: 1), facing: .north)
            try tray.placeInSlot(lamp, slot: 0, cleanOld: true)
            try vm.delete(tray)
            #expect(lamp.container == nil && !lamp.position.isOutOfWorld)
            #expect(lamp.position == .center(ofTileX: 3, y: 3, level: 1))   // the first spot that fits
        }
    }

    @Test func findsALocationNearTheReference() throws {
        try withTray { vm, tray, lamp throws in
            try vm.place(tray.group, at: .center(ofTileX: 3, y: 3, level: 1), facing: .north)
            func find(_ mode: UInt8, _ flags: Primitives.FindLocationFor.Flags = []) throws -> ExitCode {
                let operand = Primitives.FindLocationFor.Operand(mode: mode, flags: flags)
                let (primitive, frame) = try vm.makePrimitiveFrame(opcode: 16, operand: operand.encoded(), caller: tray,
                                                                   stackObjectID: lamp.objectID)
                defer { tray.thread.stack.removeAll() }
                return try primitive.execute(in: frame)
            }
            #expect(try find(0) == .gotoTrue)
            #expect(lamp.position.tileX == 2 && lamp.position.tileY == 2)   // the first ring starts up and to the left
            #expect(try find(1) == .gotoTrue && lamp.position.isOutOfWorld)
            #expect(try find(3) == .gotoTrue && !lamp.position.isOutOfWorld)
            #expect(try find(0, .userEditableTilesOnly) == .gotoFalse)       // a blueprint lot has no buildable area
            #expect(try find(5) == .gotoTrue && find(7) == .gotoFalse)
        }
    }

    @Test func createsAnObjectInTheStackObjectsSlot() throws {
        try withTray { vm, tray, lamp throws in
            let operand = Primitives.CreateObjectInstance.Operand(guid: lampGUID, position: .inSlot0OfStackObject)
            let (primitive, frame) = try vm.makePrimitiveFrame(opcode: 42, operand: operand.encoded(), caller: lamp,
                                                               stackObjectID: tray.objectID)
            defer { lamp.thread.stack.removeAll() }
            #expect(try primitive.execute(in: frame) == .gotoTrue)
            let created = try #require(frame.stackObject)
            #expect(tray.slot(0) === created && created !== lamp)
        }
    }
}
