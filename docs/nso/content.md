# TSOContent: loading a game install

TSOContent turns a folder of game files into objects and globals the VM can run. It replaces the
parts of FreeSO's `Content` singleton that SimAntics needs: finding the install, indexing its
files, applying patches, and loading objects by GUID.

## Finding the install

`GameLocator` checks, in order, a configured folder, the `TSO_GAME_DIR` environment variable, and
the usual folders for the OS (on Linux, `$XDG_DATA_HOME/The Sims Online/TSOClient`, then
`game/TSOClient` next to the working directory). A folder counts as an install if it has an
`objectdata` folder in any letter case.

```swift
import TSOContent

let install = try GameLocator().locate()
```

A configured folder or `TSO_GAME_DIR` that isn't an install throws `ContentError.notAnInstall`
rather than falling through to a default, so a typo never loads a different install silently.
Unlike 2017, it doesn't read the Windows registry.

## Loading content

`GameContent` holds one install's content. It indexes every file, loads the PIFF patches, and
registers every object up front. Object files, globals, and tuning load on first use and are kept.

```swift
let content = try GameContent(.init(gameDirectory: install,
                                    freeSOContentDirectory: repository.appendingPathComponent("TSOClient/tso.content/Content")))
```

The `freeSOContentDirectory` form uses FreeSO's layout: patches from `Content/Patch` and standalone
objects from `Content/Objects`. Use `Configuration(gameDirectory:patchDirectory:standaloneObjectDirectory:loadsSprites:)`
to set them separately, or leave both `nil` to load the game's files alone. Sprites stay unloaded
unless `loadsSprites` is set; a headless VM doesn't need them.

Nothing is global. Two `GameContent` values for two installs (say, the production copy and the
beta) can be loaded side by side.

### Files in any letter case

Installs mix letter case (`UIGraphics` beside `uigraphics`). 2017 joins paths as written, which
works on Windows and fails on case-sensitive file systems. `GameFileIndex` looks every path up in
any case:

```swift
let url = content.files.url(for: "ObjectData/Objects/objiff.far")   // finds objectdata/objects/objiff.far
print(content.files.caseCollisions)                                 // paths that differ only in case
```

## Objects

`ObjectProvider` registers the objects listed in `packingslips/objecttable.xml` (all in
`objiff.far`) and every `OBJD` in FreeSO's standalone IFFs. Looking one up loads its IFF with
patches, tuning, sprites if enabled, and its semi-global. Every object in that IFF shares the one
loaded resource.

```swift
if let door = try content.objects.object(guid: 0x0000_01CA) {   // a door, in objiff.far's doors.iff
    print(door.definition.label, door.resource.name)            // the OBJD label, the IFF's name
    let main = try door.resource.chunk(BHAV.self, id: door.definition.bhavMainID)
    print(main?.instructions.count ?? 0)
    print(door.resource.patches.applied, door.resource.patches.skipped)
}
for reference in content.objects.references.prefix(5) {
    print(String(reference.guid, radix: 16), reference.fileName, reference.source)
}
```

A `GameObject` pairs the definition (`OBJD`) with its `ObjectResource`:

| Field | Holds |
| --- | --- |
| `mainFile` | The object's IFF, patched |
| `sprites` | The sprite IFF from `objspf*.far`, if sprites are loaded |
| `tuning` | The object's OTF, from the patches or beside the IFF, if there is one |
| `semiGlobal` | The semi-global the object's `GLOB` names, for shared code and tuning |
| `treesByName` | Routines by name, for Run Tree by Name: the object's, then its semi-global's |
| `patches` | Which PIFF patches applied and which were skipped |
| `tuningFailure` | Why the OTF failed to load, if it exists but did (2017 ignores this silently) |

`chunk(_:id:)` and `chunks(_:)` read from the main file (and the sprite file for sprite chunks), so
code asks for chunks without caring which file holds them.

Where 2017 fails, this keeps loading and reports instead:

- A GUID listed twice keeps its first registration; the rest are in `objects.duplicates`.
- An entry whose IFF isn't in `objiff.far` throws `ContentError.missingFile` for that object only.
- The beta's object table has no display names, which 2017 can't read; `Reference.name` is then `nil`.

When patches change an archived IFF, its objects are registered again from the patched file,
as in 2017, since a patch can add or remove definitions.

## Globals

`objectdata/globals` holds `global.iff`, which every object can call, and the semi-globals that
groups of objects share. `GlobalProvider` loads each by name (in any case) with its patches and
tuning:

```swift
let global = try content.global()                        // global.iff
let doorGlobals = try content.globals.resource(named: "DoorGlobals")   // doorglobals.iff, with doorglobals.otf
print(try doorGlobals.chunks(BHAV.self).count, doorGlobals.tuning != nil)
```

Both `GlobalResource` and `ObjectResource` conform to `IFFResource`, which is what SimAntics reads
code and tuning through: `chunk(_:id:)`, `chunks(_:)`, `tuningTable(id:)`, and `semiGlobal`.

## Errors

Every failure is a `ContentError`:

| Case | When |
| --- | --- |
| `gameNotFound(searched:)` | No default folder is an install; lists the folders tried |
| `notAnInstall(path:)` | A configured folder or `TSO_GAME_DIR` has no `objectdata` |
| `missingFile(_:)` | A file the content needs doesn't exist |
| `invalidFile(path:reason:)` | A file exists but doesn't read or parse |
| `invalidObjectTable(_:)` | `objecttable.xml` is malformed |

A failed load isn't cached, so a later call tries again.
