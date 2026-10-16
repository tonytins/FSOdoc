import Foundation
import Testing
import TSOContent
import TSOFiles
@testable import SimAnticsScript

let gameDirectory: URL? = ProcessInfo.processInfo.environment["TSO_GAME_DIR"].map { URL(fileURLWithPath: $0) }

/// Every routine in the install converts to assembly and back unchanged.
@Suite(.enabled(if: gameDirectory != nil, "TSO_GAME_DIR is not set"))
struct RealAssemblyTests {
    @Test func everyRoutineRoundTrips() throws {
        let content = try GameContent(.init(gameDirectory: try #require(gameDirectory)))
        var files: [IFFFile] = [try content.global().mainFile]
        var seen = Set<String>()
        for reference in content.objects.references where seen.insert(reference.fileName).inserted {
            guard let object = try? content.objects.object(guid: reference.guid) else { continue }
            files.append(object.resource.mainFile)
            if let semiGlobal = object.resource.semiGlobal, seen.insert("semi " + semiGlobal.name).inserted {
                files.append(semiGlobal.mainFile)
            }
        }
        var checked = 0, problems: [String] = []
        for file in files {
            let routines = try file.chunks(BHAV.self)
            let reread = try Assembly.routines(from: Assembly.text(of: routines))
            for (original, copy) in zip(routines, reread) where !equal(original, copy) { problems.append("BHAV #\(original.id) \(original.label)") }
            if reread.count != routines.count { problems.append("routine count \(routines.count) became \(reread.count)") }
            checked += routines.count
        }
        print("Assembly round trip: \(checked) routines, \(problems.count) differ")
        #expect(checked > 10_000)
        #expect(problems.isEmpty, "\(problems.prefix(5))")
    }
}
