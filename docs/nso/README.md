# NSOClient

NSOClient is a Swift reimplementation of FreeSO's engine-free libraries: the file formats, the
content system, and the SimAntics virtual machine. It aims to get the same results as FreeSO's
2017 snapshot (in [`TSOClient/`](../../TSOClient/)) without copying its code, and to keep the
owner's 2002 TSO beta working. This folder describes how the code behaves today. For what is
finished and how that's proven, see the [scorecard](../scorecard.md); for what comes next, the
[roadmap](../roadmap.md).

These pages cover the four libraries and two tools: the checker and `nso-oracle`. FreeSO's own
oracle (`fso-oracle`, which runs FreeSO's code to produce reference answers) and SimsScript (the
scripting proof of concept) are left out.

## The packages

Each package is an independent Swift package under [`NSOClient/`](../../NSOClient/). Dependencies
point one way:

```text
TSOFiles  ──▶  TSOContent  ──▶  SimAntics
    │
    └──────▶  TSOFilesCheck (tsofiles-check)
```

| Package | What it does | Page |
| --- | --- | --- |
| TSOFiles | Reads the game's containers (FAR1, FAR3, DBPF, IFF), IFF chunks, tables, and PIFF patches | [files.md](files.md) |
| TSOContent | Finds an install and loads objects, globals, and patches from it | [content.md](content.md) |
| SimAntics | Runs object behavior: the VM, entities, threads, primitives, and variables | [simantics.md](simantics.md) |
| SimAntics (lot model) | Positions, the tile index, walls, floors, rooms, and blueprints | [lot.md](lot.md) |
| TSOFilesCheck | `tsofiles-check`, which opens everything in one or two installs and compares them | [tools.md](tools.md) |
| NSOOracle | `nso-oracle`, which answers `fso-oracle`'s questions with NSOClient and compares the two | [tools.md](tools.md#nso-oracle) |

## How the code behaves

A few rules hold everywhere. Knowing them makes each package easier to follow.

- **Same results as FreeSO, not the same code.** Doc comments name FreeSO's type each Swift type
  corresponds to (for example, `Entity` ports `VMEntity`). Where results deliberately differ,
  the comment says so, and the scorecard lists the difference under "Known differences from FreeSO".
- **Errors are values.** Readers throw typed errors (`FAR1Error`, `IFFChunkError`,
  `ContentError`, `SimAnticsError`) instead of crashing. Where FreeSO would read past the end of an
  array, the port throws. Nothing in the libraries uses `try!`, `as!`, or `fatalError`.
- **Values, not singletons.** Archives and chunks are immutable `Sendable` values, often over
  memory-mapped bytes. FreeSO reaches content through a global `Content.Get()`; here a
  `GameContent` is created and passed in, so tests and tools can load several installs side by side.
- **Degrade gracefully on the beta.** Where the 2002 beta's files differ from the 2003 production
  files FreeSO expects, the port skips what doesn't fit, reports it, and keeps going. For example,
  a PIFF patch that doesn't fit an object is skipped, not fatal. [`install-differences.md`](../results/install-differences.md)
  records how the owner's two installs differ.
- **Deterministic simulation.** SimAntics uses wrapping 16-bit arithmetic, never iterates a
  `Dictionary` or `Set` where order matters, and keeps entities in object ID order. Two VMs given
  the same lot and seed stay in step, which lockstep multiplayer needs.

## Trying it

Every package builds and tests on its own:

```sh
swift test --package-path NSOClient/SimAntics
```

Tests that need the game read `TSO_GAME_DIR` (and `TSO_ORACLE_DIR` for the comparisons with FreeSO) and
are skipped without it. The snippets on these pages use the public API. Where a snippet needs an
install, it assumes `TSO_GAME_DIR` points at one.
