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
| `packingslips/catalog.xml` | Their catalog entries (made-up prices; the parts aren't for sale) |
| `objectdata/objects/objiff.far` | `mockchair.iff`, `mocktable.iff`, `mocklamp.iff`, and `mockregister.iff` |
| `objectdata/globals/global.iff` | One global routine (256) that returns true |
| `objectdata/globals/mockglobals.iff` | The objects' semi-global: one routine (8192) that returns true |

| GUID | Object | Notes |
| --- | --- | --- |
| `0x4D4F4301` | Mock Chair | A one-tile object |
| `0x4D4F4302` | Mock Table | A multi-tile master (master ID 1) |
| `0x4D4F4303` | Mock Table (left) | Its part at offset (0, 0) |
| `0x4D4F4304` | Mock Table (right) | Its part one tile along x |
| `0x4D4F4305` | Mock Lamp | A one-tile object whose main runs a routine by name |
| `0x4D4F4306` | Mock Register | A one-tile object whose main moves money |

The GUIDs spell `MOC` followed by a number, so they can't be mistaken for a real object's.

Every object shares two routines. Init (`BHAV` 4097) lets it stand on floor or bare ground at
floor height (object data 42 and 4). Main (`BHAV` 4096) counts its runs in attribute 0. Each
object uses the `mockglobals` semi-global.

The lamp's main is its own instead. It makes the lamp the stack object, then uses Run Tree By
Name with string table 300 (`STR#` 300: "mock tree", "no such tree") to run "mock tree" (`BHAV`
4098, which adds 1 to attribute 1) on its own stack and on the stack object's, to look up the name
it doesn't have, and to push "mock tree" as a subroutine.

The register's main is its own too. It makes itself the stack object, then uses Transfer Funds
to be paid 100 by the game, pay 30 back, and fail to pay 1,000, each waiting a tick for its
answer, and puts its cash in TempXL 0, which it copies to attribute 2. Objects on a blueprint lot
all have persist ID 0, which FreeSO resolves to the lowest-numbered object, so on the mock lot
the money moves in and out of object 1, and alone on a lot it's the register's own.

`Lots/mock-lot.xml` is a made-up lot for it: a closed 3 by 3 room with floor, a chair out of
the world, a chair in the room, two tables outside (one facing south, with a group ID), the lamp in the
room, the register in the room, and one GUID the install doesn't have, which both oracles leave out.

`fso-oracle` reads it too: its game overlay adds placeholders for what FreeSO loads and
NSOClient doesn't (audio, tuning, wall and floor globals, and so on). CI runs both oracles on
it and reports whether they agree:

```sh
NSOClient/scripts/oracle-review.sh --mock /tmp/oracle
TSO_GAME_DIR="$PWD/NSOClient/MockInstall/TSOClient" TSO_ORACLE_DIR=/tmp/oracle/mock/fso swift test --package-path NSOClient/NSOOracle
```

## Changing it

The files are kept as they are, not generated. Add to them as tests need: another object, a
chunk type, a quirk to cover. Update the tables above when you do, and keep everything made up.
