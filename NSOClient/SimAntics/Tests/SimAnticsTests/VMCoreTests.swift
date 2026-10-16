import Foundation
import Testing
import TSOFiles
import TSOContent
@testable import SimAntics

@Suite struct VMRandomTests {
    /// Values from `fso-oracle run-primitive` (Random Number with a range of 100).
    @Test(arguments: [
        (UInt64(0x0F50_D0C5_EED0_0001), UInt64(97), UInt64(0x9E95_3801_3229_EF5D)),
        (1, 65, 0x0000_0000_0200_0001),
    ])
    func drawsTheSameNumbersAs2017(seed: UInt64, value: UInt64, nextSeed: UInt64) {
        var random = VMRandom(seed: seed)
        #expect(random.next(below: 100) == value)
        #expect(random.seed == nextSeed)
    }

    @Test func aLimitOfZeroReturnsZeroWithoutAdvancing() {
        var random = VMRandom(seed: 5)
        #expect(random.next(below: 0) == 0)
        #expect(random.seed == 5)
    }
}

@Suite struct EntityTests {
    @Test func objectVariablesMatch2017Indexes() {
        #expect(ObjectVariable.allCases.count == ObjectVariable.count)
        #expect(ObjectVariable.room.rawValue == 29)
        #expect(ObjectVariable.fsoEngineQuery.rawValue == 79)
    }

    @Test func readsAndWritesObjectData() throws {
        try withVM { _, chair throws in
            try chair.setValue(42, of: ObjectVariable.graphic.rawValue)
            #expect(try chair.value(of: 0) == 42)
            #expect(try chair.value(of: ObjectVariable.objectID.rawValue) == 1)
        }
    }

    @Test(arguments: [(Int16(9), Int16(1)), (-1, 7), (8, 0)])
    func normalizesDirection(written: Int16, stored: Int16) throws {
        try withVM { _, chair throws in
            try chair.setValue(written, of: ObjectVariable.direction.rawValue)
            #expect(chair.direction.notch == Int(stored))
            #expect(chair.objectData[1] == stored)
            #expect(try chair.value(of: 1) == stored)
        }
    }

    @Test func failsOutsideTheObjectData() throws {
        try withVM { _, chair throws in
            #expect(throws: SimAnticsError.simantics("Object Data out of range!")) { try chair.value(of: 80) }
            #expect(throws: SimAnticsError.indexOutOfRange("object data -1")) { try chair.setValue(1, of: -1) }
        }
    }

    @Test func growsAttributesWhenRead() throws {
        try withVM { _, chair throws in
            #expect(chair.attribute(at: 3) == 0)
            #expect(chair.attributes.count == 4)
            chair.setAttribute(7, at: 5)
            #expect(chair.attributes == [0, 0, 0, 0, 0, 7])
        }
    }

    @Test func countsDownTheLockoutFromWhenItWasSet() throws {
        try withVM { vm, chair throws in
            vm.scheduler.currentTick = 100
            try chair.setValue(30, of: ObjectVariable.lockoutCount.rawValue)
            vm.scheduler.currentTick = 110
            #expect(try chair.value(of: ObjectVariable.lockoutCount.rawValue) == 20)
            vm.scheduler.currentTick = 200
            #expect(try chair.value(of: ObjectVariable.lockoutCount.rawValue) == 0)
        }
    }
}

@Suite struct VMMemoryTests {
    @Test func setsTheDefaultGlobals() throws {
        try withVM { vm, _ throws in
            #expect(vm.globalState.count == 38)
            #expect(vm.globalState[20] == 255 && vm.globalState[25] == 4 && vm.globalState[17] == 4)
            #expect(throws: SimAnticsError.simantics("Global Access out of bounds!")) { try vm.globalValue(at: 38) }
        }
    }

