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
}
