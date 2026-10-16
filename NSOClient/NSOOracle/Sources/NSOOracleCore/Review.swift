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

        `fso-oracle` runs FreeSO's code (the 2017 snapshot) and `nso-oracle` runs NSOClient, on the
        same install and the same questions. This page compares their answers, one section per
        install, for sessions picking up the work and for public peer review. It's written by
        `NSOClient/scripts/oracle-review.sh --review` after a phase or milestone; earlier reviews are
        in its git history. It holds counts, GUIDs, case IDs, and values, never game data.

        The primitive-by-primitive comparisons run as tests (scorecard FID-9) until `nso-oracle` can
        load a lot by itself.


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
