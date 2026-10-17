# NSOClient scorecard

Maintained by hand from the source tree and `swift test` in each package under
[`NSOClient/`](../NSOClient/). Statuses are checked against the code at the date below; when this
page and [roadmap.md](roadmap.md) disagree, this page wins and the roadmap gets re-estimated. Every
`done` row names the code or test that proves it.

**As of:** 2026-10-16 · Swift 6.3.3 on Linux x86_64 · `swift test`: TSOFiles 131 passed (8 need
`TSO_GAME_DIR`), TSOFilesCheck 12 passed, TSOContent 40 passed (4 need `TSO_GAME_DIR`),
SimAntics 104 passed (1 needs `TSO_GAME_DIR`), SimsScript 12
passed (1 needs `TSO_GAME_DIR`), NSOOracle 11 passed (5 need `TSO_GAME_DIR` and `TSO_ORACLE_DIR`). Tests that need either variable are skipped without it. The
owner has two installs: a 2002 production copy (`TSO_GAME_DIR`, which the tests and oracle use since
2026-10-16) and a 2002 beta (`TSO_BETA_DIR`). FreeSO targets the 2003 production files, so differences
are expected and handled for backwards compatibility; [install-differences.md](results/install-differences.md)
lists them.

Status values: `done` (works and is tested), `partial` (works with gaps, named in the note),
`missing` (not started).

## Summary

