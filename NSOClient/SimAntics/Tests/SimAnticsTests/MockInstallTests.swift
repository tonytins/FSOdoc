import Foundation
import Testing
import TSOContent
@testable import SimAntics

/// `NSOClient/MockInstall`: a made-up install committed for tests, so these always run.
let mockInstall = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("../../../MockInstall/TSOClient").standardizedFileURL
let mockChairGUID: UInt32 = 0x4D4F_4301, mockTableGUID: UInt32 = 0x4D4F_4302
let mockLeftGUID: UInt32 = 0x4D4F_4303, mockRightGUID: UInt32 = 0x4D4F_4304

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

    @Test func mainCountsItsRuns() throws {
        let vm = try vm()
        let entity = try #require(try vm.createObject(guid: mockChairGUID)?.objects.first)
        for _ in 0..<10 { vm.tick() }
        #expect(entity.attributes.first == 10)  // main returns and runs again each tick, as in FreeSO
    }
}
