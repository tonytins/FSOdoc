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

    @Test func readsTheGlobalTuning() throws {
        let directory = try #require(gameDirectory)
        let tuning = try TuningFile(contentsOf: directory.appendingPathComponent("tuning.dat"))
        #expect(!tuning.entries.isEmpty)
        #expect(tuning.entries.allSatisfy { !$0.name.isEmpty && !$0.name.contains("?") }, "names decode to plain ASCII")
    }

    @Test func readsTheDataDefinition() throws {
        let directory = try #require(gameDirectory)
        let definition = try DataDefinition(contentsOf: directory.appendingPathComponent("TSOData_datadefinition.dat"))
        #expect(definition.structs.count > 10)
        let structIDs = Set(definition.structs.map(\.id))
        let orphans = definition.derivedStructs.filter { !structIDs.contains($0.parentID) }
        #expect(orphans.isEmpty, "every derived struct masks a known struct: \(orphans.map(\.id))")
        #expect(definition.structure(named: "Avatar") != nil)
    }

    @Test func readsEveryTuningTable() throws {
        let directory = try #require(gameDirectory)
        var tables = 0
        for url in try DirectoryListing.regularFiles(under: directory) where url.pathExtension.lowercased() == "otf" {
            tables += try OTFFile(contentsOf: url).tables.count
        }
        #expect(tables > 0)
    }

    /// The INI files FreeSO's client reads. Others may be malformed: `sys/nametohostmap.ini`
    /// repeats a section, which FreeSO's reader rejects too, but no code loads that file.
    @Test(arguments: ["sys/gameentry.ini", "sys/cityselector.ini"])
    func readsTheINIFilesTheClientUses(path: String) throws {
        let directory = try #require(gameDirectory)
        let ini = try INIFile(contentsOf: directory.appendingPathComponent(path))
        #expect(!ini.sections.isEmpty)
    }

    /// FreeSO's own patches, which ship in the snapshot (PIFF is FreeSO's format, not TSO's).
    /// They were written against TSO's 2003 production files, so on another version of
    /// the game (such as the owner's 2002 beta) some don't fit and are skipped. Every
    /// patched file must still parse, and most patches must apply.
    @Test func appliesFreeSOsShippedPatchesThatFitTheInstall() throws {
        let directory = try #require(gameDirectory)
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let registry = try PatchRegistry(directory: repository.appendingPathComponent("TSOClient/tso.content/Content/Patch"))
        // The snapshot ships one empty patch file; FreeSO skipped it silently.
        #expect(registry.failures.map(\.path) == ["skillobjects_10xmultiplier.piff"])

        let archive = try FAR1Archive(contentsOf: directory.appendingPathComponent("objectdata/objects/objiff.far"),
                                      variant: .b)
        var applied: [String] = []
        var skipped: [String] = []
        var unparsable: [String] = []
        for entry in archive.entries where !registry.patches(for: entry.fileName).isEmpty {
            let original = try IFFFile(bytes: try archive.data(for: entry))
            let outcome = registry.applyingPatches(to: original, fileName: entry.fileName)
            applied += outcome.applied
            skipped += outcome.skipped.map { "\($0.name): \($0.reason)" }
            for record in outcome.file.chunks where (try? IFFChunkTypes.type(forCode: record.typeCode)?.init(record: record)) == nil
            && IFFChunkTypes.type(forCode: record.typeCode) != nil
            && (try? original.chunk(ofType: record.typeCode, id: record.id).map { try IFFChunkTypes.type(forCode: $0.typeCode)?.init(record: $0) }) != nil {
                unparsable.append("\(entry.fileName): \(record.typeCode) #\(record.id)")
            }
        }
        print("Applied \(applied.count) shipped patches; skipped \(skipped.count): \(skipped)")
        #expect(applied.count >= 15)
        #expect(unparsable.isEmpty, "patching made chunks unparsable: \(unparsable)")
    }

    @Test func everyBHAVReadsBackFromItsEncoding() throws {
        var checked = 0, problems: [String] = []
        for (name, iff) in try installObjects() {
            for routine in try iff.chunks(BHAV.self) {
                let reread = try BHAV(record: IFFChunkRecord(typeCode: "BHAV", id: routine.id, flags: 0,
                                                             label: routine.label, data: routine.encoded()))
                if reread.instructions != routine.instructions || reread.version != routine.version
                    || reread.argumentCount != routine.argumentCount || reread.localCount != routine.localCount
                    || reread.type != routine.type || reread.flags != routine.flags {
                    problems.append("\(name) BHAV #\(routine.id)")
                }
                checked += 1
            }
        }
        #expect(checked > 10_000)
        #expect(problems.isEmpty, "\(problems.count) routines differ, first: \(problems.prefix(5))")
    }
}