| Area | Done | Partial | Missing | Key numbers |
|---|---:|---:|---:|---|
| [Formats](#formats) | 13 | 0 | 8 | 128 test cases; real install (2002 beta): 94 containers, 82,131 entries, 51,620 typed chunks, tuning, data definition, and OTFs, 0 failures |
| [Content](#content) | 3 | 2 | 4 | real install: 2,694 objects registered, 2,693 load (the beta lacks one IFF), 19 semi-globals; matches FreeSO on all 2,649 objects FreeSO loads, and loads 44 more it can't |
| [SimAntics](#simantics) | 2 | 6 | 7 | 11 primitives match FreeSO on every oracle case they can run; 2,753 objects run alone (production) match FreeSO digest for digest over 30 ticks; FreeSO's empty lot runs 1,800 ticks in step |
| [Fidelity](#fidelity) | 7 | 5 | 2 | install scan and real-data invariants clean; content and entry points match FreeSO object for object; Expression matches on 3,809 cases; single-object runs and the mock lot match digest for digest |
| [Determinism](#determinism) | 1 | 2 | 2 | the random seed matches FreeSO tick for tick |
| [Reliability](#reliability) | 4 | 1 | 2 | 0 force unwraps, 0 `try!`, 0 `fatalError` in sources |
| [Tests and tooling](#tests-and-tooling) | 5 | 2 | 0 | |
| [Platforms](#platforms) | 3 | 0 | 1 | |
| [Scripting](#scripting) | 3 | 1 | 3 | proof of concept: all 15,723 routines round-trip through assembly; compiled scripts run on the VM |
| [Known differences from FreeSO](#known-differences-from-freeso) | | | | 24 deliberate |
| [Open bugs](#open-bugs) | 0 | 0 | 0 | none filed |

## Formats

Package: [TSOFiles](../NSOClient/TSOFiles/). Ports `TSOClient/tso.files` (see
[fso/files.md](fso/files.md)).

| Id | Target | Status | Note |
|---|---|---|---|
| FMT-1 | Bounds-checked binary reader, both byte orders, .NET-compatible ASCII | done | `Binary/ByteReader.swift`, `Binary/ASCII.swift`; `ByteReaderTests` (7 tests: byte orders, signed values, 24-bit, end of data, `readBytes(upTo:)`, slices, ASCII replacement) |
| FMT-2 | RefPack decompression matching `Decompresser.Decompress` | done | `Compression/RefPack.swift`; `RefPackTests` covers all four command forms, the 6-byte passthrough, output growth, 0xFD continuing, 0xFC stop, and two error paths |
| FMT-3 | FAR1 archives, variants 1a and 1b | done | `Archives/FAR1Archive.swift`; `FAR1ArchiveTests` (both variants, bad version, truncated manifest, out-of-bounds entry) |
| FMT-4 | FAR3 archives with asset IDs and RefPack entries | done | `Archives/FAR3Archive.swift`; `FAR3ArchiveTests` (ID packing, raw and compressed entries, non-RefPack fallback, duplicate names, entries sharing a file ID, wrong type ID) |
| FMT-5 | IFF container: header, chunk records, lookups | done | `IFF/IFFFile.swift`; `IFFFileTests` (10 tests incl. trailing byte, short final chunk, bad sizes, 2.0 header) |
| FMT-6 | Reference snapshot constant | done | `ReferenceSnapshot.swift`; `ReferenceSnapshotTests` |
| FMT-7 | DBPF archives | done | `Archives/DBPFArchive.swift`; `DBPFArchiveTests` (versions 1.0 and 2.0, lookup ID packing, first-wins IDs, missing types, truncation, out-of-bounds entries) |
| FMT-8 | Behavior chunks: `BHAV`, `BCON`, `TRCN`, `TPRP` | done | `IFF/Chunks/BHAV.swift`, `BCON.swift`, `TRCN.swift`, `TPRP.swift`; `BHAVTests` (all four header versions, unknown versions left empty as in FreeSO, truncation), `ConstantChunkTests` (TRCN versions 0 and 2, Latin-1 and .NET strings, negative counts; TPRP both name layouts). Real install: 15,732 BHAVs, 1,476 BCONs, 1,856 TRCNs, 15,577 TPRPs; every branch target is an instruction or an exit code (`RealInstallTests`) |
| FMT-9 | String chunks: `STR#`, `CTSS`, `TTAs` with language sets | done | `IFF/Chunks/StringTable.swift`; `StringTableTests` (formats 0, -1, -2, -3, -4, language fallback, default language, empty and unknown formats) and `ByteReaderStringTests`. Text decoding matches each FreeSO reader: Latin-1 C strings, ASCII Pascal strings, UTF-8, and .NET length-prefixed strings. Real install: 3,401 STR#, 905 CTSS, 910 TTAs |
| FMT-10 | Object chunks: `OBJD`, `OBJf`, `GLOB`, `SLOT`, `TTAB`, `FWAV` | done | Done: `OBJD` (word layout per version, 90 named fields generated from the C# field list, type attribute fallback), `OBJf`, `GLOB`, `SLOT` (per-version defaults and scaling), `TTAB` (plain and field-encoded, via `IFF/FieldEncodedReader.swift`), `FWAV`; `ObjectChunkTests`, `FieldEncodedReaderTests`. Real install: 2,706 OBJD, 1,755 OBJf, 206 GLOB, 790 SLOT, 898 TTAB, 5,408 FWAV; every loaded interaction fits its pie menu strings where the IFF has them. |
| FMT-11 | TS1 house and neighborhood chunks: `OBJT`, `OBJM`, `ARRY`, `WALm`, `FLRm`, `CARR`, `FAMI`, `FAMs`, `NBRS`, `NGBH`, `SIMI`, `TATT` | missing | Charvatia milestone, deferred by the owner. Only TS1 hybrid mode reads them; a TSO install contains none (checked 2026-10-15) |
| FMT-12 | Sprite chunks decoded to RGBA plus depth: `SPR#`, `SPR2`, `PALT`, `DGRP` | missing | Hyde Park |
| FMT-13 | Images: `BMP_`, `THMB`, BMP, TGA, PNG with magenta masking | missing | Hyde Park |
| FMT-14 | PIFF: apply patches to an IFF, `User/` precedence | done | PIFF is FreeSO's own format (fixes for objects its engine mishandled), written against the 2003 production files. `IFF/Chunks/PIFF.swift` (the chunk and `Entry.apply(to:)`, including FreeSO's rule that a final removal may run past the end when nothing remains), `IFFFile.applying(_:)` (deletions, deferred ID swaps, added chunks grouped by type, with FreeSO's "first chunk per type and ID" index), `Patching/PatchRegistry.swift` (discovery, `User/` precedence, patches applied only where they fit). `PIFFTests`, `PatchRegistryTests`. Real install: FreeSO's 36 shipped patches from the snapshot (35 load; one is empty). Of the 27 that target objects in `objiff.far`, 17 apply to the beta and 10 don't fit and are skipped (a C#-faithful simulation confirms FreeSO would fail on 7 of them too), and no patch leaves a chunk unparsable. The snapshot's `skillobjects_10xmultiplier.piff` is empty. Encoding PIFFs is not ported (roadmap decision 4) |
| FMT-15 | OTF tuning tables and `tuning.dat` | done | `Tables/OTFFile.swift` (`T` elements anywhere, comments skipped, .NET-style integer parsing), `Tables/TuningFile.swift` (Persist header, RefPack, strings offset by 13, lower-case names). `OTFFileTests`, `TuningFileTests`. Real install: `tuning.dat` and all 12 OTFs read |
| FMT-16 | `datadefinition.dat` and INI files | done | `Tables/DataDefinition.swift` (three lists and the string table; the file is named `TSOData_datadefinition.dat`), `Tables/INIFile.swift`. `DataDefinitionTests`, `INIFileTests`. Real install: the data definition reads, every derived struct masks a known struct, and the two INI files the client loads read. `sys/nametohostmap.ini` repeats the section `kevins-town`, which FreeSO's reader also rejects; no FreeSO code loads that file |
| FMT-17 | UTK and XA decoding to PCM | missing | Landry Lakes |
| FMT-18 | HIT family: `HITFile`, HOT, EVT, HSM, FSC, TLO, hitlists | missing | Landry Lakes |
| FMT-19 | Vitaboy model formats: mesh, skeleton, animation, appearance, binding, outfit, hand group | missing | Nichol's Notch |
| FMT-20 | TS1 avatar formats: BCF, CFP, BMF | missing | Nichol's Notch |
| FMT-21 | Cursors (`.cur`, `.ani`) | missing | Low priority; a client concern |

## Content

Package: [TSOContent](../NSOClient/TSOContent/). Ports `TSOClient/tso.content` (see
[fso/content.md](fso/content.md)).

| Id | Target | Status | Note |
|---|---|---|---|
| CNT-1 | Game locator: configured path, `TSO_GAME_DIR`, per-OS defaults | done | `GameLocator`: configured folder, then `TSO_GAME_DIR` (either one an error if not an install), then OS defaults (Linux: `$XDG_DATA_HOME` or `~/.local/share`, then FreeSO's `game/TSOClient`). No Windows registry lookup (DIFF-16) |
| CNT-2 | Case-insensitive file index over the install | done | `GameFileIndex`: every lookup in any letter case and with either separator; case collisions reported (none in the beta). Indexes the 1,743-file beta in about 0.03 s |
| CNT-3 | FAR3 providers keyed by `AssetID`, with a bounded cache | missing | Ocean's Edge |
| CNT-4 | Object provider: `objecttable.xml`, `objiff.far`, sprites, tuning, standalone objects | partial | `ObjectProvider`: object table, `objiff.far`, `objotf*.far` and OTF patches, sprite IFFs from `objspf*.far` on request, standalone IFFs, PIFF patches with objects registered again from patched files, routines by name. Missing: sprite decoding (Hyde Park) and the buy and build catalog |
| CNT-5 | Semi-global and global IFFs | done | `GlobalProvider`: `objectdata/globals/<name>.iff` by lower-case name, patched, with tuning from patches or beside the IFF; named by an object's first `GLOB` |
| CNT-6 | Avatar providers: meshes, skeletons, animations, outfits, appearances, bindings, hand groups, thumbnails | missing | Ocean's Edge |
| CNT-7 | Walls, floors, roofs, city maps, UI graphics, audio resource groups | missing | Ocean's Edge |
| CNT-8 | Async initialization with progress, no singleton | partial | No singleton: `GameContent` is an ordinary value made per install. Initialization is synchronous (about 0.2 s on the beta; objects load on first use) with no progress reporting |
| CNT-9 | TS1 hybrid providers | missing | Ocean's Edge, after TSO mode works |

## SimAntics

Package: [SimAntics](../NSOClient/SimAntics/). Ports `TSOClient/tso.simantics` (see
[fso/simantics.md](fso/simantics.md)).

| Id | Target | Status | Note |
|---|---|---|---|
| VM-1 | Tick rate constant (30 per second) | done | `TickRate.swift`; `TickRateTests` |
| VM-2 | BHAV translator: decode operands once per routine | done | `Routine` decodes every operand through `PrimitiveTable` once; `VM` caches routines per file and BHAV |
| VM-3 | Thread, stack frames, exit codes, subroutine calls by opcode range | partial | `VMThread` and `StackFrame`: instructions, subroutine calls with FreeSO's argument rules, every exit code, branches 253 to 255, error unwinding, the instruction guard per entity tick, `main` pushed when the stack empties, check threads (`evaluateCheck`) sharing or copying temps as FreeSO does, and errors that reset the caller and callee with FreeSO's 20-second report cooldown. Missing: interaction queue, routing frames, deleting an object that keeps failing |
| VM-4 | Variable scopes (`VMMemory`) including tuning lookup (BCON then OTF) | partial | `Variable` and `StackFrame.value(of:)` and its siblings: every scope reads and writes as in FreeSO, or fails as FreeSO does, including the clock, object definition fields (`DefinitionVariable`, with FreeSO's quirks), entry points, lead-tile attributes through each multi-tile group's lead, room data (scope 23) from the lot's rooms, and container slots (scopes 16 and 20). Missing: Sims (which fail as FreeSO does on objects) |
| VM-5 | Scheduler and `InternalTick` order | partial | `VMScheduler` and `VM.tick()`: tick IDs from 1, the clock and its globals, entities run in object ID order with FreeSO's sorted insert, runs scheduled into the current tick, the seed advancing by the entity count. Missing: pending deletions, the architecture tick, the global link |
| VM-6 | Entities: objects, avatars, multitile groups, motives | partial | `Entity` for objects: object data with FreeSO's special cases (direction snapping to the rotation step), attributes, the list, lockout count, dynamic sprite flags, the chair-facing flag, entry point tables (`OBJD` or `OBJf`), `initialize()`, `reset()`, entry points run immediately or pushed, lot category disabling, a position and facing. Multi-tile groups (`MultitileGroup`): parts with offsets from their sub-index and level offset, the lead object, the master definition. Creation as `CreateObjectInstance` does it (`VM.createObject`): every part of a multi-tile master, the lowest free object ID, init in turn, main's parameter and stack object, out of the world. Deletion (`VM.delete`), queued until the tick ends while entities run, with the object ID freed. Placement (VM-7). Containment: each object's container slots (`SLOT` slots of type 0), `placeInSlot` with FreeSO's loop and occupancy checks, `ContainerID`, `ParentID`, `SlotNumber`, and `SlotCount` (object data 2, 26, 3, 64), contents moving with their container, and contents moved out (and placed nearby) when the container is deleted. Missing: Sims, catalog prices |
| VM-7 | Lot model: architecture, rooms, placement queries | partial | Phase A: `LotPosition` and `Direction`, entity positions, and the tile index keyed as FreeSO keys it (`VM.objects(at:)`, `VM.move(_:to:)`); digests and the oracle harness use real positions. Phase B: `Architecture` (walls and floors on 5 levels), FreeSO's room flood fill (`RoomMap`, `Room`), `room(at:)` with diagonal halves, entities' rooms (object data 29) kept current on moves and regenerated on the tick after a change, and walls and floors from blueprint XML (`Blueprint`), all matching FreeSO (FID-12). Phase C1: multi-tile groups, object creation, and deletion (VM-6). Phase C2: placement as `ChangePosition` does it (`VM.place`, `Entity.placement(at:facing:flags:)`): footprints from the footprint mask, the bounds, wall, floor, and overlap checks (with "allow intersection" entry points and stacking heights), multi-tile offsets turned with the facing, rollback when a part doesn't fit, each room's entity list, wall use and door and window wall styles, dynamic multi-tile joining, and the placement entry point. Missing: routing obstacles, portals, lighting and room score (Refresh must recompute them), support for upper floors, the buildable area from a lot's size (blueprint lots have none, as in FreeSO), sloped terrain. Phase C3: slots and containment (VM-6), stacking onto a slot when placing, and Find Location For. Phase D1: lots load with their objects as the lot server loads them (`VM.load`, `Blueprint.objects`; FID-13) |
| VM-8 | Interactions: TTAB checks, action queue, priorities | missing | Queen Margaret's |
| VM-9 | Primitives: about 70, `VMExpression` first | partial | 9 of 49 that TSO uses: Expression (opcode 2), Sleep (0), Refresh (7), Random Number (8), Find Location For (16), Play Sound (23), Set To Next (31, including parts of a multi-tile object), Test Object Type (32), and Create Object Instance (42, in the world and in slots), checked against FreeSO (FID-9). The others are known by name and fail as unsupported. The biggest blockers now are Run Tree By Name (8 objects), Transfer Funds (6), and Get Distance To, Idle For Input, and Breakpoint (5 each) |
| VM-10 | Routing: routing frame, rectangle router | missing | Shannopolis |
| VM-11 | Saves: VMMarshal version 19 read and write, hollow saves | missing | Terra Tablante |
| VM-12 | Lockstep: commands, tick lists, client and server drivers, resync | missing | The Billabong |
| VM-13 | Global link interface and offline stub | missing | The Billabong |
| VM-14 | EOD handlers | missing | Upper Shankelston |
| VM-15 | Activators and lot utilities | missing | Virginia Islands |

## Fidelity

How we know the Swift code behaves like FreeSO's code.

| Id | Target | Status | Note |
|---|---|---|---|
| FID-1 | Install scan: every FAR1, FAR3, DBPF, and IFF in a TSO install opens without error | done | `tsofiles-check` on the owner's install (2026-10-15, 1.5 GB): 12 FAR1, 47 FAR3, 6 DBPF, 29 IFF; 82,131 entries read and decompressed, including 1,554 IFFs inside FAR1 archives; 0 failures, in under 7 seconds (release build). The first run found the FAR3 file ID issue fixed as DIFF-5. Forcing FAR1 variant `a` fails on `objspf*.far`, confirming the variant handling |
| FID-1b | Two installs compared: files, archive entries, IFF chunks, and object GUIDs that differ | done | `InstallComparison` (TSOFiles) and `tsofiles-check`, which writes `docs/results/install-differences.md` once when `TSO_GAME_DIR` and `TSO_BETA_DIR` are both set; `InstallComparisonTests` and `DifferencesTests` on synthetic installs; run on the owner's 2002 production copy and 2002 beta (2026-10-16): 1,541 files identical, 125 different, 20 only in production, 77 only in the beta |
| FID-2 | Each ported reader keeps FreeSO's behavior on valid input, with quirks tested | partial | Done for FMT-1 to FMT-5 (quirks listed under [known differences](#known-differences-from-freeso) and in each type's doc comment); applies to every later format |
| FID-6 | Typed chunks parse across a real install, and their values hang together | done | `tsofiles-check` parses every supported chunk in every IFF (51,620 chunks, 0 failures). `RealInstallTests` checks that BHAV branch targets stay inside their routine and that loaded interactions fit their pie menu strings. Five old `TTAB`s (version 2 and 3) that no `OBJD` references fail to parse, as they would in FreeSO; the scanner lists them as unreferenced. **Unverified:** where the game finds pie menu strings for objects whose IFF has no `TTAs` (mostly expansion objects). Not in their sprite IFFs; the owner points to the game's CST files (`gamedata/uitext.dir` holds 112, `gamedata/objectdata.dir` one, which is empty). To confirm in Ocean's Edge |
| FID-3 | Byte-level comparison of decoded output against FreeSO's readers on real files | missing | Needs FreeSO's build or recorded dumps (roadmap decision 2) |
| FID-4 | Replay harness: FreeSO recordings of commands and per-tick state hashes | partial | `NSOClient/FSO.Oracle/` (`fso-oracle run-lot`) compiles FreeSO's SimAntics, Files, Content, LotView, HIT, and Vitaboy sources unchanged on .NET 10, loads a lot headless against the install, and prints a version 0 state digest. Lots load through `LotLoader`, a copy of FreeSO's blueprint restore that seeds the new context (FreeSO seeds it from an unseeded `System.Random`, so a lot with objects gave different digests each run); since 2026-10-16 two runs of 1,800 ticks on the house give identical digests, and `--dump` prints every entity's digested fields. Older installs go through a temporary overlay with reported placeholders. Missing: lot recordings and replays (West Darrington phase 3, after Terra Tablante) |
| FID-5 | Swift VM matches recorded state hashes for a basic lot over an in-game day | missing | Queen Margaret's to Shannopolis |
| FID-7 | Single FreeSO primitives can be run on request with given state, for differential tests | done | `fso-oracle run-primitive` (protocol version 1, see `NSOClient/FSO.Oracle/README.md`): one JSON request per line, each on a fresh lot; reports the exit code, registers, changed globals and object values, created and removed objects, exceptions, and request errors. `check_protocol.py` checks 14 example requests. Avatars not covered yet |
| FID-8 | Content loads every object the way FreeSO does on a real install | done | NSOOracle's `FixtureComparisonTests.contentAndEntryPointsMatchFreeSO` against `fso-oracle list-objects` (2026-10-16, 2002 beta with FreeSO's shipped patches and objects): all 2,649 objects FreeSO loads have the same label, resource, semi-global, routine names, BHAV count, and tuning table count. FreeSO fails on 45 more: 44 because production patches don't fit the beta (loaded here with those patches skipped, DIFF-11) and 1 whose IFF is missing (DIFF-14) |
| FID-9 | Each primitive matches FreeSO case for case | partial | NSOOracle's `FixtureComparisonTests.primitivesMatchFreeSO`, `nso-oracle run-primitive` against `fso-oracle run-primitive` (2026-10-16): each case on a lot `nso-oracle` loads itself, comparing the lot as loaded (every object's category listing, position, object data, attributes, footprint, slots, and groups) as well as the result and effects; the same on the mock lot in CI. Earlier the SimAntics tests rebuilt FreeSO's lot from its responses, which hid that a created object is listed under its category (0) at once, as `VM.AddEntity` lists it; fixed in phase D2. Expression matches on all 3,809 generated cases (every operator, every scope byte read and written with and without a stack object, every object definition field, the clock, room data for every room and out-of-range temp 0, direction snapping, 32-bit TempXL values, flags past bit 31, real tuning from two objects, lists, unknown operators). Sleep matches on all 135 cases (counts, waking at -1 with its random draw, interrupts, idle starts before and after the current tick, unsigned scheduling of negative counts, tick wraparound, bad parameter indexes). Test Object Type matches on all 48 cases (IDs from literals, temps, the stack object, and object data; missing objects; bad scopes). Refresh matches on all 40 cases (every target and refresh type, with and without a stack object). Set To Next matches on all 225 cases (every search type, including objects on a tile and next to one, parts of the lot's multi-tile object, start IDs across the lot, objects by GUID and category, the target-flag quirk). Random Number matches on all 71 cases (ranges read as unsigned, several seeds, every kind of destination, 16-bit scopes). Play Sound matches on all 160 cases (headless, it changes nothing, as on FreeSO's server). Create Object Instance matches on all 1,245 of 1,255 cases the port can run (every position mode, the main-parameter flags, missing objects and GUIDs, objects deleted when they can't be placed, the neighbor cast failure, and 780 placements beside, in front of, and under the lot's objects in every direction with every lot object and multi-tile master, 672 of them placed, and placing into the stack object's and the caller's slots); the other 10 need interactions. Find Location For matches on all 1,538 cases (every mode and flag, objects in and out of the world, references by caller and by local, the empty buildable area of a blueprint lot). Run Tree By Name matches on all 3,648 cases (every destination, string, and table scope from every lot object, missing tables and names, and FreeSO's exceptions for out-of-range strings), and on the mock lamp, which names one of its routines. Notify Stack Object Out Of Idle matches on all of its cases (every lot object as the stack object, from another object and from itself, at several ticks, interrupted or not). Other primitives: not started |
| FID-10 | Objects run alone match FreeSO digest for digest | partial | NSOOracle's `FixtureComparisonTests.objectsRunAloneMatchFreeSO` against `fso-oracle run-objects` (2026-10-16): each object created out of the world on an empty lot, digests after creation and every 10 ticks to 30. Since 2026-10-16 against the 2002 production copy. All 2,753 objects NSOClient can run match (2,569 on the beta), through creation (multi-tile objects included), init, main, sleeping, the scheduler, slots, and deletion of objects that keep failing. Skipped: 89 that FreeSO can't create, and objects that reach an unported primitive (most often Run Tree By Name) |
| FID-13 | Lots run match FreeSO digest for digest | partial | NSOOracle's `FixtureComparisonTests.lotRunsMatchFreeSO` against `fso-oracle run-lot` (2026-10-16): each lot loaded with its objects (`VM.load`), then 1,800 ticks with a digest every 300, the objects `fso-oracle` leaves out left out too. The mock lot (`NSOClient/MockInstall/Lots/mock-lot.xml`) matches every digest, entity for entity. On both real installs, FreeSO's empty lot matches every digest over all 1,800 ticks, the first real lot to; the house (318 entities) reaches Get Direction To while loading, so it's skipped |
| FID-11 | Entry point tables match FreeSO for every object | done | NSOOracle's `FixtureComparisonTests.contentAndEntryPointsMatchFreeSO` against `objects.tsv` column 8 (2026-10-16): 2,649 of 2,649 match, from `OBJD` tree IDs or `OBJf`, with FreeSO's GUID special case |
| FID-12 | Room maps match FreeSO | done | NSOOracle's `FixtureComparisonTests.roomMapsMatchFreeSO` against `fso-oracle room-maps` (2026-10-16): all 62 lots match entry for entry on every level (the room map, and each room's ID, light base, level, outside flag, area, pool flag, adjacent rooms in order, bounds, and support rooms): FreeSO's `empty_lot_fso.xml`, the owner's house (`NSOClient/Lots/tonys-house.xml`: 564 walls, 23 rooms), and 60 synthetic lots from `OracleCases/make_blueprints.py` with walls, fences, diagonals, pools, upper floors, walls on the edges, and out-of-range values. FreeSO's `empty_lot.xml` isn't compared: it has a DTD, which .NET 10 refuses to read. Routing obstacles and lighting aren't ported |

## Determinism

Rules the VM must follow for lockstep. None can be checked until VM code exists; each needs a test
or a lint when it does.

| Id | Target | Status | Note |
|---|---|---|---|
| DET-1 | All 16-bit VM arithmetic wraps (`&+`, `&-`, `&*`), division matches FreeSO | partial | Every ported operation wraps or reports .NET's overflow as an error; Expression's arithmetic matches FreeSO on 3,691 cases. Applies to each primitive as it's ported |
| DET-2 | No `Dictionary` or `Set` iteration in VM logic | partial | The ported VM looks dictionaries up by key and never iterates them; entities and schedules are arrays in object ID order. Checked by hand; no lint yet (TST-5) |
| DET-3 | One seeded random generator, owned by the VM context | done | `VMRandom` on `VM`: FreeSO's xorshift64*, advanced by the entity count each tick; seeds match FreeSO tick for tick (FID-10) |
| DET-4 | No wall-clock time or floating point feeding simulation state without review | missing | Routing and animation timing need a look |
| DET-5 | Same replay result on Linux x86_64, Linux ARM64, and macOS ARM64 | missing | Needs FID-4 and CI on those runners |

## Reliability

| Id | Target | Status | Note |
|---|---|---|---|
| REL-1 | Corrupt or truncated input throws a typed error, never crashes | done | Every reader throws a typed error (`EndOfDataError`, `RefPackError`, `FAR1Error`, `FAR3Error`, `IFFError`); tests cover truncation and bad sizes |
| REL-2 | No `try!`, force unwraps, `fatalError`, or `precondition` in library sources | done | Checked with a grep over `NSOClient/*/Sources` on 2026-10-15; no lint enforces it yet (TST-5) |
| REL-3 | Archives are immutable values, safe to read from several threads | done | `FAR1Archive` and `FAR3Archive` are `Sendable` structs over memory-mapped `Data`; removes FreeSO's `isReadingSomething` race |
| REL-4 | Swift 6 language mode (strict concurrency) in every package | done | `swiftLanguageModes: [.v6]` in all five manifests |
| REL-5 | Size limits on allocations driven by file data | partial | Reads are bounded by the data length; RefPack output growth and declared decompressed sizes have no cap yet |
| REL-6 | Fuzzing of every reader with malformed input | missing | |
| REL-7 | Bounded caches for decoded content | missing | Object and global resources are kept for the life of `GameContent` (FreeSO used weak-reference caches); fine for objects, needed before FAR3 assets (CNT-3) |

## Tests and tooling

| Id | Target | Status | Note |
|---|---|---|---|
| TST-1 | Swift Testing in every package | done | `import Testing` in all test targets |
| TST-2 | Synthetic fixtures only, no EA data in the repository | done | `Support/ByteWriter.swift` in TSOFiles and TSOContent builds archives, RefPack streams, IFFs, and fake installs in code |
| TST-3 | Each package builds and tests on its own | done | `swift build` and `swift test` per package; path dependencies resolve |
| TST-4 | CI runs every package on every push | done | `.github/workflows/swift.yml`: builds and tests each package on Linux x86_64 and ARM64 (`swift:6.3` container) and on macOS, for pushes and pull requests that touch `NSOClient/`. Run 38812498011 (commit `9fe95212`) passed all three jobs |
| TST-5 | Lint for REL-2 and DET-2 (SwiftLint custom rules or a script) | partial | The CI workflow fails on `try!`, `as!`, `fatalError`, or `precondition` in library sources. Not covered: force unwraps (`!`), and DET-2 (no SimAntics code yet) |
| TST-6 | Real-file tests gated on `TSO_GAME_DIR` | done | `RealInstallTests` in TSOFiles and TSOContent run when `TSO_GAME_DIR` is set and are skipped otherwise; comparisons with FreeSO also need `TSO_ORACLE_DIR` (`NSOClient/scripts/oracle-fixtures.sh`). No game data in the repository |
| TST-7 | Script that extracts the TSO installer's cabinets into a game folder | partial | `NSOClient/scripts/extract.sh`: detects Microsoft (cabextract) or InstallShield (unshield) cabinets, accepts a folder, a cabinet, or a .zip, tests integrity first, finds the folder holding `tuning.dat`, optional `--lowercase` and `--check`. Tested on hand-built Microsoft cabinets (extraction, lower-casing, .zip input, damaged and foreign files, usage errors). Not yet tested: spanned cabinet sets, InstallShield (unshield isn't installed here), the real installer |
| TST-8 | NSOClient answers `fso-oracle`'s questions, and a review compares the two per install | done | `nso-oracle` (NSOClient/NSOOracle: `list-objects`, `run-objects`, `run-lot`, `run-primitive`, `room-maps` in `fso-oracle`'s formats, and `compare`), `NSOClient/scripts/oracle-review.sh`, and [nso-review.md](results/nso-review.md). First review (2026-10-16), 0 mismatches on both installs: production 2,833 objects' content and entry points, 2,743 objects run alone, 62 room maps; the 2002 beta 2,650, 2,649, 2,559, and 62. `run-primitive` since phase D2. CI runs both oracles on `NSOClient/MockInstall` and fails on any mismatch (`oracle.yml`, `compare --strict`) |

## Platforms

No `platforms:` are declared (owner decision); this tracks where the packages are known to build.

| Id | Target | Status | Note |
|---|---|---|---|
| PLAT-1 | Linux x86_64 | done | Swift 6.3.3, all tests pass |
| PLAT-2 | Linux ARM64 | done | CI job `Linux (aarch64)`, `swift:6.3` container |
| PLAT-3 | macOS | done | CI job `macOS` on `macos-latest`. With no `platforms:` declared, builds target macOS 10.13, so APIs newer than that can't be used (the first run failed on `FileHandle.read(upToCount:)`) |
| PLAT-4 | Windows | missing | Untested; Foundation on Windows is the least tested |

## Scripting

Package: [SimsScript](../NSOClient/SimsScript/). A later milestone (Yatesport, roadmap
decision 5); only a proof of concept so far.

| Id | Target | Status | Note |
|---|---|---|---|
| SCR-1 | Routines and operands encode back to their bytes | done | `BHAV.encoded()` reads back equal for every BHAV in the install (TSOFiles `RealInstallTests`); Expression and call operands re-encode to their exact bytes (SimAntics `RealOperandEncodingTests`). Other primitives' operands get encoders as they're ported |
| SCR-2 | Text assembly that round-trips every routine | done | `Assembly`: Expression and calls in readable form, other primitives as hex; all 15,723 routines in the beta convert to text and back unchanged |
| SCR-3 | A compiler from an LSL-like language to routines | partial | `ScriptCompiler`: object variables, events as entry points, functions with up to 4 parameters, locals, arithmetic, comparisons, `&& \|\| !`, `if`, `while`, calls as conditions; output runs on the Swift VM (`CompilerTests`). Missing: primitives as built-ins, strings, `state`s, interactions (`TTAB`), checking compiled objects against FreeSO's VM |
| SCR-4 | Assembly instructions for every primitive's operand | done | Unmodeled primitives keep their 8 bytes in hex, so nothing is lost; readable forms come with each ported primitive |
| SCR-5 | Decompiler from routines to the LSL-like language | missing | Yatesport |
| SCR-6 | Interactions, `state`s, and built-ins for every primitive | missing | Yatesport |
| SCR-7 | Editor support: language server, VS Code extension | missing | Yatesport |

## Known differences from FreeSO

Deliberate, documented in the code. Each keeps valid-file behavior the same.

| Id | Difference | Where | Why |
|---|---|---|---|
| DIFF-1 | Corrupt data throws instead of crashing or returning partial results | all readers | Never crash on hostile input |
| DIFF-2 | Archives are values over memory-mapped bytes, not shared readers | `FAR1Archive`, `FAR3Archive` | Removes the `isReadingSomething` race that silently returned empty archives |
| DIFF-3 | IFF keeps chunk types the old reader skipped | `IFFFile` | Nothing is lost before typed parsing |
| DIFF-4 | Seeking past the end of the data throws; .NET allowed it and then read nothing | `ByteReader.seek(to:)` | Surfaces bad offsets at their source |
| DIFF-5 | FAR3 lookups by asset ID use file ID and type ID together; repeated file IDs no longer fail | `FAR3Archive.entry(id:)` | `packingslips/packingslips.dat` repeats 5,240 file IDs across type IDs (all 32,711 pairs unique). FreeSO's reader indexed by file ID alone, with the comment "isn't this a bad idea?", and would throw; FreeSO never opens that file. Results are identical for every archive FreeSO loads |
| DIFF-6 | `TTAB` rejects a motive count larger than the bits left in the chunk | `TTAB` | Field-encoded reads past the end return zeros, so a corrupt count would loop billions of times; plain counts that large fail in FreeSO too |
| DIFF-7 | A string table with an unknown format code fails to parse | `StringTable` | FreeSO accepts it with null language sets and crashes on the first lookup |
| DIFF-8 | A format -4 string lookup for a language past the stored sets falls back to English | `StringTable.strings(for:defaultLanguage:)` | FreeSO indexes past its array and crashes |
| DIFF-9 | PIFF entries and added chunks of any type apply | `IFFFile.applying(_:)` | FreeSO throws on a patch entry whose type it has no class for, and skips such added chunks |
| DIFF-10 | Patch files load in sorted order, `User/` is matched in the path relative to the patch folder, and files that fail to load are reported | `PatchRegistry` | FreeSO's file order is undefined, it matches `User/` anywhere in the full path, and it skips bad files silently |
| DIFF-11 | The patch registry applies each PIFF as a whole only if it fits, and skips and reports the rest | `PatchRegistry.applyingPatches(to:fileName:)` | FreeSO's patches target the 2003 production files. On other versions (such as the 2002 beta) FreeSO fails to load the object; this keeps the object unpatched instead. On production files every patch fits and results are identical |
| DIFF-12 | An object table entry without a display name (`o`) loads with no name | `ObjectTable` | The 2002 beta's table has no `o`; FreeSO fails on the missing attribute |
| DIFF-13 | A GUID registered twice keeps its first registration and reports the rest | `ObjectProvider.duplicates` | FreeSO throws on the second, stopping content loading (none in the beta) |
| DIFF-14 | An object whose IFF isn't in `objiff.far` throws `ContentError.missingFile` for that object only | `ObjectProvider.object(guid:)` | FreeSO fails with a null reference; the beta lists `skillcheater` without shipping it |
| DIFF-15 | Tuning that exists but fails to load is reported in `tuningFailure`; the object loads without it, as in FreeSO | `ObjectResource` | FreeSO ignores the failure silently (none in the beta) |
| DIFF-16 | Paths resolve in any letter case; the locator skips the Windows registry and looks under the XDG data folder on Linux | `GameFileIndex`, `GameLocator` | FreeSO joins paths as written, which fails on case-sensitive file systems; the registry needs Windows-only APIs |
| DIFF-17 | Playing a sound doesn't make an object run every tick | `Primitives.PlaySound` | FreeSO clients do this and its server doesn't; the VM is headless, so it follows the server, which lockstep play agrees on. Playing sound belongs to a presentation layer |
| DIFF-18 | A new `Architecture` has its rooms generated, so a VM has rooms before any lot loads; lots are 1 to 255 tiles a side, and tiles off the lot throw instead of wrapping | `Architecture`, `Blueprint` | FreeSO has no rooms until a lot loads (reading room data then fails), and its 16-bit tile offsets wrap past 255 tiles. No lot FreeSO loads is affected |
| DIFF-19 | Multi-tile offsets turn by exact quarter turns | `VM.place(_:at:facing:flags:)` | FreeSO rotates them with a float matrix and rounds; for offsets in whole tiles the results are the same |
| DIFF-20 | A door or window puts its definition's wall style on the wall as is | `Entity.setWallStyle` | FreeSO first swaps a style from 22 to 255 for a generated one, which only drawing reads |
| DIFF-21 | An error while deleting an object at the end of a tick is reported against the object, and the object stays deleted | `VMScheduler`, `VMThread` | FreeSO lets it escape the tick, which stops the lot. Owner's decision (2026-10-16): deleting must fail safe. Once Sims and interactions are ported, a Sim using the deleted object resets and drops it from its queue, as in The Sims 4 |
| DIFF-22 | Loading a lot leaves out an object the content doesn't have or can't load, and returns it | `VM.load(_:)` | FreeSO's activator fails on it; `fso-oracle` leaves such objects out beforehand, and `nso-oracle run-lot --leave-out` matches its choice |
| DIFF-23 | Loading a lot keeps entities already on the VM | `VM.load(_:)` | FreeSO replaces the context and starts with none; tests add entities and then load architecture under them |
| DIFF-24 | A routine Run Tree By Name runs to completion stops after 500,000 instructions with an infinite-loop error | `VMThread.runInMyStack` | FreeSO's `RunInMyStack` has no limit, so a tree that loops or waits hangs the whole lot |

## Open bugs

None filed yet. Bugs found in FreeSO's code that the port fixes go under known differences, not
here.
