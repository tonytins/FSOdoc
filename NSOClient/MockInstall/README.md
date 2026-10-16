# Mock install

**Nothing in this folder is from The Sims Online.** It's a tiny, made-up install, for testing
only. Every object, routine, and name here was written for SimsCraft's tests, and none of it
comes from, or stands for, EA's game data. It can't be played.

It exists so tests and CI can run without a copy of TSO: point `TSO_GAME_DIR` at `TSOClient/` here,
and anything that reads an install (`tsofiles-check`, TSOContent, the SimAntics VM) reads this one
the same way.

```sh
TSO_GAME_DIR=NSOClient/MockInstall/TSOClient swift run --package-path NSOClient/TSOFilesCheck tsofiles-check
```

## What's in it

It follows the layout of a real install, with only what the content system needs:

| File | Holds |
| --- | --- |
| `packingslips/objecttable.xml` | The four objects below, by GUID |
| `objectdata/objects/objiff.far` | `mockchair.iff` and `mocktable.iff` |
| `objectdata/globals/global.iff` | One global routine (256) that returns true |
| `objectdata/globals/mockglobals.iff` | The objects' semi-global: one routine (8192) that returns true |

| GUID | Object | Notes |
| --- | --- | --- |
| `0x4D4F4301` | Mock Chair | A one-tile object |
| `0x4D4F4302` | Mock Table | A multi-tile master (master ID 1) |
| `0x4D4F4303` | Mock Table (left) | Its part at offset (0, 0) |
| `0x4D4F4304` | Mock Table (right) | Its part one tile along x |

The GUIDs spell `MOC` followed by a number, so they can't be mistaken for a real object's.

Every object shares two routines. Init (`BHAV` 4097) lets it stand on floor or bare ground at
floor height (object data 42 and 4). Main (`BHAV` 4096) counts its runs in attribute 0. Each
object uses the `mockglobals` semi-global.

## Changing it

The files are kept as they are, not generated. Add to them as tests need: another object, a
chunk type, a quirk to cover. Update the tables above when you do, and keep everything made up.
