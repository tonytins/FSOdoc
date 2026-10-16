import Foundation
import TSOFiles

/// The Markdown `tsofiles-check` writes, once, when it checks two installs: how they differ.
enum DifferencesReport {
    static func markdown(_ differences: InstallDifferences, first: String, second: String, date: Date) -> String {
        let day = ISO8601DateFormatter.string(from: date, timeZone: .gmt, formatOptions: [.withFullDate])
        var lines = [
            "# Install differences",
            "",
            "Written once by `tsofiles-check` on \(day), comparing the install in `\(first)` with the one in",
            "`\(second)`. It names files, archive entries, IFF chunks, and object GUIDs; it holds no game data.",
            "Delete this file and run `tsofiles-check` with both variables set to compare again.",
            "",
            "Use it for backwards-compatibility notes: when NSOClient or the oracle behaves differently on",
            "the two installs, look here for what the files change before calling it a port bug.",
            "",
            "## Summary",
            "",
            "| | Files |",
            "| --- | --- |",
            "| Identical | \(differences.identicalFileCount) |",
            "| Only in `\(first)` | \(differences.onlyInFirst.count) |",
            "| Only in `\(second)` | \(differences.onlyInSecond.count) |",
            "| Different | \(differences.changedFiles.count) |",
        ]
        for (title, paths) in [(first, differences.onlyInFirst), (second, differences.onlyInSecond)] where !paths.isEmpty {
            lines += ["", "## Only in `\(title)`", ""]
            lines += paths.map { "- `\($0)`" }
        }
        if !differences.changedFiles.isEmpty {
            lines += ["", "## Different files"]
            for file in differences.changedFiles {
                let kind = file.kind.map { "\($0.rawValue), " } ?? ""
                lines += ["", "### `\(file.path)`", "", "\(kind)\(file.firstSize) bytes in `\(first)`, \(file.secondSize) in `\(second)`."]
                guard file.kind != nil else {
                    lines.append("Not compared entry by entry: it isn't a container in both, or doesn't open.")
                    continue
                }
                guard !file.entries.isEmpty else {
                    lines.append("Every entry is the same; the container's layout differs.")
                    continue
                }
                lines += ["", "| Entry | Difference | Object GUID |", "| --- | --- | --- |"]
                for entry in file.entries {
                    let change = switch entry.change {
                    case .onlyInFirst: "only in `\(first)`"
                    case .onlyInSecond: "only in `\(second)`"
                    case .changed: "changed"
                    }
                    lines.append("| `\(entry.name.replacingOccurrences(of: "|", with: "\\|"))` | \(change) | \(entry.guid ?? "") |")
                }
            }
        }
        if differences.isEmpty { lines += ["", "The installs are identical."] }
        return lines.joined(separator: "\n") + "\n"
    }
}
