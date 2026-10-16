import Foundation
import TSOFiles

/// Several FAR1 archives read as one, by entry name.
///
/// Ports FreeSO's `FAR1Provider` lookup: when two entries share a name, the later
/// one wins, archives being read in sorted path order (FreeSO's order was the file
/// system's). Names match exactly, as in FreeSO.
struct FAR1Collection: Sendable {
    private let archives: [FAR1Archive]
    private let entriesByName: [String: (archive: Int, entry: FAR1Archive.Entry)]
    let paths: [String]

    /// Opens archives by their stored paths in an install.
    init(paths: [String], in files: GameFileIndex) throws(ContentError) {
        var archives: [FAR1Archive] = []
        var entriesByName: [String: (archive: Int, entry: FAR1Archive.Entry)] = [:]
        for path in paths {
            guard let url = files.url(for: path) else { throw .missingFile(path) }
            let archive: FAR1Archive
            do {
                archive = try FAR1Archive(contentsOf: url, variant: .b)
            } catch {
                throw .invalidFile(path: path, reason: String(describing: error))
            }
            for entry in archive.entries { entriesByName[entry.fileName] = (archives.count, entry) }
            archives.append(archive)
        }
        self.archives = archives
        self.entriesByName = entriesByName
        self.paths = paths
    }

    /// An entry's data, or `nil` if no archive has it.
    func data(named name: String) throws(ContentError) -> Data? {
        guard let (index, entry) = entriesByName[name] else { return nil }
        do {
            return try archives[index].data(for: entry)
        } catch {
            throw .invalidFile(path: "\(paths[index])/\(name)", reason: String(describing: error))
        }
    }
}
