# NSOClient roadmap: milestones and what's next

> **Last reviewed:** 2026-10-16 · **Last updated:** 2026-10-16 · **Change:** minor (Queen Margaret's third pass, phase C3: slots and containment) · **Target:** behavior parity with FreeSO's engine-free libraries at the 2017-08-09 snapshot (FSO.Files, FSO.Content, FSO.SimAntics)

Forward-looking: the milestones, the current focus, and what comes next for the Swift packages in
[`NSOClient/`](../NSOClient/). The evidence behind every status is in [scorecard.md](scorecard.md).
What FreeSO's code does, and why, is in [fso/](fso/README.md); how the Swift code behaves is in
[nso/](nso/README.md).

Keep it current: at the end of every session, update the milestone rows, the scorecard, and the
revision history. Re-estimate when a milestone lands.

## Scope

Three independent SwiftPM packages, each with its own tests:

| Package | Ports | Depends on |
| --- | --- | --- |
| [TSOFiles](../NSOClient/TSOFiles/) | FSO.Files, plus the Vitaboy model formats (see [decisions](#decisions-for-the-owner)) | Foundation |
| [TSOContent](../NSOClient/TSOContent/) | FSO.Content, without GPU upload | TSOFiles |
| [SimAntics](../NSOClient/SimAntics/) | FSO.SimAntics, headless (no LotView, no HIT) | TSOContent, TSOFiles |

Out of scope here: rendering, audio playback, UI, networking transports, and servers. Those consume
these packages later.

## Alpha gate

These are libraries, so the gate is a set of end-to-end jobs a caller must be able to do against a
real TSO install, on Linux, with no crash. Any `no` keeps NSOClient pre-alpha. A row blocks only if
the job can't be done at all for typical inputs; a missing sub-case or a known difference from FreeSO
is `partial, not blocking`.

| Core job | Works end to end? | Evidence | Hours to pass |
|---|---|---|---|
| Open every FAR1, FAR3, DBPF, and IFF file in a TSO install | yes | `tsofiles-check` on a real install: 94 containers, 82,131 entries, 0 failures (scorecard FID-1). The first run found `packingslips.dat` repeating file IDs across types; FAR3 now looks entries up by full asset ID (scorecard DIFF-5) | 0 |
| Load one object with its behavior, strings, tuning, and sprites | partial, not blocking | `GameContent` loads every object on the beta with its patches, tuning, semi-global, and routines by name, matching FreeSO on all 2,649 objects FreeSO loads (scorecard FID-8). Sprite IFFs load but sprites don't decode yet | 25–40 (Hyde Park) |
| Load one avatar: mesh, skeleton, animation, outfit, appearance | no | Not started | 50–75 (Nichol's Notch, Ocean's Edge in part) |
| Run a lot headless for one in-game day without a SimAntics error | no | Objects are created (multi-tile ones included), initialize, run `main` tick by tick, and are deleted when they keep failing; the 2,743 that need no unported primitive match FreeSO's digests over 30 ticks (scorecard FID-10). Rooms, multi-tile groups, placement, and slots are ported; no lot loading yet, and 40 of 49 primitives missing | 255–420 (Queen Margaret's to Shannopolis, Virginia Islands in part) |
| Save and reload a lot (VMMarshal version 19) | no | Not started | 20–30 (Terra Tablante) |
| Replay a recorded FreeSO session to an identical state hash | no | No recording harness (decision 2) | 15–30 (West Darrington) plus everything above |

**Result: pre-alpha.** Ready for real work: ≈ 18%.

## Current focus

In order:

1. **Queen Margaret's, third pass,** in phases, each checked against the oracle:
   - [x] A. Positions, facings, and the tile index.
   - [x] B. Architecture and rooms: walls, floors, room detection, room info; walls and floors read
     from blueprint XML; a new oracle command to compare room maps.
   - [x] C. In three steps:
     - [x] C1. Multi-tile groups, object creation as `CreateObjectInstance` does it, deletion, and the
       Create Object Instance primitive out of the world.
     - [x] C2. Placement in the world: footprints, placement checks, and the placement entry point.
     - [x] C3. Slots and containment, and Find Location For.
   - [ ] Mock install wiring: unit tests read `NSOClient/MockInstall` instead of building fixtures in
     code, the oracle loads it (its install overlay can't find the object table yet), and CI runs
     the oracle comparisons against it.
   - [ ] D. Lot loading from blueprint XML, then `run-lot` digests compared with FreeSO tick by tick.
2. **Hyde Park:** sprite formats (`SPR2`, `SPR#`, `DGRP`), so the last part of loading one object works.

## Milestones

Milestones are named after The Sims Online's unused cities, the beta-only cities that never opened
for play ([list](https://www.tsomania.net/cities/lost.php)). The names are labels, not an order;
the table lists milestones in planned order. Grantley Grove, Yatesport, and Zavadaville are left for
later milestones.

"Plan size" comes from the non-blank C# lines each milestone ports, at an assumed 100–150 lines per
hour for format code and 50–80 for VM code, tests included. Those rates are a first guess, not a
measurement; recalibrate them when Pixie Point lands. "Done" is the share of the milestone's acceptance
criteria met, not lines written.

| Milestone | Scope | C# lines | Plan size (h) | Done | Remaining (h, 2026-10-15) | Notes |
|---|---|---:|---|---|---|---|
| Albertstown | Scaffolding: three packages, Swift 6 mode, Swift Testing | 0 | 1–2 | 100% | 0 | Path dependencies TSOContent → TSOFiles, SimAntics → TSOContent, TSOFiles. No `platforms:` (owner decision). |
| Xanadu | Binary reading and containers: ByteReader, FAR1, FAR3, RefPack, IFF container, DBPF, install scanner | 1,859 | 12–19 | 100% | 0 | Done: all containers, plus `InstallScanner` and the `tsofiles-check` command (exit 0 clean, 1 failures, 2 usage); 55 test cases. Kept quirks: RefPack short input and growth, 0xFD to 0xFF, FAR3 duplicate IDs, IFF trailing byte, DBPF version arithmetic and first-wins IDs. Real install: 0 failures over 82,131 entries. |
| Pixie Point | Typed IFF chunks for TSO: behavior, strings, objects, interactions, slots | 2,042 | 14–20 | 100% | 0 | Done: `BHAV`, `BCON`, `TRCN`, `TPRP`, `STR#`, `CTSS`, `TTAs`, `OBJD`, `OBJf`, `GLOB`, `SLOT`, `TTAB`, `FWAV`, the field-encoded number reader, and chunk parsing in `tsofiles-check`; 100 tests, 2 against the real install. Real install: 51,620 chunks, 0 failures. The TS1-only chunks moved to Charvatia. |
| Hyde Park | Sprites and images: `SPR#`, `SPR2`, `PALT`, `DGRP`, `BMP_`, `THMB`, BMP, TGA, PNG to RGBA | 3,543 | 24–35 | 0% | 24–35 | Decode to plain RGBA plus SPR2 depth, no textures. Includes TargaImagePCL's TGA reader. |
| King Canyons | Patching and tables: PIFF apply, OTF, `tuning.dat`, `datadefinition.dat`, INI | 802 | 5–8 | 100% | 0 | Done: PIFF chunk and patch application with FreeSO's index rules, `PatchRegistry`, `OTFFile`, `TuningFile`, `DataDefinition`, `INIFile`; 125 tests, 6 against the real install. PIFF encoding (237 C# lines) isn't ported; decision 4 is still open. |
| Landry Lakes | Audio formats: UTK, XA, HIT, HOT, EVT, HSM, FSC, TLO, hitlists | 1,651 | 11–17 | 0% | 11–17 | Decoding only; playback is a client concern. |
| Nichol's Notch | Vitaboy model formats: mesh, skeleton, animation, appearance, binding, outfit, hand groups, BCF/CFP | 1,511 | 10–15 | 0% | 10–15 | Package placement is decision 1. |
| Ocean's Edge | TSOContent: game locator, case-insensitive file index, providers and codecs, object and avatar catalogs, TS1 hybrid | 5,819 | 39–58 | 40% | 23–35 | Object path done: `GameLocator`, `GameFileIndex`, `GlobalProvider`, `ObjectProvider`, and `GameContent` (no singleton), checked object for object against `fso-oracle list-objects`. Left: FAR3 providers with a bounded cache, avatar providers, walls, floors, roofs and other assets, the catalog, async initialization with progress, TS1 hybrid. |
| West Darrington | Oracle harness and replays: FreeSO SimAntics on modern .NET, differential tests per primitive, then whole-lot replays with a shared state digest | new | 20–40 | 70% | 6–12 | Phases 1 and 2 done. `fso-oracle run-lot` loads a lot headless against the 2002 beta and prints repeatable state digests (version 0). `fso-oracle run-primitive` runs single FreeSO primitives from JSON requests on a fresh lot each, reporting the exit code, registers, and every changed global and object value (protocol version 1, regression-checked by `check_protocol.py`). Phase 3, after Terra Tablante: lot recordings and replays. |
| Queen Margaret's | SimAntics core: VM, context, threads, stack frames, memory scopes, scheduler, translator, entities, lot model | 13,368 | 165–270 | 56% | 72–118 | Two passes done (the core with Expression, then the runtime: entry points, init and reset, check threads, error handling, the clock, the scheduler, definition fields, state digests). Third pass, the lot model, in four phases; A (positions, facings, the tile index), B (architecture and rooms), C1 (multi-tile groups, creation, deletion), C2 (placement), and C3 (slots and containment) are done. |
| Rancho Rizzo | Primitives (49 in TSO) | 6,665 | 85–135 | 18% | 70–111 | Expression, Sleep, Refresh, Random Number, Find Location For, Play Sound, Set To Next, Test Object Type, and Create Object Instance done. `run-objects` ranks the rest by how many objects each blocks; the biggest blockers now are Run Tree By Name and Transfer Funds. |
| Shannopolis | Routing: `VMRoutingFrame`, `VMRectRouter`, obstacles | 1,586 | 20–32 | 0% | 20–32 | Floating point here must be checked for determinism. |
| Terra Tablante | Saves: marshals, version 19 read and write, hollow saves | 1,572 | 20–30 | 0% | 20–30 | Must read saves written by FreeSO servers. |
| The Billabong | Lockstep: net commands, ticks, server and client drivers, resync | 3,987 | 50–80 | 0% | 50–80 | Byte-level compatibility with FreeSO commands is decision 3. |
| Upper Shankelston | EOD plugin handlers | 5,217 | 65–105 | 0% | 65–105 | Server-side logic only; panels belong to a client. |
| Virginia Islands | Lot utilities: world and TS1 activators, architecture tools, lot rotation, terrain restore | 2,680 | 35–55 | 0% | 35–55 | Needed for houses from XML and surrounding lots. |
| Charvatia | TS1 house and neighborhood chunks: `OBJT`, `OBJM`, `ARRY`, `WALm`, `FLRm`, `CARR`, `FAMI`, `FAMs`, `NBRS`, `NGBH`, `SIMI`, `TATT`, and field-encoded strings | 764 | 5–8 | 0% | 5–8 | Only TS1 hybrid mode reads these; a TSO install contains none (checked 2026-10-15). Deferred by the owner; port it when TS1 hybrid is needed, ideally checked against a TS1 install. `OBJM` is decoded by heuristic search in FreeSO. |
| Yatesport | SimsScript: a text assembly for BHAVs, an LSL-like language that compiles to them, a decompiler from existing objects, LSL `state`s and interactions, editor support | new | 70–120 | 5% | 67–114 | Later, after alpha; not counted in the totals below. Proof of concept in `NSOClient/SimsScript` (decision 5). |
| | **Total** | **≈ 53,000** | **≈ 580–930** | **≈ 18% ready** | **≈ 419–658** | |

## Upcoming milestones, ranked

| Rank | Next milestone | Closes | Estimate (h) |
|---|---|---|---|
| 1 | Lot model, object creation, and lot loading | Queen Margaret's (third part), alpha row 3 in part | 50–90 |
| 2 | Sprites and images | Hyde Park | 24–35 |
| 3 | Avatars: Vitaboy formats and providers | Nichol's Notch, Ocean's Edge avatar path | 30–45 |

## Critical path

Albertstown → Xanadu → Pixie Point → King Canyons → Ocean's Edge (objects) → Queen Margaret's → Rancho Rizzo → Shannopolis is strictly in order: the VM can't run without
typed behavior chunks, patched IFFs, and a content provider. West Darrington has to land before Queen Margaret's can claim any
fidelity. Hyde Park, Landry Lakes, and Nichol's Notch run beside it and only gate the avatar and rendering consumers. Terra Tablante to Virginia Islands
follow Queen Margaret's. The long poles are Queen Margaret's (VM core) and Rancho Rizzo (primitives). Charvatia (TS1
chunks) can land whenever TS1 hybrid mode is needed; nothing in TSO mode waits on it.

## Decisions for the owner

1. **Where the Vitaboy model formats live.** In TSOFiles (they're file formats) or a fourth package
   `Vitaboy` (as in FreeSO). Recommended: TSOFiles, to keep three packages.
2. **How to record FreeSO replays.** Decided (2026-10-15): an oracle harness. A .NET 10 console tool
   in `NSOClient/Oracle/` compiles FreeSO's SimAntics, Files, and Content sources (linked read-only)
   with stubs for rendering and audio, and runs the VM headless (`VM.UseWorld = false`, as the lot
   server does). It serves two kinds of reference results: first, per-primitive differential tests
   (the Swift tests send an operand and variables, the oracle runs FreeSO's primitive); later,
   whole-lot replays using FreeSO's own lockstep stream (an initial `VMMarshal` plus `VMNetTickList`
   batches) and a state digest that both sides compute the same way. Recordings are generated from
   `TSO_GAME_DIR` and not committed. AGENTS.md allows `dotnet` for this tool only.
3. **Wire compatibility of lockstep commands.** Decided (2026-10-16): not a requirement. FreeSO's
   server protocol began as an attempt to talk to the original TSO client and still carries code
   from then, though it later stopped being compatible; NSOClient doesn't hold to it. Matching
   FreeSO's commands byte for byte stays an option where it doubles as a fidelity check.
4. **Editing support.** PIFF encoding and `IffFile` change tracking only matter for an editor. Port
   them now, or defer. Recommended: defer.
5. **Scripting.** Decided (2026-10-16): an LSL-like language for both editing existing objects and
   authoring new ones, compiling to ordinary BHAV, `OBJf`, and later `TTAB` chunks, so any VM runs
   the result unchanged and objects can be edited on any platform as text. It's a later milestone
   (Yatesport); for now a proof of concept tests feasibility: a text assembly that round-trips every
   routine in the install, operand encoders, and a small compiler whose output runs on the Swift VM.
5. **Real-file tests.** Decided (2026-10-15): tests read `TSO_GAME_DIR` and are skipped when it isn't set (`RealInstallTests`).
   `TSO_GAME_DIR` and are skipped when it isn't set.

## Risks most likely to push estimates up

- **SimAntics fidelity:** about 70 primitives whose exact behavior, including bugs the game's code
  relies on, must match FreeSO.
- **No whole-lot replays yet:** `fso-oracle` checks single primitives and content, but lot recordings wait for Terra Tablante (West Darrington phase 3), so multi-tick VM behavior is checked only by state digests from `run-lot`.
- **Determinism in Swift:** randomized hash seeds and trapping integer overflow are easy to trip
  over; one slip causes desyncs or a crashed lot.
- **Real files:** synthetic tests pass, but the original install may hold variants FreeSO's code
  only handled by accident.
- **Game version:** the owner's install is a 2002 beta, while FreeSO targets the 2003 production
  files. Real-file checks can't confirm production-only behavior, and beta differences must be told
  apart from port bugs (a C#-faithful simulation does that).
- **Floating point in routing and animation** may need fixed-point rewrites to stay deterministic
  across x86_64 and ARM64.
- **Foundation `Data` performance** on large archives under swift-corelibs-foundation is
  unmeasured.
- **The estimate itself:** the hourly rates are guesses until Pixie Point gives a measured rate.

## Revision history

| Date | Change | Summary |
|---|---|---|
| 2026-10-16 | minor | Queen Margaret's third pass, phase C3: container slots and what they hold (`placeInSlot`, the containment object data, the slot scopes), contents moving with their container and placed nearby when it's deleted, stacking onto a slot when placing, the buildable-area check (empty on blueprint lots, as in FreeSO), and Find Location For (16). Objects running alone and matching FreeSO went from 2,597 to 2,743; Expression now runs all 3,809 cases, Create Object Instance 1,245 of 1,255, and Find Location For all 1,538, every one matching. `run-primitive` reports each lot object's slots. |
| 2026-10-16 | minor | Queen Margaret's third pass, phase C2: placement as `ChangePosition` does it: footprints, the bounds, wall, floor, and overlap checks, multi-tile offsets turned with the facing and undone when a part doesn't fit, room entity lists, wall use, door and window wall styles, dynamic multi-tile joining, and the placement entry point. Create Object Instance now places in the world; all 1,167 of its 1,255 cases the port can run match, 672 of them placed objects. `run-primitive` now reports lot objects' state (object data, attributes, footprint) and groups, so tests rebuild the lot exactly. The owner's house (`NSOClient/Lots`, 564 walls, 211 objects) joined the room-map comparison and matches; the oracle now leaves out objects FreeSO can't load on the install, such as one whose FreeSO patch doesn't fit the 2002 files. |
| 2026-10-16 | minor | Queen Margaret's third pass, phase C1: multi-tile groups (`MultitileGroup`), object creation as `CreateObjectInstance` does it, deletion of objects that keep failing, Set To Next's part search, and the Create Object Instance primitive out of the world (all 314 of 475 cases the port can run match). The oracle fixtures now come from the 2002 production copy; every comparison still matches, and objects running alone and matching FreeSO went from 2,163 to 2,597. |
| 2026-10-16 | minor | Queen Margaret's third pass, phase B: walls and floors (`Architecture`), FreeSO's room flood fill, rooms by position, entities' rooms, room data (scope 23), and walls and floors from blueprint XML. `fso-oracle room-maps` dumps FreeSO's room maps; all 61 lots compared (FreeSO's empty lot and 60 synthetic ones with walls, fences, diagonals, pools, and upper floors) match. Expression matches on 3,785 cases, and objects running alone and matching FreeSO went from 1,932 to 1,988. |
| 2026-10-16 | minor | Queen Margaret's third pass, phase A: `LotPosition`, `Direction`, entity positions, and the tile index keyed as FreeSO does. Set To Next's same-tile and adjacent searches and Expression's upstairs test now work, matching FreeSO on all 212 and 3,734 cases; objects running alone and matching FreeSO went from 1,914 to 1,932. `run-primitive` reports lot objects' positions, facings, and the lot size. |
| 2026-10-16 | minor | Play Sound ported and matching FreeSO on all 160 oracle cases (headless, it changes nothing); objects running alone and matching FreeSO went from 1,886 to 1,914. The primitive-first part of Rancho Rizzo is done: the biggest blockers left (slots, rooms, multi-tile groups) come with the lot model, which is next. Refactored along the way: operand coding in its own file, operand flags as an option set, and one case generator for every primitive. |
| 2026-10-16 | minor | Random Number ported and matching FreeSO on all 71 oracle cases; objects running alone and matching FreeSO went from 1,842 to 1,886. Under the revised goals, variables became a `Variable` value read and written through `StackFrame` (scopes kept in 16 bits, as some operands store them), and lead-tile attributes now work for lone objects, so Expression matches on 3,733 cases. |
| 2026-10-16 | minor | Set To Next ported and matching FreeSO on all 128 oracle cases it can run; objects running alone and matching FreeSO went from 1,628 to 1,842. The VM gained FreeSO's category index, and `run-primitive` now reports every lot object (GUID, category, and whether it's indexed) so tests rebuild the whole lot. |
| 2026-10-16 | minor | Refresh ported and matching FreeSO on all 40 oracle cases; objects running alone and matching FreeSO went from 1,069 to 1,628. Headless, Refresh changes nothing an out-of-world object can see; the lot model must make it recompute room lighting and score. |
| 2026-10-16 | minor | Test Object Type ported and matching FreeSO on all 48 oracle cases; objects running alone and matching FreeSO went from 800 to 1,069. The fixture script now asks the oracle for the lot's object GUIDs, so cases can name real objects on any install. |
| 2026-10-16 | minor | Goals revised: the modern .NET rewrite is no longer a goal, and NSOClient is a new reimplementation that matches FreeSO's results rather than its code. Decision 3 settled: FreeSO's network protocol isn't a compatibility target. |
| 2026-10-16 | minor | Sleep ported and matching FreeSO on all 135 oracle cases. Objects that run alone and match FreeSO digest for digest went from 6 to 800. `run-primitive` gained the thread's idle start, interrupt flag, and scheduled tick, and the oracle fixtures now cover each ported primitive by name. |
| 2026-10-16 | minor | Decision 5 (scripting): an LSL-like language for editing and authoring, as a later milestone, Yatesport, outside the alpha totals. Proof of concept added: `BHAV.encoded()` and operand encoders (every Expression and call operand in the install re-encodes to its bytes), a text assembly that round-trips all 15,723 routines, and a compiler for a small LSL-like subset whose output runs on the Swift VM. |
| 2026-10-16 | minor | Queen Margaret's second pass: entry points (tables match FreeSO for all 2,649 objects), init and reset, check threads, error handling, the clock, the scheduler, `VM.tick()`, object definition fields, and a version 0 state digest. `fso-oracle run-objects` runs each object alone; the 6 the port can run match FreeSO's digests over 30 ticks, and the rest rank the unported primitives by how many objects they block. Expression now matches on 3,691 cases. Lot loading moved to a third pass: it needs the lot model, multi-tile groups, and most primitives, so whole-lot digests come after Rancho Rizzo's first part. Found and fixed two port bugs: unported primitives silently took the true branch, and direction writes ignored the rotation step. |
| 2026-10-16 | minor | Queen Margaret's first pass: the VM core (entities, threads, stack frames, variable scopes, tuning lookup, routine translation, the random generator) and Expression. `NSOClient/scripts/oracle-fixtures.sh` generates 3,387 Expression cases and their FreeSO answers; all 3,289 the port can run match, and the other 98 need state not ported yet (clock, slots, multi-tile groups, object definition fields, entry points). The comparison found one wrong reading of FreeSO (a list on a missing stack object fails at once), now fixed. |
| 2026-10-16 | minor | Ocean's Edge object path done: `GameContent` indexes the install case-insensitively, applies FreeSO's patches, and loads objects, globals, and semi-globals. Against `fso-oracle list-objects` on the 2002 beta, all 2,649 objects FreeSO loads match; FreeSO fails on 45 more (44 production patches that don't fit, 1 missing IFF) and Swift loads 44 of them. Found and fixed a Linux slowdown in TSOFiles' directory listing (`resourceValues` cost 2 ms a file; indexing went from 3.7 s to 0.03 s). Alpha row 2 is now partial: only sprites are left. |
| 2026-10-16 | minor | West Darrington phase 2 done: `fso-oracle run-primitive` reads JSON requests (opcode, operand, registers, globals, object data and attributes), runs FreeSO's handler on a freshly loaded lot each time (about a quarter second per request), and reports the exit code, the registers, and every changed value. Exceptions and bad requests come back as responses. Early finding: FreeSO's Expression divides by zero without failing and gives -1. FreeSO's code's console messages now go to standard error, so standard output carries only results. Avatars aren't covered yet; the default lot has none. |
| 2026-10-15 | minor | West Darrington phase 1 done: the oracle compiles the unchanged FreeSO SimAntics stack on .NET 10 with four small stubs and runs it headless on Linux. The 2002 beta needed placeholders (three sound groups, six expansion archives), adapted object and catalog tables, and six production-only objects left out of the default lot, all reported. The VM reseeds when a lot loads, so the oracle seeds it again afterwards; three 1,800-tick runs give identical digests. |
| 2026-10-15 | minor | Decision 2 settled: an oracle harness that compiles FreeSO's SimAntics sources on modern .NET serves per-primitive differential tests first and whole-lot replays later. West Darrington re-planned in three phases and re-estimated from 15–30 to 20–40 hours (stubs for LotView and HIT). AGENTS.md allows `dotnet` for the oracle only. |
| 2026-10-15 | minor | PIFF is FreeSO's own format, written against TSO's 2003 production files; the owner's install is a 2002 beta. Checked against FreeSO's 36 shipped patches: fixed a port bug (a final removal past the end is allowed when nothing remains, as in FreeSO), and the patch registry now applies each patch only if it fits, skipping and reporting the rest (of the 27 that target `objiff.far` objects, 17 apply to the beta and 10 are skipped). Estimates unchanged. |
| 2026-10-15 | minor | King Canyons done: PIFF patching (apply only) with FreeSO's deletion, swap, and add rules, the patch registry, OTF, `tuning.dat`, the data definition, and INI. All read the real install; `sys/nametohostmap.ini` repeats a section, as FreeSO would reject too, but nothing loads it. 125 tests. Estimates unchanged. |
| 2026-10-15 | minor | Pixie Point done for TSO. A real install contains none of the remaining chunk types, which only TS1 hybrid mode reads, so the owner deferred them to a new Charvatia milestone (764 C# lines, 5–8 h). Current focus moves to King Canyons. Estimates unchanged. |
| 2026-10-15 | minor | Pixie Point at 70%: thirteen chunk types (behavior, strings, objects, interactions) plus the field-encoded number reader. A real install parses 51,620 chunks with 0 failures, BHAV branch targets and pie menu indices check out, and five orphaned old `TTAB`s are reported separately. Decision 5 settled. Estimates unchanged. |
| 2026-10-15 | minor | Alpha gate row 1 passes: `tsofiles-check` reads a real TSO install (94 containers, 82,131 entries) with 0 failures. The first run failed on `packingslips.dat`, which repeats file IDs across type IDs; FAR3 lookups now use the full asset ID (identical results for every archive FreeSO loads). Estimates unchanged. |
| 2026-10-15 | minor | Xanadu done: `DBPFArchive` (both header layouts, first-wins IDs) and `InstallScanner` with the `tsofiles-check` command. 55 test cases. The real-install run is the remaining step for alpha gate row 1. Estimates unchanged. |
| 2026-10-15 | minor | Renamed milestones at the owner's request: Charvatia is now Xanadu, Grantley Grove is now Pixie Point, and the replay harness (formerly Pixie Point) is now West Darrington. Estimates unchanged. |
| 2026-10-15 | major | First version: scope, alpha gate (pre-alpha, ≈ 2%), milestones Albertstown to Virginia Islands sized from C# line counts, ranked next steps, owner decisions, risks. Albertstown done; Xanadu at 85% (DBPF missing). |
