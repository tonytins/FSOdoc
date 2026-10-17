import Foundation
import TSOFiles

/// The Markdown `tsofiles-check` writes, once, when it checks two installs: how they differ.
///
/// Files holding objects (IFFs, and archives of them) get one row per IFF listing the chunks
/// that differ; other archives get counts.
enum DifferencesReport {
    static func markdown(_ differences: InstallDifferences, first: String, second: String, date: Date) -> String {
        let day = ISO8601DateFormatter.string(from: date, timeZone: .gmt, formatOptions: [.withFullDate])
        var lines = [
            "# Install differences",
            "",
            "How two installed copies of *The Sims Online* differ, file by file. `\(first)` and `\(second)` name",
            "the environment variables that pointed `tsofiles-check` at them: by the project's convention,",
            "`TSO_GAME_DIR` is a production release and `TSO_BETA_DIR` a beta. `tsofiles-check` wrote this on",
            "\(day). It names files, archive entries, IFF chunks (the resources inside the game's object files),",
            "and object IDs (GUIDs); it holds none of the game's own data.",
            "",
            "When NSOClient, or FreeSO (which NSOClient is checked against), behaves differently on the two",
            "copies, this shows what changed in the game's files, before anyone looks for a bug in the code.",
            "It's written once: delete it and run `tsofiles-check` with both variables set to write it again.",
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
                lines.append("")
                if file.kind == .iff || file.entries.contains(where: { $0.name.contains(": ") }) {
                    lines += objectTable(file, first: first, second: second)
                } else {
                    // Archives of other assets: counts only; the names alone run to thousands of lines.
                    let counts = Dictionary(grouping: file.entries, by: \.change).mapValues(\.count)
                    lines.append("Entries only in `\(first)`: \(counts[.onlyInFirst, default: 0]), only in `\(second)`: "
                                 + "\(counts[.onlyInSecond, default: 0]), changed: \(counts[.changed, default: 0]).")
                }
            }
        }
        if differences.isEmpty { lines += ["", "The installs are identical."] }
        return lines.joined(separator: "\n") + "\n"
    }

    /// One row per IFF (or per entry that isn't one), with the chunks that differ by type.
    private static func objectTable(_ file: FileDifference, first: String, second: String) -> [String] {
        struct Row {
            var onlyInFirst: [String] = []
            var onlyInSecond: [String] = []
            var changed: [String] = []
            var guids: [String] = []
        }
        var rows: [String: Row] = [:]
        for entry in file.entries {
            // "chair.iff: BHAV #4096" inside an archive, "BHAV #4096" in an IFF, or a whole entry.
            let parts = entry.name.components(separatedBy: ": ")
            let (iff, chunk): (String, String) = file.kind == .iff
                ? ("(this file)", entry.name)
                : parts.count > 1 ? (parts[0], parts.dropFirst().joined(separator: ": ")) : (entry.name, "whole entry")
            var row = rows[iff] ?? Row()
            switch entry.change {
            case .onlyInFirst: row.onlyInFirst.append(chunk)
            case .onlyInSecond: row.onlyInSecond.append(chunk)
            case .changed: row.changed.append(chunk)
            }
            if let guid = entry.guid, !row.guids.contains(guid) { row.guids.append(guid) }
            rows[iff] = row
        }
        var lines = ["| Entry | Only in `\(first)` | Only in `\(second)` | Changed | Object GUIDs |", "| --- | --- | --- | --- | --- |"]
        for name in rows.keys.sorted() {
            guard let row = rows[name] else { continue }
            let cells = [row.onlyInFirst, row.onlyInSecond, row.changed].map(chunkList)
            lines.append("| `\(escaped(name))` | \(cells[0]) | \(cells[1]) | \(cells[2]) | \(row.guids.joined(separator: ", ")) |")
        }
        return lines
    }

    /// Chunks grouped by type, in order: `BHAV 4096, 4097; STR# 128`.
    private static func chunkList(_ chunks: [String]) -> String {
        var order: [String] = [], ids: [String: [String]] = [:]
        for chunk in chunks {
            let parts = chunk.components(separatedBy: " #")
            let type = parts.count == 2 ? parts[0] : chunk
            if ids[type] == nil { order.append(type) }
            if parts.count == 2 { ids[type, default: []].append(parts[1]) } else { ids[type] = ids[type] ?? [] }
        }
        return order.map { type in
            let list = ids[type] ?? []
            return escaped(list.isEmpty ? type : "\(type) \(list.joined(separator: ", "))")
        }.joined(separator: "; ")
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
    }
}
