import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Object tuning (`.otf`): XML tables of named constants that SimAntics reads.
///
/// Ports FreeSO's `OTFFile`. Every `T` element anywhere in the document is a
/// table with an ID (`i`) and name (`n`); its child elements are keys with an
/// ID (`i`), label (`l`), and value (`v`). Comments are ignored, as in 2017.
/// The VM reads a BCON first and falls back to these tables (see
/// `VMMemory.GetTuningVariable`).
public struct OTFFile: Sendable, Equatable {
    /// One tuning table.
    public struct Table: Sendable, Equatable {
        public var id: Int32
        public var name: String
        public var keys: [Key]

        /// The first key with the given ID.
        public func key(id: Int32) -> Key? {
            keys.first { $0.id == id }
        }
    }

    /// One tuning constant.
    public struct Key: Sendable, Equatable {
        public var id: Int32
        public var label: String
        public var value: Int32
    }

    /// The tables, in document order.
    public let tables: [Table]

    /// The first table with the given ID.
    public func table(id: Int32) -> Table? {
        tables.first { $0.id == id }
    }

    /// Reads an OTF document.
    public init(bytes: Data) throws(OTFError) {
        let document: XMLDocument
        let tableElements: [XMLNode]
        do {
            document = try XMLDocument(data: bytes)
            tableElements = try document.nodes(forXPath: "//T")
        } catch {
            throw .malformedXML(String(describing: error))
        }

        var tables: [Table] = []
        for case let element as XMLElement in tableElements {
            var keys: [Key] = []
            for child in element.children ?? [] where child.kind != .comment {
                guard let keyElement = child as? XMLElement else {
                    throw .unexpectedContent(table: element.attribute(forName: "n")?.stringValue ?? "?")
                }
                keys.append(Key(id: try Self.integer("i", of: keyElement),
                                label: try Self.text("l", of: keyElement),
                                value: try Self.integer("v", of: keyElement)))
            }
            tables.append(Table(id: try Self.integer("i", of: element),
                                name: try Self.text("n", of: element),
                                keys: keys))
        }
        self.tables = tables
    }

    /// Reads an OTF file from disk.
    public init(contentsOf url: URL) throws {
        try self.init(bytes: Data(contentsOf: url))
    }

    private static func text(_ name: String, of element: XMLElement) throws(OTFError) -> String {
        guard let value = element.attribute(forName: name)?.stringValue else {
            throw .missingAttribute(element: element.name ?? "?", attribute: name)
        }
        return value
    }

    /// Parses an integer the way .NET's `int.Parse` does: surrounding whitespace and a sign allowed.
    private static func integer(_ name: String, of element: XMLElement) throws(OTFError) -> Int32 {
        let raw = try text(name, of: element)
        guard let value = Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw .invalidNumber(element: element.name ?? "?", attribute: name, raw)
        }
        return value
    }
}

/// An error from reading an OTF file.
public enum OTFError: Error, Equatable, Sendable {
    case malformedXML(String)
    case missingAttribute(element: String, attribute: String)
    case invalidNumber(element: String, attribute: String, String)
    /// A table contains text or other content where only keys and comments may be.
    case unexpectedContent(table: String)
}
