import Foundation
import Testing
@testable import TSOFiles

/// The TSO install named by `TSO_GAME_DIR`, or `nil` when it isn't set.
let gameDirectory: URL? = ProcessInfo.processInfo.environment["TSO_GAME_DIR"].map {
    URL(fileURLWithPath: $0, isDirectory: true)
}

/// Every object IFF in the install's `objiff.far`, by file name.
func installObjects() throws -> [(name: String, iff: IFFFile)] {
    let directory = try #require(gameDirectory)
    let archive = try FAR1Archive(contentsOf: directory.appendingPathComponent("objectdata/objects/objiff.far"),
                                  variant: .b)
    return try archive.entries.compactMap { entry in
        let data = try archive.data(for: entry)
        guard ContainerKind(header: data) == .iff else { return nil }
        return (entry.fileName, try IFFFile(bytes: data))
    }
}

/// Checks against a real TSO install. Skipped unless `TSO_GAME_DIR` is set; no game data is in the repository.
@Suite(.enabled(if: gameDirectory != nil, "TSO_GAME_DIR is not set"))
struct RealInstallTests {
    @Test func everyBranchTargetIsAnInstructionOrAnExitCode() throws {
        var checked = 0
        var problems: [String] = []
        for (name, iff) in try installObjects() {
            for routine in try iff.chunks(BHAV.self) {
                for (index, instruction) in routine.instructions.enumerated() {
                    for target in [instruction.truePointer, instruction.falsePointer]
                    where Int(target) >= routine.instructions.count && target < 0xFD {
                        problems.append("\(name) BHAV #\(routine.id) instruction \(index) -> \(target)")
                    }
                    checked += 1
                }
            }
        }
        #expect(checked > 100_000)
        #expect(problems.isEmpty, "\(problems.count) bad targets, first: \(problems.prefix(5))")
    }

    /// Where an object's IFF has pie menu strings, every interaction's index must fit them.
    /// That checks the field-encoded TTAB decoding against independent data. Some objects
    /// (mostly expansion ones) keep no TTAs in their IFF; those are counted, not checked.
    @Test func everyLoadedInteractionFitsItsPieMenuStrings() throws {
        var checked = 0
        var tablesWithoutStrings = 0
        var problems: [String] = []
        for (name, iff) in try installObjects() {
            let tableIDs = Set(try iff.chunks(OBJD.self).map(\.treeTableID))
            for tableID in tableIDs {
                guard let table = try iff.chunk(TTAB.self, id: tableID) else { continue }
                guard let strings = try iff.chunk(TTAs.self, id: tableID)?.table, strings.count > 0 else {
                    tablesWithoutStrings += 1
                    continue
                }
                for interaction in table.interactions {
                    checked += 1
                    if interaction.ttaIndex >= strings.count {
                        problems.append("\(name) TTAB #\(tableID) index \(interaction.ttaIndex) of \(strings.count)")
                    }
                }
            }
        }
        #expect(checked > 1_000)
        #expect(tablesWithoutStrings < checked)
        #expect(problems.isEmpty, "\(problems.count) interactions without strings, first: \(problems.prefix(5))")
    }
}
