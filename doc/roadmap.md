# NSOClient roadmap: milestones and what's next

> **Last reviewed:** 2026-10-15 · **Last updated:** 2026-10-15 · **Change:** major (first version: milestones Albertstown to Virginia Islands, alpha gate, estimates from C# line counts) · **Target:** behavior parity with FreeSO's engine-free libraries at the 2017-08-09 snapshot (FSO.Files, FSO.Content, FSO.SimAntics)

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
| Open every FAR1, FAR3, and IFF file in a TSO install | no | Container readers exist and pass synthetic tests (scorecard FMT-1 to FMT-5); no run against a real install yet | 5–10 (Charvatia remainder plus a corpus scan tool) |
| Load one object with its behavior, strings, tuning, and sprites | no | IFF chunk records only; no typed chunks, no content provider | 90–130 (Grantley Grove, Hyde Park, King Canyons, Ocean's Edge in part) |
| Load one avatar: mesh, skeleton, animation, outfit, appearance | no | Not started | 50–75 (Nichol's Notch, Ocean's Edge in part) |
| Run a lot headless for one in-game day without a SimAntics error | no | `TickRate` only | 300–480 (Queen Margaret's to Shannopolis, Virginia Islands in part) |
| Save and reload a lot (VMMarshal version 19) | no | Not started | 20–30 (Terra Tablante) |
| Replay a recorded 2017 session to an identical state hash | no | No recording harness (decision 2) | 15–30 (Pixie Point) plus everything above |

**Result: pre-alpha.** Ready for real work: ≈ 2%.

## Current focus

In order:

1. **Finish Charvatia:** DBPF, then a `tsofiles-check` command that opens every archive and IFF under a
   TSO install and reports failures (scorecard FID-1). It's the first contact with real files.
2. **Grantley Grove, behavior first:** `BHAV`, `BCON`, `TRCN`, `TPRP`, `STR#`/`CTSS`, `OBJD`, `OBJf`, `TTAB`/`TTAs`,
   `SLOT`, `GLOB`. SimAntics needs these before anything else.
3. **Decide how to record 2017 replays** (decision 2). Every SimAntics milestone depends on it for
   evidence.
4. **King Canyons, then the object path of Ocean's Edge:** PIFF patching, OTF, then `WorldObjectProvider` and semi-globals, so
   one object loads end to end.
5. **Queen Margaret's core:** `VM`, `VMContext`, `VMThread`, `VMMemory`, the scheduler, and the BHAV translator,
   with `VMExpression` as the first primitive.

## Milestones

Milestones are named after The Sims Online's unused cities, the beta-only cities that never opened
for play ([list](https://www.tsomania.net/cities/lost.php)), in alphabetical order, so the order
of the names is the planned order. West Darrington, Xanadu, Yatesport, and Zavadaville are left for
later milestones. The Charvatia milestone is unrelated to the `Charvatia/` folder, which holds a
2017 VM server tool.

"Plan size" comes from the non-blank C# lines each milestone ports, at an assumed 100–150 lines per
hour for format code and 50–80 for VM code, tests included. Those rates are a first guess, not a
measurement; recalibrate them when Grantley Grove lands. "Done" is the share of the milestone's acceptance
criteria met, not lines written.

| Milestone | Scope | C# lines | Plan size (h) | Done | Remaining (h, 2026-10-15) | Notes |
|---|---|---:|---|---|---|---|
| Albertstown | Scaffolding: three packages, Swift 6 mode, Swift Testing | 0 | 1–2 | 100% | 0 | Path dependencies TSOContent → TSOFiles, SimAntics → TSOContent, TSOFiles. No `platforms:` (owner decision). |
| Charvatia | Binary reading and containers: ByteReader, FAR1, FAR3, RefPack, IFF container, DBPF | 1,859 | 12–19 | 85% | 2–4 | Done: everything but DBPF, 38 test cases. Kept quirks: RefPack short input and growth, 0xFD to 0xFF, FAR3 duplicate IDs, IFF trailing byte. Missing: DBPF. |
| Grantley Grove | Typed IFF chunks (behavior, strings, objects, interactions, slots, neighborhood) | 2,806 | 19–28 | 0% | 19–28 | Behavior chunks first. Field-encoded chunks (`IffFieldEncode`) for TS1 data last. |
| Hyde Park | Sprites and images: `SPR#`, `SPR2`, `PALT`, `DGRP`, `BMP_`, `THMB`, BMP, TGA, PNG to RGBA | 3,543 | 24–35 | 0% | 24–35 | Decode to plain RGBA plus SPR2 depth, no textures. Includes TargaImagePCL's TGA reader. |
| King Canyons | Patching and tables: PIFF apply and encode, OTF, `tuning.dat`, `datadefinition.dat`, INI | 802 | 5–8 | 0% | 5–8 | PIFF encoding only if the editor is planned (decision 4). |
| Landry Lakes | Audio formats: UTK, XA, HIT, HOT, EVT, HSM, FSC, TLO, hitlists | 1,651 | 11–17 | 0% | 11–17 | Decoding only; playback is a client concern. |
| Nichol's Notch | Vitaboy model formats: mesh, skeleton, animation, appearance, binding, outfit, hand groups, BCF/CFP | 1,511 | 10–15 | 0% | 10–15 | Package placement is decision 1. |
| Ocean's Edge | TSOContent: game locator, case-insensitive file index, providers and codecs, object and avatar catalogs, TS1 hybrid | 5,819 | 39–58 | 0% | 39–58 | Async initialization with progress; no singleton. |
| Pixie Point | Replay harness: record VM sessions in the 2017 code, read them in Swift | new | 15–30 | 0% | 15–30 | Needs the 2017 build to run (decision 2). |
| Queen Margaret's | SimAntics core: VM, context, threads, stack frames, memory scopes, scheduler, translator, entities, lot model | 13,368 | 165–270 | 0% | 165–270 | Wrapping 16-bit arithmetic and ordered iteration are rules from the first line. |
| Rancho Rizzo | Primitives (about 70) | 6,665 | 85–135 | 0% | 85–135 | `VMExpression` first. Each primitive lands with a replay or unit test. |
| Shannopolis | Routing: `VMRoutingFrame`, `VMRectRouter`, obstacles | 1,586 | 20–32 | 0% | 20–32 | Floating point here must be checked for determinism. |
| Terra Tablante | Saves: marshals, version 19 read and write, hollow saves | 1,572 | 20–30 | 0% | 20–30 | Must read saves written by 2017 servers. |
| The Billabong | Lockstep: net commands, ticks, server and client drivers, resync | 3,987 | 50–80 | 0% | 50–80 | Byte-level compatibility with 2017 commands is decision 3. |
| Upper Shankelston | EOD plugin handlers | 5,217 | 65–105 | 0% | 65–105 | Server-side logic only; panels belong to a client. |
| Virginia Islands | Lot utilities: world and TS1 activators, architecture tools, lot rotation, terrain restore | 2,680 | 35–55 | 0% | 35–55 | Needed for houses from XML and surrounding lots. |
| | **Total** | **≈ 53,000** | **≈ 575–920** | **≈ 2% ready** | **≈ 565–900** | |

## Upcoming milestones, ranked

| Rank | Next milestone | Closes | Estimate (h) |
|---|---|---|---|
| 0 | DBPF and the install scan tool | Charvatia, FID-1 | 5–10 |
| 1 | Behavior and string chunks | Grantley Grove (first half) | 10–15 |
| 2 | Replay harness | Pixie Point, decision 2 | 15–30 |
| 3 | One object end to end: rest of Grantley Grove, King Canyons, object path of Ocean's Edge | alpha row 2 | 40–60 |
| 4 | VM core with `VMExpression` | Queen Margaret's (first pass) | 60–100 |
| 5 | Sprites and images | Hyde Park | 24–35 |
| 6 | Avatars: Vitaboy formats and providers | Nichol's Notch, Ocean's Edge avatar path | 30–45 |

## Critical path

Albertstown → Charvatia → Grantley Grove → King Canyons → Ocean's Edge (objects) → Queen Margaret's → Rancho Rizzo → Shannopolis is strictly in order: the VM can't run without
typed behavior chunks, patched IFFs, and a content provider. Pixie Point has to land before Queen Margaret's can claim any
fidelity. Hyde Park, Landry Lakes, and Nichol's Notch run beside it and only gate the avatar and rendering consumers. Terra Tablante to Virginia Islands
follow Queen Margaret's. The long poles are Queen Margaret's (VM core) and Rancho Rizzo (primitives).

## Decisions for the owner

1. **Where the Vitaboy model formats live.** In TSOFiles (they're file formats) or a fourth package
   `Vitaboy` (as in 2017). Recommended: TSOFiles, to keep three packages.
2. **How to record 2017 replays.** The 2017 code needs .NET Framework (Windows) or Mono, and the
   docs rules forbid running `dotnet` here. Options: a small recording hook added to a local 2017
   build on Windows, or recordings made by hand once and committed as fixtures. Recommended: a
   minimal hook on a separate branch, so the snapshot itself stays untouched.
3. **Wire compatibility of lockstep commands.** Byte-for-byte with 2017 (mixed clients possible), or
   a new encoding. Recommended: byte-for-byte; it doubles as a fidelity check.
4. **Editing support.** PIFF encoding and `IffFile` change tracking only matter for an editor. Port
   them now, or defer. Recommended: defer.
5. **Real-file tests.** The game files can't be committed. Recommended: tests that read
   `TSO_GAME_DIR` and are skipped when it isn't set.

## Risks most likely to push estimates up

- **SimAntics fidelity:** about 70 primitives whose exact behavior, including bugs the game's code
  relies on, must match FreeSO.
- **No replay oracle yet:** without Pixie Point, VM correctness can only be judged by reading C#.
- **Determinism in Swift:** randomized hash seeds and trapping integer overflow are easy to trip
  over; one slip causes desyncs or a crashed lot.
- **Real files:** synthetic tests pass, but the original install may hold variants the 2017 code
  only handled by accident.
- **Floating point in routing and animation** may need fixed-point rewrites to stay deterministic
  across x86_64 and ARM64.
- **Foundation `Data` performance** on large archives under swift-corelibs-foundation is
  unmeasured.
- **The estimate itself:** the hourly rates are guesses until Grantley Grove gives a measured rate.

## Revision history

| Date | Change | Summary |
|---|---|---|
| 2026-10-15 | major | First version: scope, alpha gate (pre-alpha, ≈ 2%), milestones Albertstown to Virginia Islands sized from C# line counts, ranked next steps, owner decisions, risks. Albertstown done; Charvatia at 85% (DBPF missing). |
