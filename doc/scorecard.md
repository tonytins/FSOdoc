# NSOClient scorecard

Maintained by hand from the source tree and `swift test` in each package under
[`NSOClient/`](../NSOClient/). Statuses are checked against the code at the date below; when this
page and [roadmap.md](roadmap.md) disagree, this page wins and the roadmap gets re-estimated. Every
`done` row names the code or test that proves it.

**As of:** 2026-10-15 · Swift 6.3.3 on Linux x86_64 · `swift test`: TSOFiles 100 passed (98 without
`TSO_GAME_DIR`, which skips the 2 real-install tests), TSOContent 1 passed, SimAntics 1 passed.

Status values: `done` (works and is tested), `partial` (works with gaps, named in the note),
`missing` (not started).

## Summary

| Area | Done | Partial | Missing | Key numbers |
|---|---:|---:|---:|---|
| [Formats](#formats) | 9 | 1 | 11 | 100 test cases; real install: 94 containers, 82,131 entries, 51,620 typed chunks, 0 failures |
| [Content](#content) | 0 | 0 | 9 | |
| [SimAntics](#simantics) | 1 | 0 | 14 | 0 of about 70 primitives |
| [Fidelity](#fidelity) | 2 | 1 | 3 | install scan and real-data invariants clean; no replay oracle |
| [Determinism](#determinism) | 0 | 0 | 5 | |
| [Reliability](#reliability) | 4 | 1 | 2 | 0 force unwraps, 0 `try!`, 0 `fatalError` in sources |
| [Tests and tooling](#tests-and-tooling) | 5 | 2 | 0 | |
| [Platforms](#platforms) | 3 | 0 | 1 | |
| [Known differences from 2017](#known-differences-from-2017) | | | | 8 deliberate |
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
| FMT-10 | Object chunks: `OBJD`, `OBJf`, `OBJT`, `OBJM`, `GLOB`, `SLOT`, `TTAB`, `FWAV` | partial | Done: `OBJD` (word layout per version, 90 named fields generated from the C# field list, type attribute fallback), `OBJf`, `GLOB`, `SLOT` (per-version defaults and scaling), `TTAB` (plain and field-encoded, via `IFF/FieldEncodedReader.swift`), `FWAV`; `ObjectChunkTests`, `FieldEncodedReaderTests`. Real install: 2,706 OBJD, 1,755 OBJf, 206 GLOB, 790 SLOT, 898 TTAB, 5,408 FWAV; every loaded interaction fits its pie menu strings where the IFF has them. Missing: `OBJT`, `OBJM` |
| FMT-11 | Lot and TS1 chunks: `ARRY`, `WALm`, `FLRm`, `CARR`, `FAMI`, `FAMs`, `NBRS`, `NGBH`, `SIMI`, `TATT` | missing | Pixie Point |
| FMT-12 | Sprite chunks decoded to RGBA plus depth: `SPR#`, `SPR2`, `PALT`, `DGRP` | missing | Hyde Park |
| FMT-13 | Images: `BMP_`, `THMB`, BMP, TGA, PNG with magenta masking | missing | Hyde Park |
| FMT-14 | PIFF: apply patches to an IFF, `User/` precedence | missing | King Canyons |
| FMT-15 | OTF tuning tables and `tuning.dat` | missing | King Canyons |
| FMT-16 | `datadefinition.dat` and INI files | missing | King Canyons |
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
| CNT-1 | Game locator: configured path, `TSO_GAME_DIR`, per-OS defaults | missing | Ocean's Edge |
| CNT-2 | Case-insensitive file index over the install | missing | Ocean's Edge; fixes the 2017 Linux path failures |
| CNT-3 | FAR3 providers keyed by `AssetID`, with a bounded cache | missing | Ocean's Edge |
| CNT-4 | Object provider: `objecttable.xml`, `objiff.far`, sprites, tuning, standalone objects | missing | Ocean's Edge |
| CNT-5 | Semi-global and global IFFs | missing | Ocean's Edge |
| CNT-6 | Avatar providers: meshes, skeletons, animations, outfits, appearances, bindings, hand groups, thumbnails | missing | Ocean's Edge |
| CNT-7 | Walls, floors, roofs, city maps, UI graphics, audio resource groups | missing | Ocean's Edge |
| CNT-8 | Async initialization with progress, no singleton | missing | Ocean's Edge |
| CNT-9 | TS1 hybrid providers | missing | Ocean's Edge, after TSO mode works |

## SimAntics

Package: [SimAntics](../NSOClient/SimAntics/). Ports `TSOClient/tso.simantics` (see
[fso/simantics.md](fso/simantics.md)).

| Id | Target | Status | Note |
|---|---|---|---|
| VM-1 | Tick rate constant (30 per second) | done | `TickRate.swift`; `TickRateTests` |
| VM-2 | BHAV translator: decode operands once per routine | missing | Queen Margaret's |
| VM-3 | Thread, stack frames, exit codes, subroutine calls by opcode range | missing | Queen Margaret's |
| VM-4 | Variable scopes (`VMMemory`) including tuning lookup (BCON then OTF) | missing | Queen Margaret's |
| VM-5 | Scheduler and `InternalTick` order | missing | Queen Margaret's |
| VM-6 | Entities: objects, avatars, multitile groups, motives | missing | Queen Margaret's |
| VM-7 | Lot model: architecture, rooms, placement queries | missing | Queen Margaret's |
| VM-8 | Interactions: TTAB checks, action queue, priorities | missing | Queen Margaret's |
| VM-9 | Primitives: about 70, `VMExpression` first | missing | Rancho Rizzo |
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
| FID-4 | Replay harness: 2017 recordings of commands and per-tick state hashes | missing | West Darrington |
| FID-5 | Swift VM matches recorded state hashes for a basic lot over an in-game day | missing | Queen Margaret's to Shannopolis |

## Determinism

Rules the VM must follow for lockstep. None can be checked until VM code exists; each needs a test
or a lint when it does.

| Id | Target | Status | Note |
|---|---|---|---|
| DET-1 | All 16-bit VM arithmetic wraps (`&+`, `&-`, `&*`), division matches FreeSO | missing | Overflow traps in Swift; C# wraps |
| DET-2 | No `Dictionary` or `Set` iteration in VM logic | missing | Swift randomizes hash seeds per process |
| DET-3 | One seeded random generator, owned by the VM context | missing | |
| DET-4 | No wall-clock time or floating point feeding simulation state without review | missing | Routing and animation timing need a look |
| DET-5 | Same replay result on Linux x86_64, Linux ARM64, and macOS ARM64 | missing | Needs FID-4 and CI on those runners |

## Reliability

| Id | Target | Status | Note |
|---|---|---|---|
| REL-1 | Corrupt or truncated input throws a typed error, never crashes | done | Every reader throws a typed error (`EndOfDataError`, `RefPackError`, `FAR1Error`, `FAR3Error`, `IFFError`); tests cover truncation and bad sizes |
| REL-2 | No `try!`, force unwraps, `fatalError`, or `precondition` in library sources | done | Checked with a grep over `NSOClient/*/Sources` on 2026-10-15; no lint enforces it yet (TST-5) |
| REL-3 | Archives are immutable values, safe to read from several threads | done | `FAR1Archive` and `FAR3Archive` are `Sendable` structs over memory-mapped `Data`; removes the 2017 `isReadingSomething` race |
| REL-4 | Swift 6 language mode (strict concurrency) in every package | done | `swiftLanguageModes: [.v6]` in all three manifests |
| REL-5 | Size limits on allocations driven by file data | partial | Reads are bounded by the data length; RefPack output growth and declared decompressed sizes have no cap yet |
| REL-6 | Fuzzing of every reader with malformed input | missing | |
| REL-7 | Bounded caches for decoded content | missing | Ocean's Edge |

## Tests and tooling

| Id | Target | Status | Note |
|---|---|---|---|
| TST-1 | Swift Testing in every package | done | `import Testing` in all test targets |
| TST-2 | Synthetic fixtures only, no EA data in the repository | done | `Tests/TSOFilesTests/Support/ByteWriter.swift` builds archives, RefPack streams, and IFFs in code |
| TST-3 | Each package builds and tests on its own | done | `swift build` and `swift test` per package; path dependencies resolve |
| TST-4 | CI runs all three packages on every push | done | `.github/workflows/swift.yml`: builds and tests each package on Linux x86_64 and ARM64 (`swift:6.3` container) and on macOS, for pushes and pull requests that touch `NSOClient/`. Run 38812498011 (commit `9fe95212`) passed all three jobs |
| TST-5 | Lint for REL-2 and DET-2 (SwiftLint custom rules or a script) | partial | The CI workflow fails on `try!`, `as!`, `fatalError`, or `precondition` in library sources. Not covered: force unwraps (`!`), and DET-2 (no SimAntics code yet) |
| TST-6 | Real-file tests gated on `TSO_GAME_DIR` | done | `RealInstallTests` runs when `TSO_GAME_DIR` is set and is skipped otherwise; no game data in the repository |
| TST-7 | Script that extracts the TSO installer's cabinets into a game folder | partial | `NSOClient/scripts/extract.sh`: detects Microsoft (cabextract) or InstallShield (unshield) cabinets, accepts a folder, a cabinet, or a .zip, tests integrity first, finds the folder holding `tuning.dat`, optional `--lowercase` and `--check`. Tested on hand-built Microsoft cabinets (extraction, lower-casing, .zip input, damaged and foreign files, usage errors). Not yet tested: spanned cabinet sets, InstallShield (unshield isn't installed here), the real installer |

## Platforms

No `platforms:` are declared (owner decision); this tracks where the packages are known to build.

| Id | Target | Status | Note |
|---|---|---|---|
| PLAT-1 | Linux x86_64 | done | Swift 6.3.3, all tests pass |
| PLAT-2 | Linux ARM64 | done | CI job `Linux (aarch64)`, `swift:6.3` container |
| PLAT-3 | macOS | done | CI job `macOS` on `macos-latest`. With no `platforms:` declared, builds target macOS 10.13, so APIs newer than that can't be used (the first run failed on `FileHandle.read(upToCount:)`) |
| PLAT-4 | Windows | missing | Untested; Foundation on Windows is the least tested |

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

## Open bugs

None filed yet. Bugs found in the 2017 code that the port fixes go under known differences, not
here.
