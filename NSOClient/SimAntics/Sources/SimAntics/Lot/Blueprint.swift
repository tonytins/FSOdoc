import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// A lot saved as XML (FreeSO's `XmlHouseData`), as FreeSO's `Content/Blueprints` and the
/// lot server store them.
///
/// Only the size, category, and world (floors, pools, walls) are read so far; objects and
/// ambient sounds come with lot loading.
public struct Blueprint: Sendable, Equatable {
    public struct Floor: Sendable, Equatable {
        /// 0 is the ground floor.
        public var level: Int
        public var x: Int
        public var y: Int
        public var pattern: Int
    }

    public struct Pool: Sendable, Equatable {
        public var x: Int
        public var y: Int
    }

    public struct Wall: Sendable, Equatable {
        /// 0 is the ground floor.
        public var level: Int
        public var x: Int
        public var y: Int
        public var tile: WallTile
    }

    /// An object to create on the lot (`XmlHouseDataObject`).
    public struct Object: Sendable, Equatable {
        public var guid: UInt32
        /// 0 leaves the object out of the world; 1 is the ground floor.
        public var level: Int
        /// The tile.
        public var x: Int
        public var y: Int
        public var direction: Direction
        /// A value for every part's object data `groupID`, or 0 to leave it.
        public var group: Int

        public init(guid: UInt32, level: Int = 0, x: Int = 0, y: Int = 0, direction: Direction = .north, group: Int = 0) {
            self.guid = guid
            self.level = level
            self.x = x
            self.y = y
            self.direction = direction
            self.group = group
        }

        /// The facing for a `dir` attribute, as `XmlHouseDataObject.Direction` reads it: 0, 2,
        /// 4, and 6 are north, east, south, and west, and anything else is west.
        public static func direction(dir: Int) -> Direction {
            switch dir {
            case 0: .north
            case 2: .east
            case 4: .south
            default: .west
            }
        }
    }

    /// The width and height in tiles.
    public var size: Int
    public var category: Int
    public var floors: [Floor]
    public var pools: [Pool]
    public var walls: [Wall]
    /// The lot's objects, in the order they're created.
    public var objects: [Object]

    /// Reads blueprint XML.
    ///
    /// Missing attributes read as 0, as .NET's `XmlSerializer` reads them.
    ///
    /// - Throws: ``BlueprintError/malformed(_:)`` if the XML doesn't parse, has no size, or
    ///   has a value that isn't a number.
    public init(xml: Data) throws(BlueprintError) {
        let document: XMLDocument
        do {
            document = try XMLDocument(data: xml)
        } catch {
            throw .malformed("XML doesn't parse: \(error)")
        }
        func elements(_ path: String) throws(BlueprintError) -> [XMLElement] {
            do {
                return try document.nodes(forXPath: path).compactMap { $0 as? XMLElement }
            } catch {
                throw .malformed("can't search for \(path): \(error)")
            }
        }
        func number(_ text: String?, _ what: String) throws(BlueprintError) -> Int {
            guard let text else { return 0 }
            guard let value = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw .malformed("\(what) \"\(text)\" isn't a 32-bit number")
            }
            return Int(value)
        }
        func attributes(_ element: XMLElement) -> (String) throws(BlueprintError) -> Int {
            { (name: String) throws(BlueprintError) -> Int in
                try number(element.attribute(forName: name)?.stringValue, "\(element.name ?? "element") \(name)")
            }
        }

        guard let sizeElement = try elements("/house/size").first else { throw .malformed("no size") }
        size = try number(sizeElement.stringValue, "size")
        category = try number(try elements("/house/category").first?.stringValue, "category")
        floors = try elements("/house/world/floors/floor").map { (element) throws(BlueprintError) in
            let value = attributes(element)
            return Floor(level: try value("level"), x: try value("x"), y: try value("y"), pattern: try value("value"))
        }
        pools = try elements("/house/world/pools/pool").map { (element) throws(BlueprintError) in
            let value = attributes(element)
            return Pool(x: try value("x"), y: try value("y"))
        }
        walls = try elements("/house/world/walls/wall").map { (element) throws(BlueprintError) in
            let value = attributes(element)
            let tile = WallTile(
                segments: WallSegments(rawValue: Int32(try value("segments"))),
                topLeftPattern: UInt16(truncatingIfNeeded: try value("tlp")),
                topRightPattern: UInt16(truncatingIfNeeded: try value("trp")),
                bottomLeftPattern: UInt16(truncatingIfNeeded: try value("blp")),
                bottomRightPattern: UInt16(truncatingIfNeeded: try value("brp")),
                topLeftStyle: UInt16(truncatingIfNeeded: try value("tls")),
                topRightStyle: UInt16(truncatingIfNeeded: try value("trs")))
            return Wall(level: try value("level"), x: try value("x"), y: try value("y"), tile: tile)
        }
        objects = try elements("/house/objects/object").map { (element) throws(BlueprintError) in
            let value = attributes(element)
            // `Convert.ToUInt32(text, 16)`: an optional 0x prefix; a missing GUID reads as 0.
            var text = element.attribute(forName: "guid")?.stringValue ?? "0"
            if text.lowercased().hasPrefix("0x") { text.removeFirst(2) }
            guard let guid = UInt32(text, radix: 16) else { throw .malformed("object guid \"\(text)\" isn't a 32-bit hex number") }
            return Object(guid: guid, level: try value("level"), x: try value("x"), y: try value("y"),
                          direction: Object.direction(dir: try value("dir")), group: try value("group"))
        }
    }

    /// The lot's walls and floors, with rooms generated, as `VMWorldActivator.LoadFromXML`
    /// builds them: floors, then pools (on the ground floor), then walls.
    ///
    /// - Throws: ``BlueprintError/offLot(_:)`` if the size is outside 1...255 or a tile is off
    ///   the lot or above the top level, where FreeSO fails with an index out of range.
    public func architecture() throws(BlueprintError) -> Architecture {
        do {
            var architecture = try Architecture(width: size, height: size)
            for floor in floors {
                try architecture.setFloor(UInt16(truncatingIfNeeded: floor.pattern), atX: floor.x, y: floor.y,
                                          level: floor.level + 1)
            }
            for pool in pools {
                try architecture.setFloor(Architecture.poolPattern, atX: pool.x, y: pool.y, level: 1)
            }
            for wall in walls {
                try architecture.setWall(wall.tile, atX: wall.x, y: wall.y, level: wall.level + 1)
            }
            architecture.regenerateRooms()
            return architecture
        } catch {
            throw .offLot("\(error)")
        }
    }
}

public enum BlueprintError: Error, Equatable, Sendable {
    /// The XML doesn't parse or doesn't describe a lot.
    case malformed(String)
    /// The lot is too big or small, or a tile is outside it.
    case offLot(String)
}
