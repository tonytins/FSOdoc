import Foundation

/// The global tuning constants in `tuning.dat`.
///
/// Ports FreeSO's `Tuning`. The file is a Persist container (body type 1 or 3)
/// holding RefPack-compressed data: a list of named entries, each a list of
/// key and value strings. Strings are obfuscated by adding 13 to every byte.
/// Entry names are matched in lower case, as in 2017.
public struct TuningFile: Sendable, Equatable {
    /// One named group of settings.
    public struct Entry: Sendable, Equatable {
        public var name: String
        /// The settings in file order.
        public var values: [(key: String, value: String)]

        /// The value for a key, matched exactly.
        public func value(forKey key: String) -> String? {
            values.first { $0.key == key }?.value
        }

        /// A value parsed as a number, as `TuningEntry.GetNum` does with US formatting.
        public func number(forKey key: String) -> Float? {
            value(forKey: key).flatMap { Float($0.trimmingCharacters(in: .whitespaces)) }
        }

        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.name == rhs.name && lhs.values.elementsEqual(rhs.values) { $0 == $1 }
        }
    }

    /// The entries in file order.
    public let entries: [Entry]

    /// The entry with the given name, ignoring case.
    public func entry(named name: String) -> Entry? {
        let wanted = name.lowercased()
        return entries.first { $0.name.lowercased() == wanted }
    }

    /// Reads `tuning.dat`.
    public init(bytes: Data) throws(TuningError) {
        let compressed: (data: Data, decompressedSize: Int)?
        do {
            compressed = try Self.readContainer(bytes)
        } catch {
            throw .truncated(error)
        }
        guard let compressed else { throw .notATuningFile }

        let body: Data
        do {
            body = try RefPack.decompress(compressed.data, decompressedSize: compressed.decompressedSize)
        } catch {
            throw .decompressionFailed(error)
        }

        do {
            entries = try Self.readEntries(body)
        } catch let error as TuningError {
            throw error
        } catch let error as EndOfDataError {
            throw .truncated(error)
        } catch {
            throw .truncated(EndOfDataError(offset: 0, needed: 0, available: 0))
        }
    }

    /// Reads `tuning.dat` from disk.
    public init(contentsOf url: URL) throws {
        try self.init(bytes: Data(contentsOf: url))
    }

    /// Reads the Persist header, or returns `nil` if the body type or compression isn't one 2017 accepts.
    private static func readContainer(_ bytes: Data) throws(EndOfDataError) -> (data: Data, decompressedSize: Int)? {
        var reader = ByteReader(bytes, byteOrder: .littleEndian)
        let bodyType = try reader.readUInt8()
        guard bodyType == 0x01 || bodyType == 0x03 else { return nil }
        let decompressedSize = Int(try reader.readUInt32())
        let compressedSize = Int(try reader.readUInt32())
        _ = try reader.readUInt32() // stream body size
        guard try reader.readUInt16() == 0xFB10 else { return nil }
        try reader.skip(3) // the RefPack header's own size; 2017 uses the Persist header's instead
        return (reader.readBytes(upTo: compressedSize), decompressedSize)
    }

    private static func readEntries(_ body: Data) throws -> [Entry] {
        var reader = ByteReader(body, byteOrder: .littleEndian)
        let count = try reader.readUInt32()
        var entries: [Entry] = []
        var seenNames = Set<String>()
        for _ in 0..<count {
            let name = try readString(&reader)
            // 2017 files entries by lower-case name in a dictionary, which fails on a repeat.
            guard seenNames.insert(name.lowercased()).inserted else { throw TuningError.repeatedEntry(name) }
            let valueCount = try reader.readUInt32()
            var values: [(key: String, value: String)] = []
            var seenKeys = Set<String>()
            for _ in 0..<valueCount {
                let key = try readString(&reader)
                guard seenKeys.insert(key).inserted else { throw TuningError.repeatedKey(entry: name, key: key) }
                values.append((key, try readString(&reader)))
            }
            entries.append(Entry(name: name, values: values))
        }
        return entries
    }

    /// A 7-bit length, then that many bytes, each 13 more than the ASCII character.
    private static func readString(_ reader: inout ByteReader) throws -> String {
        var length = 0
        var shift = 0
        while true {
            guard shift < 35 else { throw TuningError.invalidLength }
            let byte = try reader.readUInt8()
            length |= Int(byte & 0x7F) << shift
            shift += 7
            if byte & 0x80 == 0 { break }
        }
        let bytes = reader.readBytes(upTo: length) // .NET's ReadBytes stops at the end
        return ASCII.decode(bytes.map { $0 &- 13 })
    }
}

/// An error from reading `tuning.dat`.
public enum TuningError: Error, Equatable, Sendable {
    /// The Persist body type or compression ID isn't one 2017 accepts.
    case notATuningFile
    case truncated(EndOfDataError)
    case decompressionFailed(RefPackError)
    case invalidLength
    case repeatedEntry(String)
    case repeatedKey(entry: String, key: String)
}
