# The lot model

The lot model is where things are on a lot: positions and facings, which objects share a tile,
and the walls, floors, and rooms that SimAntics code asks about. It's part of the SimAntics
package. Positions, the tile index, rooms, and multi-tile groups are done; placing objects in the
world, slots, and loading a lot's objects come next. How objects are created and grouped is in
[simantics.md](simantics.md#creating-and-deleting-objects).

## Positions and facings

A `LotPosition` (2017's `LotTilePos`) is a point in sixteenths of a tile, plus a level, where 1
is the ground floor. Objects in an inventory or not yet placed are at `.outOfWorld`.

```swift
let center = LotPosition.center(ofTileX: 4, y: 7, level: 1)     // (72, 120) level 1
print(center.tileX, center.tileY)                                // 4 7
print(center.distance(to: LotPosition(x: 72, y: 136, level: 1))) // 16: one tile
```

`Direction` holds the eight facings as 2017 stores them, one bit each, north first and clockwise.
Object data 1 holds the same facing as a notch from 0 to 7:

```swift
print(Direction(notch: 3), Direction.east.notch, Direction.east.rawValue)   // southEast 2 4
```

## Moving and finding objects

Always move entities with `VM.move(_:to:)`. Like 2017's position change, it keeps the tile index
current and records the entity's room in object data 29:

```swift
vm.move(door, to: .center(ofTileX: 4, y: 4, level: 1))
print(vm.objects(at: .center(ofTileX: 4, y: 4, level: 1))?.map(\.objectID) ?? [])   // [1]
print(vm.objects(withGUID: 0x0000_01CA)?.count ?? 0)
print(vm.objects(inCategory: 5) ?? [])     // listed once the category is set through object data
```

Query results are in object ID order, as 2017's are, since primitives such as Set To Next walk
them in that order. Tiles are keyed as 2017 keys them: a position past the lot's edge shares a
key with a tile on the next row, and every object out of the world shares one entry.

## Walls, floors, and rooms

`Architecture` (2017's `VMArchitecture`) holds the walls and floor patterns of five levels and the
rooms they make. A `WallTile` records which edges of a tile have walls: a tile owns its top-left
(−x) and top-right (−y) edges, and a diagonal wall splits a tile in two. Style 1 is a normal wall;
other styles (fences, for example) don't divide rooms on their own.

```swift
var architecture = try Architecture(width: 8, height: 8)
// Walls around tiles x 2...4, y 3...4.
for y in 3..<5 {
    for x in [2, 5] {
        try architecture.setWall(WallTile(segments: .topLeft, topLeftStyle: 1), atX: x, y: y, level: 1)
    }
}
for x in 2..<5 {
    for y in [3, 5] {
        var tile = try architecture.wall(atX: x, y: y, level: 1)
        tile.segments.insert(.topRight)
        tile.topRightStyle = 1
        try architecture.setWall(tile, atX: x, y: y, level: 1)
    }
}
architecture.regenerateRooms()

let inside = architecture.room(at: .center(ofTileX: 3, y: 3, level: 1))
let room = architecture.rooms[Int(inside)]
print(inside, room.isOutside, room.area, room.bounds)   // 2 false 6 (x 2, y 3, 3 by 2)
```

### How rooms are found

`regenerateRooms()` ports 2017's flood fill (`VMRoomMap.GenerateMap`), level by level, so room
IDs on upper levels follow those below. Room 0 is an unused placeholder, as in 2017.

- Tiles are taken across, then down. Each tile (or half of a diagonal tile) not yet in a room
  starts a new one, which spreads to its neighbors.
- A normal wall stops the spread. A fence, a change of floor pattern, or water doesn't merge the
  two sides, but makes them **adjacent** rooms.
- The fill wraps around the lot's edges, as 2017's does.
- The first room on each level is **outside**, and so is every room adjacent to an outside room.
- Pool tiles (pattern above 65533) form their own rooms. Above the ground floor, tiles without a
  floor join only each other.
- Rooms joined by adjacency share a **light base room**: the lowest-numbered room among them.

Each `RoomMap` entry packs two room IDs, one per side of a diagonal wall (the low 16 bits, then
bits 16–30), and bit 31 marks a horizontal diagonal. `room(at:)` picks the side from where the
position lies within the tile, and returns 0 off the lot.

### When rooms change

Setting a wall or floor marks the architecture dirty. Rooms are regenerated on the next
`vm.tick()`, which then updates every entity's room, as 2017's `Architecture.Tick` and
`RegeneratePortalInfo` do. Until that tick, lookups still see the old rooms, as in 2017:

```swift
try vm.architecture.setFloor(Architecture.poolPattern, atX: 2, y: 2, level: 1)
print(vm.architecture.isDirty)        // true; room(at:) still gives the old rooms
vm.tick()                             // rooms regenerate; data 29 of every entity follows
```

SimAntics code reads rooms through the room data scope: temp 0 picks the room (clamped to the
rooms there are), and data 1, 3, and 4 give whether it's outside, its area, and whether it's a pool.

Routing obstacles, doors and portals, lighting and room score, and support for upper floors aren't
ported yet.

## Blueprints

`Blueprint` reads FreeSO's lot XML (`XmlHouseData`): the size, the category, floors, pools, and
walls. `architecture()` builds the walls and floors as 2017's `VMWorldActivator` does, floors
first, then pools (always on the ground floor), then walls, and generates the rooms:

```swift
let blueprint = try Blueprint(xml: Data(contentsOf: freeSOContent.appendingPathComponent("Blueprints/empty_lot_fso.xml")))
print(blueprint.size, blueprint.floors.count)            // 77, and its floor tiles
try vm.load(blueprint)                                   // the lot's architecture, entities put in rooms
```

Values are read as .NET's `XmlSerializer` reads them: missing attributes are 0, and floor patterns
are truncated to 16 bits. A malformed file throws `BlueprintError.malformed`; a tile off the lot
throws `BlueprintError.offLot`, where 2017 fails with an index out of range. Lots are 1 to 255
tiles a side. The lot's objects aren't loaded yet.

All of this matches 2017 exactly: `fso-oracle room-maps` dumps 2017's room maps and rooms, and
all 61 lots compared (FreeSO's empty lot and 60 synthetic ones with walls, fences, diagonals,
pools, and upper floors) match entry for entry.
