import Foundation
import TSOFiles

/// Every file in an install, found by relative path in any letter case.
///
/// Installs mix letter case (`UIGraphics` beside `uigraphics`), and FreeSO's code
/// joined paths as written, which works on Windows and fails on case-sensitive file
/// systems. Looking every path up here fixes that. Paths use `/` separators; `\` is
/// accepted in lookups.
public struct GameFileIndex: Sendable {
    /// The install folder.
    public let root: URL
    /// Every file's path relative to ``root``, as stored on disk, sorted.
    public let relativePaths: [String]
    /// Paths that differ only in letter case, each group sorted. Lookups return the first.
    public let caseCollisions: [[String]]

    private let pathsByKey: [String: String]

    /// Lists every file under `root`.
    ///
    /// - Throws: ``ContentError/invalidFile(path:reason:)`` if the folder can't be listed.
    public init(root: URL) throws(ContentError) {
        let urls: [URL]
        do {
            urls = try DirectoryListing.regularFiles(under: root)
        } catch {
            throw .invalidFile(path: root.path, reason: String(describing: error))
        }
        self.init(root: root, relativePaths: urls.map { DirectoryListing.relativePath(of: $0, under: root) })
    }

    /// An index over a known list of paths, for tests and tools.
    public init(root: URL, relativePaths: [String]) {
        self.root = root
        self.relativePaths = relativePaths.sorted()
        var pathsByKey: [String: String] = [:]
        var collisions: [String: [String]] = [:]
        for path in self.relativePaths {
            let key = Self.key(for: path)
            if let first = pathsByKey[key] {
                collisions[key, default: [first]].append(path)
            } else {
                pathsByKey[key] = path
            }
        }
        self.pathsByKey = pathsByKey
        caseCollisions = collisions.values.sorted { $0[0] < $1[0] }
    }

    /// The path of a file as stored on disk, if the install has it.
    public func storedPath(for relativePath: String) -> String? {
        pathsByKey[Self.key(for: relativePath)]
    }

    /// The location of a file, if the install has it.
    public func url(for relativePath: String) -> URL? {
        storedPath(for: relativePath).map { root.appendingPathComponent($0) }
    }

    /// The stored paths whose lower-case form satisfies `predicate`, sorted.
    public func paths(where predicate: (String) -> Bool) -> [String] {
        relativePaths.filter { predicate(Self.key(for: $0)) }
    }

    private static func key(for path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/").lowercased()
    }
}
