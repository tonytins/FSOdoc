import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// `packingslips/objecttable.xml`: the objects in `objiff.far`, by GUID.
///
/// Ports the table read in FreeSO's `WorldObjectProvider.Init`. Each `I` element is
/// an object with a GUID (`g`, hexadecimal), the IFF it's in (`n`, without
/// extension), a display name (`o`), a group (`m`), and a sub-index (`i`). Other
/// attributes are ignored.
///
/// The 2002 beta's table has no `o`, which 2017 can't read (it fails on the
/// missing attribute). Here ``Entry/name`` is `nil` instead.
public struct ObjectTable: Sendable, Equatable {
    public struct Entry: Sendable, Equatable {
        public var guid: UInt32
        /// The IFF in `objiff.far`, without the `.iff` extension.
        public var fileName: String
        /// The display name, or `nil` if the table has none.
        public var name: String?
        /// The group (`m`), which is the master ID of a multi-tile object's parts.
        public var group: Int16
        /// The part's sub-index within its group (`i`).
        public var subIndex: Int16
    }

    /// The entries, in document order.
    public let entries: [Entry]

    /// Reads a table.
    ///
    /// - Throws: ``ContentError/invalidObjectTable(_:)`` if the XML is malformed or an
    ///   entry lacks a GUID, file name, group, or sub-index, or one doesn't parse.
    public init(bytes: Data) throws(ContentError) {
        let elements: [XMLNode]
        do {
            elements = try XMLDocument(data: bytes).nodes(forXPath: "//I")
        } catch {
            throw .invalidObjectTable("malformed XML: \(error)")
        }
        var entries: [Entry] = []
        for case let (index, element as XMLElement) in elements.enumerated() {
            entries.append(try Self.entry(element, index: index))
        }
        self.entries = entries
    }

    private static func entry(_ element: XMLElement, index: Int) throws(ContentError) -> Entry {
        func text(_ name: String) throws(ContentError) -> String {
            guard let value = element.attribute(forName: name)?.stringValue else {
                throw .invalidObjectTable("entry \(index) has no \"\(name)\"")
            }
            return value
        }
        // .NET's Convert.ToUInt32(value, 16) and Convert.ToInt16(value): an optional 0x prefix for hex, an optional sign for decimal.
        let rawGUID = try text("g")
        let hexDigits = rawGUID.lowercased().hasPrefix("0x") ? String(rawGUID.dropFirst(2)) : rawGUID
        guard let guid = UInt32(hexDigits, radix: 16) else {
            throw .invalidObjectTable("entry \(index) has an invalid GUID \"\(rawGUID)\"")
        }
        let rawGroup = try text("m"), rawSubIndex = try text("i")
        guard let group = Int16(rawGroup), let subIndex = Int16(rawSubIndex) else {
            throw .invalidObjectTable("entry \(index) has an invalid group \"\(rawGroup)\" or sub-index \"\(rawSubIndex)\"")
        }
        return Entry(guid: guid, fileName: try text("n"), name: element.attribute(forName: "o")?.stringValue,
                     group: group, subIndex: subIndex)
    }
}
