import Foundation
import Testing
import TSOFiles
@testable import TSOContent

/// `NSOClient/MockInstall`: a made-up install committed for tests, so these always run.
let mockInstall = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("../../../MockInstall/TSOClient").standardizedFileURL

/// The mock install read the way a real one is (see its README for what's in it).
@Suite struct MockInstallTests {
    let content: GameContent

    init() throws {
        content = try GameContent(.init(gameDirectory: mockInstall))
    }

    @Test func registersTheFiveMockObjects() {
        #expect(content.objects.references.map(\.guid) == [0x4D4F_4301, 0x4D4F_4302, 0x4D4F_4303, 0x4D4F_4304, 0x4D4F_4305])
        #expect(content.objects.references.map(\.fileName) == ["mockchair", "mocktable", "mocktable", "mocktable", "mocklamp"])
        #expect(content.objects.duplicates.isEmpty)
    }

    @Test func loadsEachObjectWithTheMockSemiGlobal() throws {
        for reference in content.objects.references {
            let object = try #require(try content.objects.object(guid: reference.guid))
            #expect(object.resource.semiGlobal?.name == "mockglobals")
            #expect(try object.resource.semiGlobal?.chunk(BHAV.self, id: 8192) != nil)
            #expect(try object.resource.chunk(BHAV.self, id: 4096) != nil && object.resource.chunk(BHAV.self, id: 4097) != nil)
        }
    }

    @Test func describesTheTableAsAMasterWithTwoParts() throws {
        let table = try #require(try content.objects.object(guid: 0x4D4F_4302))
        let left = try #require(try content.objects.object(guid: 0x4D4F_4303))
        let right = try #require(try content.objects.object(guid: 0x4D4F_4304))
        #expect([table, left, right].allSatisfy { $0.definition.masterID == 1 })
        #expect([table.definition.subIndex, left.definition.subIndex, right.definition.subIndex] == [-1, 0, 0x0100])
        let chair = try #require(try content.objects.object(guid: 0x4D4F_4301))
        #expect(chair.definition.masterID == 0)
    }

    @Test func loadsTheGlobal() throws {
        #expect(try content.global().chunk(BHAV.self, id: 256) != nil)
    }
}
