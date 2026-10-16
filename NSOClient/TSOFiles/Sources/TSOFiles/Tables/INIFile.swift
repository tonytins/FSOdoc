import Foundation

/// A simple INI file: `[section]` headers and `key = value` lines.
///
/// Ports FreeSO's `IniFile`, which the content system uses for `sys/*.ini`.
/// Lines starting with `;` are comments. Key and value lines before the first
/// section, or with an empty key or value, are ignored, and a repeated key
/// keeps its last value, as in FreeSO.
public struct INIFile: Sendable, Equatable {
    /// One section.
    public struct Section: Sendable, Equatable {
        public var name: String
        /// The settings, in the order each key first appeared.
        public var values: [(key: String, value: String)] = []

        /// The value for a key, matched exactly.
        public func value(forKey key: String) -> String? {
            values.first { $0.key == key }?.value
        }

        mutating func set(_ value: String, forKey key: String) {
            if let index = values.firstIndex(where: { $0.key == key }) {
                values[index].value = value
            } else {
                values.append((key, value))
            }
        }

        public static func == (lhs: Section, rhs: Section) -> Bool {
            lhs.name == rhs.name && lhs.values.elementsEqual(rhs.values) { $0 == $1 }
        }
    }

    /// The sections, in file order.
    public let sections: [Section]

    /// The section with the given name, matched exactly.
    public func section(named name: String) -> Section? {
        sections.first { $0.name == name }
    }

    /// Reads INI text. Bytes are decoded as UTF-8 (after any byte order mark), as .NET's `StreamReader` does.
    public init(bytes: Data) throws(INIError) {
        var text = String(decoding: bytes, as: UTF8.self)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        var sections: [Section] = []
        for (lineIndex, rawLine) in Self.lines(of: text).enumerated() {
            let line = rawLine.drop { $0.isWhitespace }
            if line.hasPrefix(";") { continue }
            if line.hasPrefix("[") {
                guard let close = line.lastIndex(of: "]") else { throw .unclosedSection(line: lineIndex + 1) }
                let name = String(line[line.index(after: line.startIndex)..<close])
                guard !sections.contains(where: { $0.name == name }) else {
                    throw .repeatedSection(name) // FreeSO adds sections to a dictionary, which fails on a repeat
                }
                sections.append(Section(name: name))
                continue
            }
            guard let equals = line.firstIndex(of: "="), !sections.isEmpty,
                  line.index(after: equals) < line.endIndex else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equals)...].drop { $0.isWhitespace })
            guard !key.isEmpty else { continue }
            sections[sections.count - 1].set(value, forKey: key)
        }
        self.sections = sections
    }

    /// Reads an INI file from disk.
    public init(contentsOf url: URL) throws {
        try self.init(bytes: Data(contentsOf: url))
    }

    /// Splits text on `\r\n`, `\n`, or `\r`, like `StreamReader.ReadLine`.
    private static func lines(of text: String) -> [Substring] {
        var lines: [Substring] = []
        var start = text.startIndex
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if character == "\n" || character == "\r" || character == "\r\n" {
                lines.append(text[start..<index])
                index = text.index(after: index)
                start = index
            } else {
                index = text.index(after: index)
            }
        }
        if start < text.endIndex { lines.append(text[start...]) }
        return lines
    }
}

/// An error from reading an INI file.
public enum INIError: Error, Equatable, Sendable {
    /// A `[` line has no closing `]`; FreeSO throws here too.
    case unclosedSection(line: Int)
    case repeatedSection(String)
}
