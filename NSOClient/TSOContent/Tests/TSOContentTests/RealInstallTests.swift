import Foundation
import Testing
import TSOFiles
@testable import TSOContent

/// The TSO install named by `TSO_GAME_DIR`, or `nil` when it isn't set.
let gameDirectory: URL? = ProcessInfo.processInfo.environment["TSO_GAME_DIR"].map {
    URL(fileURLWithPath: $0, isDirectory: true)
}

/// FreeSO's own content folder in the 2017 snapshot: shipped patches and standalone objects.
let freeSOContentDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("../../../../TSOClient/tso.content/Content").standardizedFileURL

/// `objects.tsv` (`fso-oracle list-objects`) in the folder `NSOClient/scripts/oracle-fixtures.sh`
/// writes, named by `TSO_ORACLE_DIR`, or `nil`.
let oracleObjects: URL? = ProcessInfo.processInfo.environment["TSO_ORACLE_DIR"].map {
    URL(fileURLWithPath: $0).appendingPathComponent("objects.tsv")
}

/// Checks against a real TSO install. Skipped unless `TSO_GAME_DIR` is set; no game data is in the repository.
@Suite(.enabled(if: gameDirectory != nil, "TSO_GAME_DIR is not set"))
struct RealInstallTests {
    let content: GameContent

    init() throws {
        content = try GameContent(.init(gameDirectory: try #require(gameDirectory),
                                        freeSOContentDirectory: freeSOContentDirectory))
    }

    @Test func locatesTheInstallFromTheEnvironment() throws {
        #expect(try GameLocator().locate().standardizedFileURL == gameDirectory?.standardizedFileURL)
    }

    @Test func indexesTheInstallWithoutCaseCollisions() {
        #expect(content.files.relativePaths.count > 1_000)
        #expect(content.files.caseCollisions.isEmpty, "\(content.files.caseCollisions.prefix(5))")
    }

    @Test func loadsTheGlobal() throws {
        let global = try content.global()
        #expect(try global.chunks(BHAV.self).count > 100)
        #expect(global.tuning != nil)
    }

    /// Every registered object loads with its semi-global. Objects whose IFF the install
    /// lacks are allowed (the 2002 beta lists `skillcheater` without shipping it); any
    /// other failure isn't.
    @Test func loadsEveryRegisteredObject() throws {
        var loaded = 0, absent: [UInt32] = [], missingFiles: [String] = [], failures: [String] = []
        var semiGlobals = Set<String>()
        var tuningFailures = Set<String>(), skippedPatches = Set<String>()
        for reference in content.objects.references {
            do {
                guard let object = try content.objects.object(guid: reference.guid) else {
                    absent.append(reference.guid)
                    continue
                }
                loaded += 1
                if let name = object.resource.semiGlobal?.name { semiGlobals.insert(name) }
                if let failure = object.resource.tuningFailure { tuningFailures.insert(failure) }
                skippedPatches.formUnion(object.resource.patches.skipped.map(\.name))
            } catch .missingFile(let path) {
                missingFiles.append(path)
            } catch {
                failures.append("\(String(reference.guid, radix: 16)) \(reference.fileName): \(error)")
            }
        }
        print("""
            TSOContent real install: \(content.objects.references.count) registered, \(loaded) loaded, \
            \(absent.count) absent from their files, \(missingFiles.count) with missing files \(missingFiles), \
            \(failures.count) failed; \
            \(semiGlobals.count) semi-globals; \(tuningFailures.count) tuning failures; \
            \(skippedPatches.count) patches skipped; \(content.objects.duplicates.count) duplicate GUIDs
            """)
        #expect(loaded > 2_000)
        #expect(failures.isEmpty, "\(failures.count) failures, first: \(failures.prefix(5))")
        #expect(tuningFailures.isEmpty, "\(tuningFailures.prefix(5))")
    }

    private func loadingError(guid: UInt32) -> ContentError? {
        do {
            _ = try content.objects.object(guid: guid)
            return nil
        } catch {
            return error
        }
    }

    /// Compares every object with what FreeSO's content system loads (`fso-oracle list-objects`).
    ///
    /// Where FreeSO loads an object, the label, resource, semi-global, routine names, BHAV
    /// count, and tuning table count must match. Where FreeSO fails (on an older install,
    /// FreeSO's patches for 2003 files don't fit), the object must still load here.
    @Test(.enabled(if: oracleObjects != nil, "TSO_ORACLE_DIR is not set"))
    func matchesFreeSOsContentSystem() throws {
        let expected = try String(contentsOf: try #require(oracleObjects), encoding: .utf8)
            .split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        var compared = 0, recovered = 0, mismatches: [String] = []
        for fields in expected {
            let guid = try #require(UInt32(fields[0], radix: 16))
            switch fields[1] {
            case "missing":
                if try content.objects.object(guid: guid) != nil { mismatches.append("\(fields[0]): FreeSO has no OBJD") }
            case "error":
                // skillcheater's IFF isn't in the beta (FreeSO fails with a null reference); anything else must load.
                switch loadingError(guid: guid) {
                case nil: recovered += 1
                case .missingFile? where fields[2] == "NullReferenceException": break
                case let error?: mismatches.append("\(fields[0]): \(error)")
                }
            default:
                let object = try #require(try content.objects.object(guid: guid), "\(fields[0])")
                let resource = object.resource
                let actual = [fields[0], object.definition.label, resource.name, resource.semiGlobal?.name ?? "-",
                              "\(resource.treesByName.count)", "\(try resource.mainFile.chunks(BHAV.self).count)",
                              "\(resource.tuning?.tables.count ?? 0)"]
                // Later columns describe SimAntics entities and are compared in that package.
                if actual != Array(fields.prefix(actual.count)) { mismatches.append("FreeSO \(fields) Swift \(actual)") }
                compared += 1
            }
        }
        print("TSOContent against FreeSO: \(compared) objects compared, \(mismatches.count) mismatched, \(recovered) loaded where FreeSO failed")
        #expect(compared > 2_000)
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches, first: \(mismatches.prefix(5))")
    }
}
