import Foundation

/// Lists files under a directory in a stable order.
enum DirectoryListing {
    /// Every regular file under `root`, recursively, sorted by path.
    ///
    /// Sorting makes results independent of the file system's own order, which
    /// .NET's `Directory.GetFiles` leaves undefined.
    static func regularFiles(under root: URL) throws -> [URL] {
        // On Linux the enumerator silently yields nothing for a missing directory, so check first.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: root.path])
        }
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: root.path])
        }
        var files: [URL] = []
        for case let url as URL in enumerator where (try? url.resourceValues(forKeys: Set(keys)))?.isRegularFile == true {
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }

    /// A file's path relative to `root`, with `/` separators.
    static func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return filePath }
        return String(filePath.dropFirst(rootPath.count).drop { $0 == "/" })
    }
}
