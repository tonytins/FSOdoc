import Foundation

/// Lists files under a directory in a stable order.
public enum DirectoryListing {
    /// Every file under `root`, recursively, sorted by path. Paths are standardized, so on
    /// macOS a file under `/var` is reported under `/var`, not `/private/var`.
    ///
    /// Sorting makes results independent of the file system's own order, which
    /// .NET's `Directory.GetFiles` leaves undefined.
    public static func regularFiles(under root: URL) throws -> [URL] {
        // On Linux the enumerator silently yields nothing for a missing directory, so check first.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: root.path])
        }
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: root.path])
        }
        // `fileExists(atPath:isDirectory:)` is one `stat`. On Linux, `resourceValues` and
        // `attributesOfItem` also look up the owner's account, about 2 ms per file.
        // Links are followed: a link to a file is listed, and a broken link is skipped.
        var files: [URL] = []
        for case let url as URL in enumerator {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                // On macOS the enumerator resolves a root like /var or /tmp to /private/…;
                // standardizing gives back the form callers passed in.
                files.append(url.standardizedFileURL)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    /// A file's path relative to `root`, with `/` separators.
    public static func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return filePath }
        return String(filePath.dropFirst(rootPath.count).drop { $0 == "/" })
    }
}
