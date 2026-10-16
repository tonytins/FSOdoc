# NSOClient scorecard

Maintained by hand from the source tree and `swift test` in each package under
[`NSOClient/`](../NSOClient/). Statuses are checked against the code at the date below; when this
page and [roadmap.md](roadmap.md) disagree, this page wins and the roadmap gets re-estimated. Every
`done` row names the code or test that proves it.

**As of:** 2026-10-16 · Swift 6.3.3 on Linux x86_64 · `swift test`: TSOFiles 128 passed (8 need
`TSO_GAME_DIR`), TSOFilesCheck 6 passed, TSOContent 37 passed (5 need `TSO_GAME_DIR`, and one of those also `TSO_ORACLE_DIR`),
SimAntics 62 passed (4 need `TSO_GAME_DIR`, and 3 of those also `TSO_ORACLE_DIR`), SimsScript 12
passed (1 needs `TSO_GAME_DIR`). Tests that need either variable are skipped without it. The
owner's install is a 2002 beta; FreeSO targets the 2003 production files, so beta-only differences are
expected and handled for backwards compatibility.

Status values: `done` (works and is tested), `partial` (works with gaps, named in the note),
`missing` (not started).

## Summary

| Area | Done | Partial | Missing | Key numbers |
|---|---:|---:|---:|---|
| [Formats](#formats) | 13 | 0 | 8 | 128 test cases; real install (2002 beta): 94 containers, 82,131 entries, 51,620 typed chunks, tuning, data definition, and OTFs, 0 failures |
| [Content](#content) | 3 | 2 | 4 | real install: 2,694 objects registered, 2,693 load (the beta lacks one IFF), 19 semi-globals; matches 2017 on all 2,649 objects 2017 loads, and loads 44 more it can't |
| [SimAntics](#simantics) | 2 | 5 | 8 | 7 primitives match 2017 on every oracle case they can run; 1,914 objects run alone match 2017 digest for digest over 30 ticks |
| [Fidelity](#fidelity) | 5 | 4 | 2 | install scan and real-data invariants clean; content and entry points match 2017 object for object; Expression matches on 3,691 cases; single-object runs match digest for digest |
| [Determinism](#determinism) | 1 | 2 | 2 | the random seed matches 2017 tick for tick |
| [Reliability](#reliability) | 4 | 1 | 2 | 0 force unwraps, 0 `try!`, 0 `fatalError` in sources |
| [Tests and tooling](#tests-and-tooling) | 5 | 2 | 0 | |
| [Platforms](#platforms) | 3 | 0 | 1 | |
| [Scripting](#scripting) | 3 | 1 | 3 | proof of concept: all 15,723 routines round-trip through assembly; compiled scripts run on the VM |
| [Known differences from 2017](#known-differences-from-2017) | | | | 17 deliberate |
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
| FMT-8 | Behavior chunks: `BHAV`, `BCON`, `TRCN`, `TPRP` | done | `IFF/Chunks/BHAV.swift`, `BCON.swift`, `TRCN.swift`, `TPRP.swift`; `BHAVTests` (all four header versions, unknown versions left empty as in 2017, truncation), `ConstantChunkTests` (TRCN versions 0 and 2, Latin-1 and .NET strings, negative counts; TPRP both name layouts). Real install: 15,732 BHAVs, 1,476 BCONs, 1,856 TRCNs, 15,577 TPRPs; every branch target is an instruction or an exit code (`RealInstallTests`) |
| FMT-9 | String chunks: `STR#`, `CTSS`, `TTAs` with language sets | done | `IFF/Chunks/StringTable.swift`; `StringTableTests` (formats 0, -1, -2, -3, -4, language fallback, default language, empty and unknown formats) and `ByteReaderStringTests`. Text decoding matches each 2017 reader: Latin-1 C strings, ASCII Pascal strings, UTF-8, and .NET length-prefixed strings. Real install: 3,401 STR#, 905 CTSS, 910 TTAs |
| FMT-10 | Object chunks: `OBJD`, `OBJf`, `GLOB`, `SLOT`, `TTAB`, `FWAV` | done | Done: `OBJD` (word layout per version, 90 named fields generated from the C# field list, type attribute fallback), `OBJf`, `GLOB`, `SLOT` (per-version defaults and scaling), `TTAB` (plain and field-encoded, via `IFF/FieldEncodedReader.swift`), `FWAV`; `ObjectChunkTests`, `FieldEncodedReaderTests`. Real install: 2,706 OBJD, 1,755 OBJf, 206 GLOB, 790 SLOT, 898 TTAB, 5,408 FWAV; every loaded interaction fits its pie menu strings where the IFF has them. |
| FMT-11 | TS1 house and neighborhood chunks: `OBJT`, `OBJM`, `ARRY`, `WALm`, `FLRm`, `CARR`, `FAMI`, `FAMs`, `NBRS`, `NGBH`, `SIMI`, `TATT` | missing | Charvatia milestone, deferred by the owner. Only TS1 hybrid mode reads them; a TSO install contains none (checked 2026-10-15) |
| FMT-12 | Sprite chunks decoded to RGBA plus depth: `SPR#`, `SPR2`, `PALT`, `DGRP` | missing | Hyde Park |
| FMT-13 | Images: `BMP_`, `THMB`, BMP, TGA, PNG with magenta masking | missing | Hyde Park |
| FMT-14 | PIFF: apply patches to an IFF, `User/` precedence | done | PIFF is FreeSO's own format (fixes for objects its engine mishandled), written against the 2003 production files. `IFF/Chunks/PIFF.swift` (the chunk and `Entry.apply(to:)`, including 2017's rule that a final removal may run past the end when nothing remains), `IFFFile.applying(_:)` (deletions, deferred ID swaps, added chunks grouped by type, with the 2017 "first chunk per type and ID" index), `Patching/PatchRegistry.swift` (discovery, `User/` precedence, patches applied only where they fit). `PIFFTests`, `PatchRegistryTests`. Real install: FreeSO's 36 shipped patches from the snapshot (35 load; one is empty). Of the 27 that target objects in `objiff.far`, 17 apply to the beta and 10 don't fit and are skipped (a C#-faithful simulation confirms 2017 would fail on 7 of them too), and no patch leaves a chunk unparsable. The snapshot's `skillobjects_10xmultiplier.piff` is empty. Encoding PIFFs is not ported (roadmap decision 4) |
| FMT-15 | OTF tuning tables and `tuning.dat` | done | `Tables/OTFFile.swift` (`T` elements anywhere, comments skipped, .NET-style integer parsing), `Tables/TuningFile.swift` (Persist header, RefPack, strings offset by 13, lower-case names). `OTFFileTests`, `TuningFileTests`. Real install: `tuning.dat` and all 12 OTFs read |
| FMT-16 | `datadefinition.dat` and INI files | done | `Tables/DataDefinition.swift` (three lists and the string table; the file is named `TSOData_datadefinition.dat`), `Tables/INIFile.swift`. `DataDefinitionTests`, `INIFileTests`. Real install: the data definition reads, every derived struct masks a known struct, and the two INI files the client loads read. `sys/nametohostmap.ini` repeats the section `kevins-town`, which the 2017 reader also rejects; no 2017 code loads that file |
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
| CNT-1 | Game locator: configured path, `TSO_GAME_DIR`, per-OS defaults | done | `GameLocator`: configured folder, then `TSO_GAME_DIR` (either one an error if not an install), then OS defaults (Linux: `$XDG_DATA_HOME` or `~/.local/share`, then 2017's `game/TSOClient`). No Windows registry lookup (DIFF-16) |
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
| VM-3 | Thread, stack frames, exit codes, subroutine calls by opcode range | partial | `VMThread` and `StackFrame`: instructions, subroutine calls with 2017's argument rules, every exit code, branches 253 to 255, error unwinding, the instruction guard per entity tick, `main` pushed when the stack empties, check threads (`evaluateCheck`) sharing or copying temps as 2017 does, and errors that reset the caller and callee with 2017's 20-second report cooldown. Missing: interaction queue, routing frames, deleting an object that keeps failing |
| VM-4 | Variable scopes (`VMMemory`) including tuning lookup (BCON then OTF) | partial | `Variable` and `StackFrame.value(of:)` and its siblings: every scope reads and writes as in 2017, or fails as 2017 does, including the clock, object definition fields (`DefinitionVariable`, with 2017's quirks), entry points, and lead-tile attributes (each object leads its own group until groups are ported). Missing: slots, room data 1, 3, and 4, and Sims (which fail as 2017 does on objects) |
| VM-5 | Scheduler and `InternalTick` order | partial | `VMScheduler` and `VM.tick()`: tick IDs from 1, the clock and its globals, entities run in object ID order with 2017's sorted insert, runs scheduled into the current tick, the seed advancing by the entity count. Missing: pending deletions, the architecture tick, the global link |
| VM-6 | Entities: objects, avatars, multitile groups, motives | partial | `Entity` for objects: object data with 2017's special cases (direction snapping to the rotation step), attributes, the list, lockout count, dynamic sprite flags, the chair-facing flag, entry point tables (`OBJD` or `OBJf`), `initialize()`, `reset()`, entry points run immediately or pushed, lot category disabling. Missing: Sims, multi-tile groups, containers and slots, positions, creation through `CreateObjectInstance` |
| VM-7 | Lot model: architecture, rooms, placement queries | missing | Queen Margaret's. When rooms land, Refresh must recompute room lighting and score (it does nothing while every entity is out of the world) |
| VM-8 | Interactions: TTAB checks, action queue, priorities | missing | Queen Margaret's |
| VM-9 | Primitives: about 70, `VMExpression` first | partial | 7 of 49 that TSO uses: Expression (opcode 2), Sleep (0), Refresh (7), Random Number (8), Play Sound (23), Set To Next (31), and Test Object Type (32), checked against 2017 (FID-9). The others are known by name and fail as unsupported. The biggest blockers now come with the lot model (FID-10): stack object slots (111), room data (56), adjacent-object searches (17) |
| VM-10 | Routing: routing frame, rectangle router | missing | Shannopolis |
| VM-11 | Saves: VMMarshal version 19 read and write, hollow saves | missing | Terra Tablante |
| VM-12 | Lockstep: commands, tick lists, client and server drivers, resync | missing | The Billabong |
| VM-13 | Global link interface and offline stub | missing | The Billabong |
| VM-14 | EOD handlers | missing | Upper Shankelston |
| VM-15 | Activators and lot utilities | missing | Virginia Islands |

## Fidelity

How we know the Swift code behaves like the 2017 code.

| Id | Target | Status | Note |
|---|---|---|---|
| FID-1 | Install scan: every FAR1, FAR3, DBPF, and IFF in a TSO install opens without error | done | `tsofiles-check` on the owner's install (2026-10-15, 1.5 GB): 12 FAR1, 47 FAR3, 6 DBPF, 29 IFF; 82,131 entries read and decompressed, including 1,554 IFFs inside FAR1 archives; 0 failures, in under 7 seconds (release build). The first run found the FAR3 file ID issue fixed as DIFF-5. Forcing FAR1 variant `a` fails on `objspf*.far`, confirming the variant handling |
| FID-2 | Each ported reader keeps the 2017 behavior on valid input, with quirks tested | partial | Done for FMT-1 to FMT-5 (quirks listed under [known differences](#known-differences-from-2017) and in each type's doc comment); applies to every later format |
| FID-6 | Typed chunks parse across a real install, and their values hang together | done | `tsofiles-check` parses every supported chunk in every IFF (51,620 chunks, 0 failures). `RealInstallTests` checks that BHAV branch targets stay inside their routine and that loaded interactions fit their pie menu strings. Five old `TTAB`s (version 2 and 3) that no `OBJD` references fail to parse, as they would in 2017; the scanner lists them as unreferenced. **Unverified:** where the game finds pie menu strings for objects whose IFF has no `TTAs` (mostly expansion objects). Not in their sprite IFFs; the owner points to the game's CST files (`gamedata/uitext.dir` holds 112, `gamedata/objectdata.dir` one, which is empty). To confirm in Ocean's Edge |
| FID-3 | Byte-level comparison of decoded output against the 2017 readers on real files | missing | Needs the 2017 build or recorded dumps (roadmap decision 2) |
| FID-4 | Replay harness: 2017 recordings of commands and per-tick state hashes | partial | `NSOClient/Oracle/` (`fso-oracle run-lot`) compiles the 2017 SimAntics, Files, Content, LotView, HIT, and Vitaboy sources unchanged on .NET 10, loads a lot headless against the install, and prints a version 0 state digest; three runs of 1,800 ticks give identical digests. Older installs go through a temporary overlay with reported placeholders. Missing: lot recordings and replays (West Darrington phase 3, after Terra Tablante) |
| FID-5 | Swift VM matches recorded state hashes for a basic lot over an in-game day | missing | Queen Margaret's to Shannopolis |
| FID-7 | Single 2017 primitives can be run on request with given state, for differential tests | done | `fso-oracle run-primitive` (protocol version 1, see `NSOClient/Oracle/README.md`): one JSON request per line, each on a fresh lot; reports the exit code, registers, changed globals and object values, created and removed objects, exceptions, and request errors. `check_protocol.py` checks 14 example requests. Avatars not covered yet |
| FID-8 | Content loads every object the way 2017 does on a real install | done | `RealInstallTests.matchesThe2017ContentSystem` against `fso-oracle list-objects` (2026-10-16, 2002 beta with FreeSO's shipped patches and objects): all 2,649 objects 2017 loads have the same label, resource, semi-global, routine names, BHAV count, and tuning table count. 2017 fails on 45 more: 44 because production patches don't fit the beta (loaded here with those patches skipped, DIFF-11) and 1 whose IFF is missing (DIFF-14) |
| FID-9 | Each primitive matches 2017 case for case | partial | `OracleExpressionTests` against `fso-oracle run-primitive` (2026-10-16): Expression matches on all 3,733 of 3,760 generated cases the port can run (every operator, every scope byte read and written with and without a stack object, every object definition field, the clock, direction snapping, 32-bit TempXL values, flags past bit 31, real tuning from two objects, lists, unknown operators). The other 27 need slots or rooms. Sleep matches on all 135 cases (counts, waking at -1 with its random draw, interrupts, idle starts before and after the current tick, unsigned scheduling of negative counts, tick wraparound, bad parameter indexes). Test Object Type matches on all 48 cases (IDs from literals, temps, the stack object, and object data; missing objects; bad scopes). Refresh matches on all 40 cases (every target and refresh type, with and without a stack object). Set To Next matches on all 128 cases it can run (every search type, start IDs across the lot, objects by GUID and category, the target-flag quirk); 5 need positions. Random Number matches on all 71 cases (ranges read as unsigned, several seeds, every kind of destination, 16-bit scopes). Play Sound matches on all 160 cases (headless, it changes nothing, as on 2017's server). Other primitives: not started |
| FID-10 | Objects run alone match 2017 digest for digest | partial | `OracleObjectRunTests` against `fso-oracle run-objects` (2026-10-16): each object created out of the world on an empty lot, digests after creation and every 10 ticks to 30. All 1,914 objects the port can run match, through init, main, sleeping, and the scheduler. Skipped: objects that reach an unported primitive or scope (most often stack object slots and room data), 390 multi-tile, 90 that 2017 can't create, and those that keep failing (on a missing stack object or a Sim-only scope), which 2017 deletes |
| FID-11 | Entry point tables match 2017 for every object | done | `OracleEntryPointTests` against `objects.tsv` column 8 (2026-10-16): 2,649 of 2,649 match, from `OBJD` tree IDs or `OBJf`, with 2017's GUID special case |

## Determinism

Rules the VM must follow for lockstep. None can be checked until VM code exists; each needs a test
or a lint when it does.

| Id | Target | Status | Note |
|---|---|---|---|
| DET-1 | All 16-bit VM arithmetic wraps (`&+`, `&-`, `&*`), division matches FreeSO | partial | Every ported operation wraps or reports .NET's overflow as an error; Expression's arithmetic matches 2017 on 3,691 cases. Applies to each primitive as it's ported |
| DET-2 | No `Dictionary` or `Set` iteration in VM logic | partial | The ported VM looks dictionaries up by key and never iterates them; entities and schedules are arrays in object ID order. Checked by hand; no lint yet (TST-5) |
| DET-3 | One seeded random generator, owned by the VM context | done | `VMRandom` on `VM`: 2017's xorshift64*, advanced by the entity count each tick; seeds match 2017 tick for tick (FID-10) |
| DET-4 | No wall-clock time or floating point feeding simulation state without review | missing | Routing and animation timing need a look |
| DET-5 | Same replay result on Linux x86_64, Linux ARM64, and macOS ARM64 | missing | Needs FID-4 and CI on those runners |

## Reliability

| Id | Target | Status | Note |
|---|---|---|---|
| REL-1 | Corrupt or truncated input throws a typed error, never crashes | done | Every reader throws a typed error (`EndOfDataError`, `RefPackError`, `FAR1Error`, `FAR3Error`, `IFFError`); tests cover truncation and bad sizes |
| REL-2 | No `try!`, force unwraps, `fatalError`, or `precondition` in library sources | done | Checked with a grep over `NSOClient/*/Sources` on 2026-10-15; no lint enforces it yet (TST-5) |
| REL-3 | Archives are immutable values, safe to read from several threads | done | `FAR1Archive` and `FAR3Archive` are `Sendable` structs over memory-mapped `Data`; removes the 2017 `isReadingSomething` race |
| REL-4 | Swift 6 language mode (strict concurrency) in every package | done | `swiftLanguageModes: [.v6]` in all five manifests |
| REL-5 | Size limits on allocations driven by file data | partial | Reads are bounded by the data length; RefPack output growth and declared decompressed sizes have no cap yet |
| REL-6 | Fuzzing of every reader with malformed input | missing | |
| REL-7 | Bounded caches for decoded content | missing | Object and global resources are kept for the life of `GameContent` (2017 used weak-reference caches); fine for objects, needed before FAR3 assets (CNT-3) |

## Tests and tooling

| Id | Target | Status | Note |
|---|---|---|---|
| TST-1 | Swift Testing in every package | done | `import Testing` in all test targets |
| TST-2 | Synthetic fixtures only, no EA data in the repository | done | `Support/ByteWriter.swift` in TSOFiles and TSOContent builds archives, RefPack streams, IFFs, and fake installs in code |
| TST-3 | Each package builds and tests on its own | done | `swift build` and `swift test` per package; path dependencies resolve |
| TST-4 | CI runs every package on every push | done | `.github/workflows/swift.yml`: builds and tests each package on Linux x86_64 and ARM64 (`swift:6.3` container) and on macOS, for pushes and pull requests that touch `NSOClient/`. Run 38812498011 (commit `9fe95212`) passed all three jobs |
| TST-5 | Lint for REL-2 and DET-2 (SwiftLint custom rules or a script) | partial | The CI workflow fails on `try!`, `as!`, `fatalError`, or `precondition` in library sources. Not covered: force unwraps (`!`), and DET-2 (no SimAntics code yet) |
| TST-6 | Real-file tests gated on `TSO_GAME_DIR` | done | `RealInstallTests` in TSOFiles and TSOContent run when `TSO_GAME_DIR` is set and are skipped otherwise; comparisons with 2017 also need `TSO_ORACLE_DIR` (`NSOClient/scripts/oracle-fixtures.sh`). No game data in the repository |
| TST-7 | Script that extracts the TSO installer's cabinets into a game folder | partial | `NSOClient/scripts/extract.sh`: detects Microsoft (cabextract) or InstallShield (unshield) cabinets, accepts a folder, a cabinet, or a .zip, tests integrity first, finds the folder holding `tuning.dat`, optional `--lowercase` and `--check`. Tested on hand-built Microsoft cabinets (extraction, lower-casing, .zip input, damaged and foreign files, usage errors). Not yet tested: spanned cabinet sets, InstallShield (unshield isn't installed here), the real installer |

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
| SCR-3 | A compiler from an LSL-like language to routines | partial | `ScriptCompiler`: object variables, events as entry points, functions with up to 4 parameters, locals, arithmetic, comparisons, `&& \|\| !`, `if`, `while`, calls as conditions; output runs on the Swift VM (`CompilerTests`). Missing: primitives as built-ins, strings, `state`s, interactions (`TTAB`), checking compiled objects against the 2017 VM |
| SCR-4 | Assembly instructions for every primitive's operand | done | Unmodeled primitives keep their 8 bytes in hex, so nothing is lost; readable forms come with each ported primitive |
| SCR-5 | Decompiler from routines to the LSL-like language | missing | Yatesport |
| SCR-6 | Interactions, `state`s, and built-ins for every primitive | missing | Yatesport |
| SCR-7 | Editor support: language server, VS Code extension | missing | Yatesport |

## Known differences from 2017

Deliberate, documented in the code. Each keeps valid-file behavior the same.

| Id | Difference | Where | Why |
|---|---|---|---|
| DIFF-1 | Corrupt data throws instead of crashing or returning partial results | all readers | Never crash on hostile input |
| DIFF-2 | Archives are values over memory-mapped bytes, not shared readers | `FAR1Archive`, `FAR3Archive` | Removes the `isReadingSomething` race that silently returned empty archives |
| DIFF-3 | IFF keeps chunk types the old reader skipped | `IFFFile` | Nothing is lost before typed parsing |
| DIFF-4 | Seeking past the end of the data throws; .NET allowed it and then read nothing | `ByteReader.seek(to:)` | Surfaces bad offsets at their source |
| DIFF-5 | FAR3 lookups by asset ID use file ID and type ID together; repeated file IDs no longer fail | `FAR3Archive.entry(id:)` | `packingslips/packingslips.dat` repeats 5,240 file IDs across type IDs (all 32,711 pairs unique). The 2017 reader indexed by file ID alone, with the comment "isn't this a bad idea?", and would throw; FreeSO never opens that file. Results are identical for every archive FreeSO loads |
| DIFF-6 | `TTAB` rejects a motive count larger than the bits left in the chunk | `TTAB` | Field-encoded reads past the end return zeros, so a corrupt count would loop billions of times; plain counts that large fail in 2017 too |
| DIFF-7 | A string table with an unknown format code fails to parse | `StringTable` | 2017 accepts it with null language sets and crashes on the first lookup |
| DIFF-8 | A format -4 string lookup for a language past the stored sets falls back to English | `StringTable.strings(for:defaultLanguage:)` | 2017 indexes past its array and crashes |
| DIFF-9 | PIFF entries and added chunks of any type apply | `IFFFile.applying(_:)` | 2017 throws on a patch entry whose type it has no class for, and skips such added chunks |
| DIFF-10 | Patch files load in sorted order, `User/` is matched in the path relative to the patch folder, and files that fail to load are reported | `PatchRegistry` | 2017's file order is undefined, it matches `User/` anywhere in the full path, and it skips bad files silently |
| DIFF-11 | The patch registry applies each PIFF as a whole only if it fits, and skips and reports the rest | `PatchRegistry.applyingPatches(to:fileName:)` | FreeSO's patches target the 2003 production files. On other versions (such as the 2002 beta) 2017 fails to load the object; this keeps the object unpatched instead. On production files every patch fits and results are identical |
| DIFF-12 | An object table entry without a display name (`o`) loads with no name | `ObjectTable` | The 2002 beta's table has no `o`; 2017 fails on the missing attribute |
| DIFF-13 | A GUID registered twice keeps its first registration and reports the rest | `ObjectProvider.duplicates` | 2017 throws on the second, stopping content loading (none in the beta) |
| DIFF-14 | An object whose IFF isn't in `objiff.far` throws `ContentError.missingFile` for that object only | `ObjectProvider.object(guid:)` | 2017 fails with a null reference; the beta lists `skillcheater` without shipping it |
| DIFF-15 | Tuning that exists but fails to load is reported in `tuningFailure`; the object loads without it, as in 2017 | `ObjectResource` | 2017 ignores the failure silently (none in the beta) |
| DIFF-16 | Paths resolve in any letter case; the locator skips the Windows registry and looks under the XDG data folder on Linux | `GameFileIndex`, `GameLocator` | 2017 joins paths as written, which fails on case-sensitive file systems; the registry needs Windows-only APIs |
| DIFF-17 | Playing a sound doesn't make an object run every tick | `Primitives.PlaySound` | 2017 clients do this and its server doesn't; the VM is headless, so it follows the server, which lockstep play agrees on. Playing sound belongs to a presentation layer |

## Open bugs

None filed yet. Bugs found in the 2017 code that the port fixes go under known differences, not
here.
