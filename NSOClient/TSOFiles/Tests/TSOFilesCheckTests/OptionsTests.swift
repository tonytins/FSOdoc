import Foundation
import Testing
@testable import TSOFilesCheck

@Suite struct OptionsTests {
    @Test func readsEveryOption() throws {
        let options = try Options(
            arguments: ["--far1-variant", "a", "--headers-only", "--max-failures", "5", "/games/tso"],
            environment: [:])

        #expect(options.far1Variant == .a)
        #expect(options.headersOnly)
        #expect(options.maxFailures == 5)
        #expect(options.directory.path == "/games/tso")
    }

    @Test func fallsBackToTheEnvironment() throws {
        let options = try Options(arguments: [], environment: ["TSO_GAME_DIR": "/opt/tso"])
        #expect(options.directory.path == "/opt/tso")
        #expect(options.far1Variant == .b)
        #expect(!options.headersOnly)
    }

    @Test(arguments: [
        [],
        ["--far1-variant", "c", "/x"],
        ["--max-failures", "-1", "/x"],
        ["--max-failures"],
        ["--verbose", "/x"],
        ["/x", "/y"],
        ["--help"],
    ])
    func rejectsBadArguments(arguments: [String]) {
        #expect(throws: Options.UsageError.self) { try Options(arguments: arguments, environment: [:]) }
    }
}
