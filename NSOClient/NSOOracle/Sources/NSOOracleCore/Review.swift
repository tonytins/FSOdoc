import Foundation

/// `docs/results/nso-review.md`: how `nso-oracle` compares with `fso-oracle`, one section per
/// install. Writing one install's section keeps the others.
public enum Review {
    public struct Run: Sendable {
        /// The install's name, such as `production` or `beta`.
        public var install: String
        public var date: Date
        public var commit: String
        public var comparisons: [Comparison]
        /// Seconds each side took per command, such as `["fso list-objects": 41.2]`.
        public var timings: [String: Double]

        public init(install: String, date: Date, commit: String, comparisons: [Comparison], timings: [String: Double]) {
            self.install = install
            self.date = date
            self.commit = commit
            self.comparisons = comparisons
            self.timings = timings
        }
    }

    /// How many mismatches a section lists; the rest are counted.
    static let listedMismatches = 25

    static let header = """
        # NSOClient review

        SimsCraft is rebuilding the engine of *The Sims Online* (Maxis and EA, 2002) in Swift, as
        NSOClient. Its reference is FreeSO, an open-source C# reimplementation of the same game, as it
        stood in 2017 (the copy in `TSOClient/`). NSOClient counts as correct when it gives the same
        results as FreeSO on the same game files. Neither project ships those files: each run reads a copy
        of the game installed on the machine running it.

        Two command-line programs make the check. `fso-oracle` runs FreeSO's own code, and `nso-oracle`
        runs NSOClient's. Both read the same installed copy of the game and report the same things:

        - **Content:** every object the game lists, whether it loads, and what it's made of: its name, the
          file it comes from, the shared library of routines it uses, and how many routines and tuning
          values it has.
        - **Entry points:** for each object, which routine runs on each event, such as being created,
          each tick of the simulation, or being used.
        - **Objects run alone:** each object placed by itself on an empty lot and simulated for 30 ticks.
          The whole simulation's state is compared, as a checksum, every 10 ticks.
        - **Lots run:** each lot loaded with all its objects, as the game's lot server loads it, and
          simulated for 1,800 ticks, compared every 300. The lots are FreeSO's empty lot (which holds a
          mailbox and other fixtures) and a house built in-game. Where NSOClient reaches something it
          doesn't support yet, the run stops there; it's skipped if every comparison before that matched.
        - **Room maps:** for each test lot, how its walls divide it into rooms. The lots are generated
          layouts, FreeSO's empty lot, a house built in-game, and a small made-up lot.

        Each section below covers one copy of the game. *Production* is a 2002 release of the game
        (FreeSO was built against a 2003 one), and *beta* is a 2002 beta. In each table:

        - **Matched:** both programs gave the same answer.
        - **Mismatched:** their answers differ. Each mismatch is listed, with both answers.
        - **Skipped:** cases left out, by reason: FreeSO itself failed, or NSOClient doesn't support
          something yet (such as one of the game's instructions, its *primitives*).
        - **Answered where FreeSO failed:** objects NSOClient loads that FreeSO can't.

        The last table shows how long each program took for each command.

        `NSOClient/scripts/oracle-review.sh --review` writes this page after each phase of work; earlier
        reviews are in its git history. It holds only counts, IDs, and values, never the game's own data.
        Finer checks, instruction by instruction, run as tests in the repository (scorecard FID-9) until
        `nso-oracle` can load a whole lot by itself.



        """

    /// The file with this run's section written in, keeping other installs' sections.
    public static func updating(_ existing: String?, with run: Run) -> String {
        var sections = sections(of: existing ?? "")
        sections[run.install] = section(for: run)
        // Production first, then the beta, then any others by name.
        let order = ["production", "beta"]
        let names = sections.keys.sorted { (order.firstIndex(of: $0) ?? order.count, $0) < (order.firstIndex(of: $1) ?? order.count, $1) }
        return header + names.compactMap { sections[$0] }.joined(separator: "\n")
    }

    /// One install's section, between markers that mark where it starts and ends.
    static func section(for run: Run) -> String {
        let day = ISO8601DateFormatter.string(from: run.date, timeZone: TimeZone(secondsFromGMT: 0) ?? .current,
                                              formatOptions: [.withFullDate])
        var lines = ["<!-- install: \(run.install) -->", "## \(run.install.prefix(1).uppercased() + run.install.dropFirst())", "",
                     "Run on \(day) at commit `\(run.commit)`.", "",
                     "| Comparison | Matched | Mismatched | Skipped | Answered where FreeSO failed |",
                     "| --- | ---: | ---: | ---: | ---: |"]
        for comparison in run.comparisons {
            lines.append("| \(comparison.name) | \(comparison.matched) | \(comparison.mismatches.count) | "
                         + "\(comparison.skipped.values.reduce(0, +)) | \(comparison.recovered) |")
        }
        for comparison in run.comparisons where !comparison.skipped.isEmpty {
            lines += ["", "**\(comparison.name), skipped:**", ""]
            lines += comparison.skipsByCount.prefix(15).map { "- \($0.count): \(escaped($0.reason))" }
            if comparison.skipped.count > 15 { lines.append("- and \(comparison.skipped.count - 15) more reasons") }
        }
        for comparison in run.comparisons where !comparison.mismatches.isEmpty {
            lines += ["", "**\(comparison.name), mismatched:**", ""]
            lines += comparison.mismatches.prefix(listedMismatches).map { "- \(escaped($0))" }
            if comparison.mismatches.count > listedMismatches {
                lines.append("- and \(comparison.mismatches.count - listedMismatches) more")
            }
        }
        if !run.timings.isEmpty {
            lines += ["", "| Command | Seconds |", "| --- | ---: |"]
            lines += run.timings.sorted { $0.key < $1.key }.map { "| `\($0.key)` | \(String(format: "%.1f", $0.value)) |" }
        }
        lines += ["<!-- end install -->", ""]
        return lines.joined(separator: "\n")
    }

    /// The sections already in a file, by install.
    static func sections(of text: String) -> [String: String] {
        var result: [String: String] = [:]
        var remaining = Substring(text)
        while let start = remaining.range(of: "<!-- install: "), let end = remaining.range(of: "<!-- end install -->", range: start.upperBound..<remaining.endIndex) {
            let nameEnd = remaining[start.upperBound...].range(of: " -->")?.lowerBound ?? start.upperBound
            let name = String(remaining[start.upperBound..<nameEnd])
            result[name] = String(remaining[start.lowerBound..<end.upperBound]) + "\n"
            remaining = remaining[end.upperBound...]
        }
        return result
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "<", with: "&lt;")
    }
}
