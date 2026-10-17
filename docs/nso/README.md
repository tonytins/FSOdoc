# NSOClient

NSOClient is a Swift reimplementation of the parts of FreeSO that don't depend on a game engine
(no graphics, sound, user interface, or networking): the file formats, the content system, and the
SimAntics virtual machine that runs object behavior. It aims to get the same results as FreeSO, as
its code stood at beta/update-46, in August 2017 (in [`TSOClient/`](../../TSOClient/)), without copying that code. It also
keeps working on a 2002 beta of the game, whose files differ from the release FreeSO expects.

This folder describes how the code behaves today. For what's finished and the evidence for it, see
the [scorecard](../scorecard.md); for what comes next, the [roadmap](../roadmap.md). Unfamiliar
terms are explained in the [docs index](../README.md#terms).

These pages cover the four libraries and two tools: the file checker and `nso-oracle`. Two things
are left out: `fso-oracle`, which runs FreeSO's code to produce the answers NSOClient is checked
against (see [its README](../../NSOClient/FSO.Oracle/README.md)), and SimsScript, an experimental
scripting language.

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
  array, NSOClient throws. Nothing in the libraries uses `try!`, `as!`, or `fatalError`.
- **Values, not singletons.** Archives and chunks are immutable `Sendable` values, often over
  memory-mapped bytes. FreeSO reaches content through a global `Content.Get()`; here a
  `GameContent` is created and passed in, so tests and tools can load several installs side by side.
- **Degrade gracefully on the beta.** Where the 2002 beta's files differ from the 2003 production
  files FreeSO expects, NSOClient skips what doesn't fit, reports it, and keeps going. For example,
  a PIFF patch that doesn't fit an object is skipped, not fatal. [`install-differences.md`](../results/install-differences.md)
  records how the production and beta installs differ.
- **Deterministic simulation.** SimAntics uses wrapping 16-bit arithmetic, never iterates a
  `Dictionary` or `Set` where order matters, and keeps entities in object ID order. Two VMs given
  the same lot and seed stay in step, which lockstep multiplayer needs.

## Trying it

Every package builds and tests on its own:

```sh
swift test --package-path NSOClient/SimAntics
```

You need Swift 6 and, for the comparisons with FreeSO, the .NET 10 SDK. You don't need the game:
without it, the tests use [`NSOClient/MockInstall`](../../NSOClient/MockInstall/README.md), a tiny
made-up install, and the tests that need the real game are skipped. To run those too, set these
environment variables:

| Variable | Points at |
| --- | --- |
| `TSO_GAME_DIR` | An install's `TSOClient` folder, normally the production release |
| `TSO_BETA_DIR` | The 2002 beta's `TSOClient` folder, for the tools that compare the two |
| `TSO_ORACLE_DIR` | A folder of FreeSO's answers, written by `NSOClient/scripts/oracle-fixtures.sh` (or `oracle-review.sh`), for the tests that compare NSOClient with FreeSO |

```sh
NSOClient/scripts/oracle-review.sh --mock /tmp/review     # both oracles on the mock install, as CI runs them
```

The snippets on these pages use the public API. Where a snippet needs an install, it assumes
`TSO_GAME_DIR` points at one.

## Compatibility

NSOClient matches FreeSO as of beta/update-46 (August 2017), the snapshot in
[`TSOClient/`](../../TSOClient/); [FreeSO's releases](../fso/releases.md) list what came before and
after it. Nothing newer is a target. In particular, FreeSO is rebuilding its server and client for
the self-hosting FreeSO Archive, and says modifications to the current software may need to be
refactored to work with them ([freeso.org/download](https://freeso.org/download/)). NewSO doesn't
follow that rework, so expect the Archive's server and client to be incompatible with NewSO, and
with content made for FreeSO before its server shut down in December 2024.
