import Foundation

/// The data service's schema, from `TSOData_datadefinition.dat`.
///
/// Ports FreeSO's `TSODataDefinition`. The file holds three lists (two of
/// structs, one of derived structs, which are masked views of a parent struct)
/// and a string table that names them. The data service uses these to map
/// avatar, lot, and city fields to wire IDs.
public struct DataDefinition: Sendable, Equatable {
    /// How a struct field holds its values.
    public enum FieldClassification: UInt8, Sendable {
        case singleField = 0
        case map = 1
        case list = 2
    }

    /// Whether a derived struct keeps or removes a field of its parent.
    public enum FieldMaskType: UInt8, Sendable {
        case keep = 1
        case remove = 2
    }

    public struct StringEntry: Sendable, Equatable {
        public var id: UInt32
        public var value: String
        public var unknown: UInt8
    }

    public struct Field: Sendable, Equatable {
        public var id: UInt32
        /// The field name, or `nil` if the string table has no entry for it.
        public var name: String?
        /// The raw classification byte. See ``classification``.
        public var classificationValue: UInt8
        public var typeID: UInt32
        public var parentID: UInt32

        public var classification: FieldClassification? { FieldClassification(rawValue: classificationValue) }
    }

    public struct Struct: Sendable, Equatable {
        public var id: UInt32
        public var name: String?
        public var fields: [Field]
    }

    public struct FieldMask: Sendable, Equatable {
        public var id: UInt32
        public var name: String?
        /// The raw mask type byte. See ``type``.
        public var typeValue: UInt8

        public var type: FieldMaskType? { FieldMaskType(rawValue: typeValue) }
    }

    public struct DerivedStruct: Sendable, Equatable {
        public var id: UInt32
        public var name: String?
        /// The ID of the struct this one masks.
        public var parentID: UInt32
        public var fieldMasks: [FieldMask]
    }

    public let fileID: UInt32
    public let strings: [StringEntry]
    /// The structs of the first two lists, in file order.
    public let structs: [Struct]
    public let derivedStructs: [DerivedStruct]

    /// The first struct with the given ID.
    public func structure(id: UInt32) -> Struct? {
        structs.first { $0.id == id }
    }

    /// The struct with the given name.
    public func structure(named name: String) -> Struct? {
        structs.first { $0.name == name }
    }

    /// Reads a data definition.
    public init(bytes: Data) throws(DataDefinitionError) {
        let raw: RawLists
        do {
            raw = try Self.readLists(bytes)
        } catch {
            throw .truncated(error)
        }

        func name(_ id: UInt32) -> String? {
            raw.strings.first { $0.id == id }?.value
        }
        func fields(of entry: RawEntry) -> [Field] {
            entry.fields.map {
                Field(id: $0.nameID, name: name($0.nameID), classificationValue: $0.flag,
                      typeID: $0.typeID, parentID: entry.nameID)
            }
        }

        let structs = (raw.list1 + raw.list2).map { Struct(id: $0.nameID, name: name($0.nameID), fields: fields(of: $0)) }
        // 2017 indexes structs by name in a dictionary, which fails on a missing or repeated name.
        var names = Set<String>()
        for item in structs {
            guard let structName = item.name else { throw .unnamedStruct(id: item.id) }
            guard names.insert(structName).inserted else { throw .repeatedStructName(structName) }
        }

        fileID = raw.fileID
        strings = raw.strings
        self.structs = structs
        derivedStructs = raw.list3.map { entry in
            DerivedStruct(id: entry.nameID, name: name(entry.nameID), parentID: entry.parentID,
                          fieldMasks: entry.fields.map { FieldMask(id: $0.nameID, name: name($0.nameID), typeValue: $0.flag) })
        }
    }

    /// Reads a data definition from disk.
    public init(contentsOf url: URL) throws {
        try self.init(bytes: Data(contentsOf: url))
    }

    // MARK: Private

    private struct RawField {
        var nameID: UInt32
        var flag: UInt8
        var typeID: UInt32
    }

    private struct RawEntry {
        var nameID: UInt32
        var parentID: UInt32
        var fields: [RawField]
    }

    private struct RawLists {
        var fileID: UInt32
        var list1: [RawEntry]
        var list2: [RawEntry]
        var list3: [RawEntry]
        var strings: [StringEntry]
    }

    private static func readLists(_ bytes: Data) throws(EndOfDataError) -> RawLists {
        var reader = ByteReader(bytes, byteOrder: .littleEndian)
        let fileID = try reader.readUInt32()
        let list1 = try readList(&reader, hasParent: false)
        let list2 = try readList(&reader, hasParent: false)
        let list3 = try readList(&reader, hasParent: true)
        let stringCount = try reader.readUInt32()
        var strings: [StringEntry] = []
        for _ in 0..<stringCount {
            strings.append(StringEntry(id: try reader.readUInt32(),
                                       value: try reader.readNullTerminatedLatin1(),
                                       unknown: try reader.readUInt8()))
        }
        return RawLists(fileID: fileID, list1: list1, list2: list2, list3: list3, strings: strings)
    }

    /// Reads one list. Derived structs store a parent ID and no field types.
    private static func readList(_ reader: inout ByteReader, hasParent: Bool) throws(EndOfDataError) -> [RawEntry] {
        let count = try reader.readUInt32()
        var entries: [RawEntry] = []
        for _ in 0..<count {
            let nameID = try reader.readUInt32()
            let parentID = hasParent ? try reader.readUInt32() : 0
            let fieldCount = try reader.readUInt32()
            var fields: [RawField] = []
            for _ in 0..<fieldCount {
                let fieldNameID = try reader.readUInt32()
                let flag = try reader.readUInt8()
                let typeID = hasParent ? 0 : try reader.readUInt32()
                fields.append(RawField(nameID: fieldNameID, flag: flag, typeID: typeID))
            }
            entries.append(RawEntry(nameID: nameID, parentID: parentID, fields: fields))
        }
        return entries
    }
}

/// An error from reading a data definition.
public enum DataDefinitionError: Error, Equatable, Sendable {
    case truncated(EndOfDataError)
    /// A struct's name isn't in the string table.
    case unnamedStruct(id: UInt32)
    /// Two structs share a name.
    case repeatedStructName(String)
}