    @Test func keepsAStackObjectIDWithNoEntity() throws {
        try withVM { vm, chair throws in
            let (_, frame) = try vm.runPrimitive(opcode: 2, operand: expression(.assign, .stackObjectID, 0, .literal, 9),
                                                 caller: chair)
            #expect(frame.stackObjectID == 9)
            #expect(frame.stackObject == nil)
        }
    }

    @Test func failsForAnUnknownScope() throws {
        try withVM { vm, chair throws in
            var operand = expression(.assign, .temps, 0, .literal, 1)
            operand[7] = 39 // no scope 39
            #expect(throws: SimAnticsError.simantics("Unknown get variable")) {
                try vm.runPrimitive(opcode: 2, operand: operand, caller: chair)
            }
        }
    }

    /// Table numbers in the tuning scope: the top 9 bits pick a table, the low 7 a key.
    static func tuning(table: UInt16, key: UInt16) -> Int16 { Int16(bitPattern: table << 7 | key) }

    @Test func readsTuningFromTheOwnerSemiGlobalAndGlobal() throws {
        try withVM(chair: [bconChunk(id: 4096, [11, 12])], semiGlobal: [bconChunk(id: 8193, [21])],
                   global: [bconChunk(id: 258, [31, 32, 33])]) { vm, chair throws in
            func read(_ data: Int16) throws -> Int16 {
                let (_, frame) = try vm.runPrimitive(opcode: 2, operand: expression(.assign, .temps, 0, .tuning, data),
                                                     caller: chair)
                return frame.thread.tempRegisters[0]
            }
            #expect(try read(Self.tuning(table: 0, key: 1)) == 12)
            #expect(try read(Self.tuning(table: 65, key: 0)) == 21)
            #expect(try read(Self.tuning(table: 130, key: 2)) == 33)
            #expect(try read(Self.tuning(table: 130, key: 3)) == 0) // past a checked BCON, with no OTF
            #expect(throws: SimAnticsError.indexOutOfRange("constant 2 of BCON 4096")) {
                try read(Self.tuning(table: 0, key: 2)) // the owner's BCONs aren't checked
            }
        }
    }

    @Test func fallsBackToTheObjectsTuningTables() throws {
        try withVM(chairOTF: otf([(id: 4097, keys: [(id: 3, value: 70_000)])])) { vm, chair throws in
            let (_, frame) = try vm.runPrimitive(opcode: 2, operand: expression(.assign, .temps, 0, .tuning,
                                                                                Self.tuning(table: 1, key: 3)), caller: chair)
            #expect(frame.thread.tempRegisters[0] == Int16(truncatingIfNeeded: 70_000))
            #expect(throws: SimAnticsError.nullReference("key 4 of tuning table 4097")) {
                try vm.runPrimitive(opcode: 2, operand: expression(.assign, .temps, 0, .tuning,
                                                                    Self.tuning(table: 1, key: 4)), caller: chair)
            }
        }
    }
}

@Suite struct OperandEncodingTests {
    @Test func encodesAnExpressionAsItWasRead() {
        let bytes: [UInt8] = [0x0a, 0x00, 0xff, 0xff, 1, 5, 8, 7]
        #expect(Primitives.Expression.Operand(bytes: bytes).encoded() == bytes)
    }

    @Test func encodesACall() {
        let call = SubroutineOperand(arguments: [-1, 2])
        #expect(call.arguments == [-1, 2, 0, 0] && call.usesTemps)
        #expect(call.encoded() == [0xff, 0xff, 2, 0, 0, 0, 0, 0])
    }
}

