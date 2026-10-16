# NSOClient roadmap: milestones and what's next

> **Last reviewed:** 2026-10-16 · **Last updated:** 2026-10-16 · **Change:** minor (West Darrington phase 2 done: the oracle runs single 2017 primitives on request over a JSON-lines protocol) · **Target:** behavior parity with FreeSO's engine-free libraries at the 2017-08-09 snapshot (FSO.Files, FSO.Content, FSO.SimAntics)

Forward-looking: the milestones, the current focus, and what comes next for the Swift packages in
[`NSOClient/`](../NSOClient/). The evidence behind every status is in [scorecard.md](scorecard.md).
What the 2017 code does, and why, is in [fso/](fso/README.md); the Swift design is sketched in
`Stash/swift-ada-vapor.md` (local only).

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
the job can't be done at all for typical inputs; a missing sub-case or a known difference from 2017
is `partial, not blocking`.

| Core job | Works end to end? | Evidence | Hours to pass |
|---|---|---|---|
| Open every FAR1, FAR3, DBPF, and IFF file in a TSO install | yes | `tsofiles-check` on a real install: 94 containers, 82,131 entries, 0 failures (scorecard FID-1). The first run found `packingslips.dat` repeating file IDs across types; FAR3 now looks entries up by full asset ID (scorecard DIFF-5) | 0 |
| Load one object with its behavior, strings, tuning, and sprites | no | Behavior, string, and object chunks parse, and patching and tuning work (scorecard FMT-8 to FMT-16); no sprites or content provider yet | 55–80 (Hyde Park, Ocean's Edge in part) |
| Load one avatar: mesh, skeleton, animation, outfit, appearance | no | Not started | 50–75 (Nichol's Notch, Ocean's Edge in part) |
| Run a lot headless for one in-game day without a SimAntics error | no | `TickRate` only | 300–480 (Queen Margaret's to Shannopolis, Virginia Islands in part) |
| Save and reload a lot (VMMarshal version 19) | no | Not started | 20–30 (Terra Tablante) |
| Replay a recorded 2017 session to an identical state hash | no | No recording harness (decision 2) | 15–30 (West Darrington) plus everything above |

**Result: pre-alpha.** Ready for real work: ≈ 6%.

## Current focus

In order:

1. **The object path of Ocean's Edge:** `WorldObjectProvider` and semi-globals, so one object loads end
   to end.
2. **Queen Margaret's core:** `VM`, `VMContext`, `VMThread`, `VMMemory`, the scheduler, and the BHAV translator,
   with `VMExpression` as the first primitive, checked against `fso-oracle run-primitive`.

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
| King Canyons | Patching and tables: PIFF apply, OTF, `tuning.dat`, `datadefinition.dat`, INI | 802 | 5–8 | 100% | 0 | Done: PIFF chunk and patch application with the 2017 index rules, `PatchRegistry`, `OTFFile`, `TuningFile`, `DataDefinition`, `INIFile`; 125 tests, 6 against the real install. PIFF encoding (237 C# lines) isn't ported; decision 4 is still open. |
| Landry Lakes | Audio formats: UTK, XA, HIT, HOT, EVT, HSM, FSC, TLO, hitlists | 1,651 | 11–17 | 0% | 11–17 | Decoding only; playback is a client concern. |
| Nichol's Notch | Vitaboy model formats: mesh, skeleton, animation, appearance, binding, outfit, hand groups, BCF/CFP | 1,511 | 10–15 | 0% | 10–15 | Package placement is decision 1. |
| Ocean's Edge | TSOContent: game locator, case-insensitive file index, providers and codecs, object and avatar catalogs, TS1 hybrid | 5,819 | 39–58 | 0% | 39–58 | Async initialization with progress; no singleton. |
| West Darrington | Oracle harness and replays: 2017 SimAntics on modern .NET, differential tests per primitive, then whole-lot replays with a shared state digest | new | 20–40 | 70% | 6–12 | Phases 1 and 2 done. `fso-oracle run-lot` loads a lot headless against the 2002 beta and prints repeatable state digests (version 0). `fso-oracle run-primitive` runs single 2017 primitives from JSON requests on a fresh lot each, reporting the exit code, registers, and every changed global and object value (protocol version 1, regression-checked by `check_protocol.py`). Phase 3, after Terra Tablante: lot recordings and replays. |
| Queen Margaret's | SimAntics core: VM, context, threads, stack frames, memory scopes, scheduler, translator, entities, lot model | 13,368 | 165–270 | 0% | 165–270 | Wrapping 16-bit arithmetic and ordered iteration are rules from the first line. |
| Rancho Rizzo | Primitives (about 70) | 6,665 | 85–135 | 0% | 85–135 | `VMExpression` first. Each primitive lands with a replay or unit test. |
| Shannopolis | Routing: `VMRoutingFrame`, `VMRectRouter`, obstacles | 1,586 | 20–32 | 0% | 20–32 | Floating point here must be checked for determinism. |
| Terra Tablante | Saves: marshals, version 19 read and write, hollow saves | 1,572 | 20–30 | 0% | 20–30 | Must read saves written by 2017 servers. |
| The Billabong | Lockstep: net commands, ticks, server and client drivers, resync | 3,987 | 50–80 | 0% | 50–80 | Byte-level compatibility with 2017 commands is decision 3. |
| Upper Shankelston | EOD plugin handlers | 5,217 | 65–105 | 0% | 65–105 | Server-side logic only; panels belong to a client. |
| Virginia Islands | Lot utilities: world and TS1 activators, architecture tools, lot rotation, terrain restore | 2,680 | 35–55 | 0% | 35–55 | Needed for houses from XML and surrounding lots. |
| Charvatia | TS1 house and neighborhood chunks: `OBJT`, `OBJM`, `ARRY`, `WALm`, `FLRm`, `CARR`, `FAMI`, `FAMs`, `NBRS`, `NGBH`, `SIMI`, `TATT`, and field-encoded strings | 764 | 5–8 | 0% | 5–8 | Only TS1 hybrid mode reads these; a TSO install contains none (checked 2026-10-15). Deferred by the owner; port it when TS1 hybrid is needed, ideally checked against a TS1 install. `OBJM` is decoded by heuristic search in 2017. |
| | **Total** | **≈ 53,000** | **≈ 580–930** | **≈ 6% ready** | **≈ 536–852** | |

## Upcoming milestones, ranked

| Rank | Next milestone | Closes | Estimate (h) |
|---|---|---|---|
| 1 | One object end to end: object path of Ocean's Edge | alpha row 2 | 30–45 |
| 2 | VM core with `VMExpression` | Queen Margaret's (first pass) | 60–100 |
| 3 | Sprites and images | Hyde Park | 24–35 |
| 4 | Avatars: Vitaboy formats and providers | Nichol's Notch, Ocean's Edge avatar path | 30–45 |

## Critical path

Albertstown → Xanadu → Pixie Point → King Canyons → Ocean's Edge (objects) → Queen Margaret's → Rancho Rizzo → Shannopolis is strictly in order: the VM can't run without
typed behavior chunks, patched IFFs, and a content provider. West Darrington has to land before Queen Margaret's can claim any
fidelity. Hyde Park, Landry Lakes, and Nichol's Notch run beside it and only gate the avatar and rendering consumers. Terra Tablante to Virginia Islands
follow Queen Margaret's. The long poles are Queen Margaret's (VM core) and Rancho Rizzo (primitives). Charvatia (TS1
chunks) can land whenever TS1 hybrid mode is needed; nothing in TSO mode waits on it.

## Decisions for the owner

1. **Where the Vitaboy model formats live.** In TSOFiles (they're file formats) or a fourth package
   `Vitaboy` (as in 2017). Recommended: TSOFiles, to keep three packages.
2. **How to record 2017 replays.** Decided (2026-10-15): an oracle harness. A .NET 10 console tool
   in `NSOClient/Oracle/` compiles the 2017 SimAntics, Files, and Content sources (linked read-only)
   with stubs for rendering and audio, and runs the VM headless (`VM.UseWorld = false`, as the lot
   server does). It serves two kinds of reference results: first, per-primitive differential tests
   (the Swift tests send an operand and variables, the oracle runs the 2017 primitive); later,
   whole-lot replays using FreeSO's own lockstep stream (an initial `VMMarshal` plus `VMNetTickList`
   batches) and a state digest that both sides compute the same way. Recordings are generated from
   `TSO_GAME_DIR` and not committed. AGENTS.md allows `dotnet` for this tool only.
3. **Wire compatibility of lockstep commands.** Byte-for-byte with 2017 (mixed clients possible), or
   a new encoding. Recommended: byte-for-byte; it doubles as a fidelity check.
4. **Editing support.** PIFF encoding and `IffFile` change tracking only matter for an editor. Port
   them now, or defer. Recommended: defer.
5. **Real-file tests.** Decided (2026-10-15): tests read `TSO_GAME_DIR` and are skipped when it isn't set (`RealInstallTests`).
   `TSO_GAME_DIR` and are skipped when it isn't set.

## Risks most likely to push estimates up

- **SimAntics fidelity:** about 70 primitives whose exact behavior, including bugs the game's code
  relies on, must match FreeSO.
- **No replay oracle yet:** without West Darrington, VM correctness can only be judged by reading C#.
- **Determinism in Swift:** randomized hash seeds and trapping integer overflow are easy to trip
  over; one slip causes desyncs or a crashed lot.
- **Real files:** synthetic tests pass, but the original install may hold variants the 2017 code
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
| 2026-10-16 | minor | West Darrington phase 2 done: `fso-oracle run-primitive` reads JSON requests (opcode, operand, registers, globals, object data and attributes), runs the 2017 handler on a freshly loaded lot each time (about a quarter second per request), and reports the exit code, the registers, and every changed value. Exceptions and bad requests come back as responses. Early finding: 2017's Expression divides by zero without failing and gives -1. The 2017 code's console messages now go to standard error, so standard output carries only results. Avatars aren't covered yet; the default lot has none. |
| 2026-10-15 | minor | West Darrington phase 1 done: the oracle compiles the unchanged 2017 SimAntics stack on .NET 10 with four small stubs and runs it headless on Linux. The 2002 beta needed placeholders (three sound groups, six expansion archives), adapted object and catalog tables, and six production-only objects left out of the default lot, all reported. The VM reseeds when a lot loads, so the oracle seeds it again afterwards; three 1,800-tick runs give identical digests. |
| 2026-10-15 | minor | Decision 2 settled: an oracle harness that compiles the 2017 SimAntics sources on modern .NET serves per-primitive differential tests first and whole-lot replays later. West Darrington re-planned in three phases and re-estimated from 15–30 to 20–40 hours (stubs for LotView and HIT). AGENTS.md allows `dotnet` for the oracle only. |
| 2026-10-15 | minor | PIFF is FreeSO's own format, written against TSO's 2003 production files; the owner's install is a 2002 beta. Checked against FreeSO's 36 shipped patches: fixed a port bug (a final removal past the end is allowed when nothing remains, as in 2017), and the patch registry now applies each patch only if it fits, skipping and reporting the rest (of the 27 that target `objiff.far` objects, 17 apply to the beta and 10 are skipped). Estimates unchanged. |
| 2026-10-15 | minor | King Canyons done: PIFF patching (apply only) with the 2017 deletion, swap, and add rules, the patch registry, OTF, `tuning.dat`, the data definition, and INI. All read the real install; `sys/nametohostmap.ini` repeats a section, as 2017 would reject too, but nothing loads it. 125 tests. Estimates unchanged. |
| 2026-10-15 | minor | Pixie Point done for TSO. A real install contains none of the remaining chunk types, which only TS1 hybrid mode reads, so the owner deferred them to a new Charvatia milestone (764 C# lines, 5–8 h). Current focus moves to King Canyons. Estimates unchanged. |
| 2026-10-15 | minor | Pixie Point at 70%: thirteen chunk types (behavior, strings, objects, interactions) plus the field-encoded number reader. A real install parses 51,620 chunks with 0 failures, BHAV branch targets and pie menu indices check out, and five orphaned old `TTAB`s are reported separately. Decision 5 settled. Estimates unchanged. |
| 2026-10-15 | minor | Alpha gate row 1 passes: `tsofiles-check` reads a real TSO install (94 containers, 82,131 entries) with 0 failures. The first run failed on `packingslips.dat`, which repeats file IDs across type IDs; FAR3 lookups now use the full asset ID (identical results for every archive FreeSO loads). Estimates unchanged. |
| 2026-10-15 | minor | Xanadu done: `DBPFArchive` (both header layouts, first-wins IDs) and `InstallScanner` with the `tsofiles-check` command. 55 test cases. The real-install run is the remaining step for alpha gate row 1. Estimates unchanged. |
| 2026-10-15 | minor | Renamed milestones at the owner's request: Charvatia is now Xanadu, Grantley Grove is now Pixie Point, and the replay harness (formerly Pixie Point) is now West Darrington. Estimates unchanged. |
| 2026-10-15 | major | First version: scope, alpha gate (pre-alpha, ≈ 2%), milestones Albertstown to Virginia Islands sized from C# line counts, ranked next steps, owner decisions, risks. Albertstown done; Xanadu at 85% (DBPF missing). |
