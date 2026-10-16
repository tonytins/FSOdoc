import Foundation

/// The language of a string table entry, as numbered by the game.
public enum StringLanguage: UInt8, Sendable, CaseIterable {
    /// Use the caller's default language.
    case `default` = 0
    case englishUS = 1
    case englishUK = 2
    case french = 3
    case german = 4
    case italian = 5
    case spanish = 6
    case dutch = 7
    case danish = 8
    case swedish = 9
    case norwegian = 10
    case finnish = 11
    case hebrew = 12
    case russian = 13
    case portuguese = 14
    case japanese = 15
    case polish = 16
    case simplifiedChinese = 17
    case traditionalChinese = 18
    case thai = 19
    case korean = 20
}

/// Localized strings, shared by the `STR#`, `CTSS`, and `TTAs` chunks.
///
/// Ports the parsing and lookup of FreeSO's `STR`. Five formats exist, named
/// by their first two bytes: 0 (Pascal strings), -1 (UTF-8 C strings), -2
/// (Latin-1 string pairs), -3 (pairs with a language code), and -4 (TSO's
/// length-prefixed sets, one per language).
public struct StringTable: Sendable, Equatable {
    /// One string with its comment.
    public struct Item: Sendable, Equatable {
        /// The language code stored with the string. Formats 0 to -2 store none (0).
        public var languageCode: UInt8
        public var value: String
        /// The comment. Formats 0 and -1 have none.
        public var comment: String?
    }

    /// The table's format code, the chunk's first two bytes.
    public let formatCode: Int16

    /// The strings of each language, where index 0 holds English (US).
    ///
    /// Formats 0 to -3 always have 20 sets. Format -4 has as many as the file stores.
    public let languageSets: [[Item]]

    /// The strings to use for a language.
    ///
    /// Like FreeSO's lookup, a language with no strings falls back to English (US).
    /// A language beyond the stored sets (possible in format -4, where the FreeSO
    /// code would crash) falls back the same way.
    ///
    /// - Parameters:
    ///   - language: The language to look up.
    ///   - defaultLanguage: The language `.default` means, the game's configured language.
    public func strings(
        for language: StringLanguage, defaultLanguage: StringLanguage = .englishUS
    ) -> [Item] {
        let resolved = language == .default ? defaultLanguage : language
        let index = Int(resolved.rawValue) - 1
        if languageSets.indices.contains(index), !languageSets[index].isEmpty {
            return languageSets[index]
        }
        return languageSets.first ?? []
    }

    /// The string at an index in a language, or `nil` if the index is out of range.
    public func string(
        at index: Int, language: StringLanguage = .default, defaultLanguage: StringLanguage = .englishUS
    ) -> String? {
        let items = strings(for: language, defaultLanguage: defaultLanguage)
        return items.indices.contains(index) ? items[index].value : nil
    }

    /// The number of English (US) strings, which FreeSO's code treats as the table's length.
    public var count: Int { languageSets.first?.count ?? 0 }

    static let fixedLanguageSetCount = 20

    /// Parses a string table from a chunk.
    static func parse(_ reader: inout ByteReader) throws -> StringTable {
        let formatCode = try reader.readInt16()
        var sets = [[Item]](repeating: [], count: fixedLanguageSetCount)

        // FreeSO's reader returns empty sets when fewer than two bytes follow the format code.
        guard reader.remaining >= 2 else { return StringTable(formatCode: formatCode, languageSets: sets) }

        switch formatCode {
        case 0:
            let count = Int(try reader.readUInt16())
            for _ in 0..<count {
                sets[0].append(Item(languageCode: 0, value: try reader.readPascalString(), comment: nil))
            }
        case -1:
            let count = Int(try reader.readUInt16())
            for _ in 0..<count {
                sets[0].append(Item(languageCode: 0, value: try reader.readNullTerminatedUTF8(), comment: nil))
            }
        case -2:
            let count = Int(try reader.readUInt16())
            for _ in 0..<count {
                sets[0].append(Item(languageCode: 0,
                                    value: try reader.readNullTerminatedLatin1(),
                                    comment: try reader.readNullTerminatedLatin1()))
            }
        case -3:
            let count = Int(try reader.readUInt16())
            for _ in 0..<count {
                let item = Item(languageCode: try reader.readUInt8(),
                                value: try reader.readNullTerminatedLatin1(),
                                comment: try reader.readNullTerminatedLatin1())
                // Code 0 files under English (US); codes above 20 are dropped. The item keeps its code.
                let language = item.languageCode == 0 ? 1 : Int(item.languageCode)
                guard language <= fixedLanguageSetCount else { continue }
                sets[language - 1].append(item)
            }
        case -4:
            let setCount = Int(try reader.readUInt8())
            sets = []
            for _ in 0..<setCount {
                let pairCount = Int(try reader.readUInt16())
                var items: [Item] = []
                for _ in 0..<pairCount {
                    let languageCode = try reader.readUInt8() &+ 1
                    guard let value = try reader.readDotNetString(),
                          let comment = try reader.readDotNetString() else {
                        throw ChunkFormatError(reason: "invalid string length prefix")
                    }
                    items.append(Item(languageCode: languageCode, value: value, comment: comment))
                }
                sets.append(items)
            }
        default:
            // FreeSO's reader leaves every set null here, so any later lookup crashes.
            throw ChunkFormatError(reason: "unknown string table format \(formatCode)")
        }
        return StringTable(formatCode: formatCode, languageSets: sets)
    }
}

/// A string table chunk (`STR#`): object names, UI text, and dialog strings.
public struct STR: IFFChunk {
    public static let typeCode = "STR#"
    public let id: UInt16
    public let label: String
    public let table: StringTable

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        table = try record.parse(byteOrder: .littleEndian) { try StringTable.parse(&$0) }
    }
}

/// Catalog text strings (`CTSS`): an object's catalog name and description.
public struct CTSS: IFFChunk {
    public static let typeCode = "CTSS"
    public let id: UInt16
    public let label: String
    public let table: StringTable

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        table = try record.parse(byteOrder: .littleEndian) { try StringTable.parse(&$0) }
    }
}

/// Pie menu strings (`TTAs`) for the interactions in the ``TTAB`` with the same ID.
public struct TTAs: IFFChunk {
    public static let typeCode = "TTAs"
    public let id: UInt16
    public let label: String
    public let table: StringTable

    public init(record: IFFChunkRecord) throws(IFFChunkError) {
        id = record.id
        label = record.label
        table = try record.parse(byteOrder: .littleEndian) { try StringTable.parse(&$0) }
    }
}