/// Every Expression and call operand in the install encodes back to its bytes.
@Suite(.enabled(if: gameDirectory != nil, "TSO_GAME_DIR is not set"))
struct RealOperandEncodingTests {
    @Test func everyOperandRoundTrips() throws {
        let content = try GameContent(.init(gameDirectory: try required(gameDirectory)))
        var resources: [any IFFResource] = [try content.global()]
        var seen = Set<String>()
        for reference in content.objects.references where seen.insert(reference.fileName).inserted {
            guard let object = try? content.objects.object(guid: reference.guid) else { continue }
            resources.append(object.resource)
            if let semiGlobal = object.resource.semiGlobal, seen.insert("semi " + semiGlobal.name).inserted { resources.append(semiGlobal) }
        }
        var checked = 0, problems: [String] = []
        for resource in resources {
            for routine in try resource.mainFile.chunks(BHAV.self) {
                for instruction in routine.instructions where instruction.opcode == 2 || instruction.opcode >= 256 {
                    let bytes = [UInt8](instruction.operand)
                    let encoded = instruction.opcode == 2
                        ? Primitives.Expression.Operand(bytes: bytes).encoded() : SubroutineOperand(bytes: bytes).encoded()
                    if encoded != bytes { problems.append("BHAV #\(routine.id) opcode \(instruction.opcode)") }
                    checked += 1
                }
            }
        }
        #expect(checked > 50_000)
        #expect(problems.isEmpty, "\(problems.count) operands differ, first: \(problems.prefix(5))")
    }
}

@Suite struct LotPositionTests {
    @Test func placesTileCentersInSixteenths() {
        let position = LotPosition.center(ofTileX: 3, y: 5, level: 2)
        #expect(position == LotPosition(x: 56, y: 88, level: 2))
        #expect(position.tileX == 3 && position.tileY == 5)
        #expect(LotPosition.outOfWorld.isOutOfWorld && LotPosition.outOfWorld.tileX == -2048)
    }

    @Test func measuresDistanceRoundedDown() {
        #expect(LotPosition(x: 0, y: 0, level: 1).distance(to: LotPosition(x: 3, y: 4, level: 2)) == 5)
        #expect(LotPosition(x: 0, y: 0, level: 1).distance(to: LotPosition(x: 1, y: 1, level: 1)) == 1)
    }

    @Test func numbersDirectionsClockwiseFromNorth() {
        #expect(Direction(notch: 0) == .north && Direction(notch: 7) == .northWest && Direction(notch: 9) == .northEast)
        #expect(Direction(notch: -1) == .northWest)
        #expect(Direction.allCases.map(\.notch) == Array(0...7))
    }

    @Test func snapsDirectionWritesToTheRotationStep() throws {
        try withVM { _, chair throws in
            chair.objectData[Int(ObjectVariable.rotationNotches.rawValue)] = 2
            try chair.setValue(3, of: ObjectVariable.direction.rawValue)
            #expect(chair.direction == .east)          // notch 3 snaps down to 2
            #expect(chair.objectData[1] == 3)            // the stored value isn't snapped
        }
    }
}

@Suite struct TileIndexTests {
    @Test func listsObjectsByTileInIDOrder() throws {
        try withVM { vm, chair throws in
            let other = try vm.addObject(guid: chairGUID, id: 5)
            let tile = LotPosition.center(ofTileX: 4, y: 4, level: 1)
            vm.move(other, to: tile)
            vm.move(chair, to: LotPosition(x: tile.x + 3, y: tile.y, level: 1)) // same tile, off center
            #expect(vm.objects(at: tile)?.map(\.objectID) == [1, 5])
            vm.move(chair, to: .outOfWorld)
            #expect(vm.objects(at: tile)?.map(\.objectID) == [5])
            #expect(vm.objects(at: .outOfWorld)?.map(\.objectID) == [1])
            #expect(vm.objects(at: LotPosition.center(ofTileX: 9, y: 9, level: 1)) == nil)
        }
    }

    @Test func sharesKeysPastTheLotEdgeAs2017Does() throws {
        try withVM { vm, chair throws in
            vm.architecture = try Architecture(width: 10, height: 10)
            vm.move(chair, to: LotPosition.center(ofTileX: 10, y: 0, level: 1)) // one past the edge
            #expect(vm.objects(at: LotPosition.center(ofTileX: 0, y: 1, level: 1))?.first === chair)
        }
    }
}
