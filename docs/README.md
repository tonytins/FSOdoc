# Documentation

SimsCraft is rebuilding the engine of *The Sims Online* in Swift. This folder documents both sides
of that work:

- **FreeSO**, the open-source C# reimplementation of the game that SimsCraft learns from, as its
  source stood at its beta/update-46 build (August 2017). That copy of the code is in
  [`TSOClient/`](../TSOClient/), and [fso/releases.md](fso/releases.md) places it among FreeSO's updates.
- **NSOClient**, the new Swift code, in [`NSOClient/`](../NSOClient/). It covers the parts of
  FreeSO that don't depend on a game engine (no graphics, sound, user interface, or networking):
  reading the game's files, loading its content, and running its object behavior.

It also holds a copy of the community SimAntics reference, which explains the scripting language
the game's objects are written in.

New here? Read [Terms](#terms) below, then pick a starting point. The rules for changing the code
are in [`AGENTS.md`](../AGENTS.md); they apply to people and AI assistants alike.

## Where to start

- **To understand FreeSO's code:** [fso/README.md](fso/README.md), then
  [fso/architecture.md](fso/architecture.md).
- **To understand how NSOClient's code behaves:** [nso/README.md](nso/README.md).
- **To see where NSOClient stands:** the [scorecard](scorecard.md) for what's done and the evidence
  for it, the [roadmap](roadmap.md) for what comes next, and the [results](results/README.md) for how
  closely NSOClient matches FreeSO.

## Terms

| Term | Meaning |
| --- | --- |
| *The Sims Online* (TSO) | Maxis and EA's online Sims game, released in 2002 and renamed *EA-Land* before it closed in 2008 |
| FreeSO | An open-source C# reimplementation of TSO, built on MonoGame. NSOClient is checked against it |
| NSOClient | SimsCraft's Swift reimplementation of FreeSO's engine-independent libraries (also called NewSO) |
| Install | A copy of TSO's game files on disk (a `TSOClient` folder). The repository holds none; tests that need one read the `TSO_GAME_DIR` environment variable, or use [`NSOClient/MockInstall`](../NSOClient/MockInstall/README.md), a tiny made-up install |
| Production, beta | The two installs the project is tested on: a 2002 production release and a 2002 beta. FreeSO was built against a 2003 release |
| SimAntics | The virtual machine that runs object behavior in The Sims games |
| Routine (`BHAV`), primitive | A routine is a small program an object runs; each of its instructions is either a call to another routine or a primitive, one of the VM's built-in operations |
| IFF, chunk | Maxis's resource file format. An object's IFF holds chunks: its definition (`OBJD`), routines (`BHAV`), strings (`STR#`), sprites, and so on |
| FAR, DBPF | Archive formats that bundle many files, such as all the objects' IFFs |
| PIFF | FreeSO's patch format: a file of changes to apply to one of the game's IFFs |
| GUID | The 32-bit number that identifies an object type |
| Semi-global | A library of routines shared by a family of objects, such as all chairs |
| Lot, tick | A property Sims live on and objects are placed on; one step of the simulation |
| Oracle | `fso-oracle` runs FreeSO's code and `nso-oracle` runs NSOClient's, on the same install; comparing their output is how NSOClient is checked |

- **To look up what a SimAntics primitive, scope, or data field means:**
  [simantics/README.md](simantics/README.md).

## Outline

### [roadmap.md](roadmap.md): the NSOClient plan

Scope, the alpha gate (the end-to-end jobs NSOClient must do before alpha), current focus,
milestones (named after The Sims Online's unused cities) with estimates and progress, the ranked
next milestones, the critical path, decisions for the maintainer, risks, and the revision history.

### [scorecard.md](scorecard.md): NSOClient status with evidence

One row per feature, each `done`, `partial`, or `missing`, with the code or test that proves it:
file formats, content, SimAntics, fidelity to FreeSO, determinism, reliability, tests and tooling,
and platforms. It also lists the known deliberate differences from FreeSO and open bugs. When the
scorecard and the roadmap disagree, the scorecard wins.

### [nso/](nso/README.md): how NSOClient works

How the Swift libraries behave today, with code examples. `fso-oracle` (see
[its README](../NSOClient/FSO.Oracle/README.md)) and SimsScript, an experimental scripting language,
aren't covered.

| Page | Covers |
| --- | --- |
| [README.md](nso/README.md) | The packages, how they depend on each other, and the rules every package follows |
| [files.md](nso/files.md) | TSOFiles: containers, IFF chunks, patches, tables, scanning and comparing installs |
| [content.md](nso/content.md) | TSOContent: finding an install, loading objects, globals, and patches |
| [simantics.md](nso/simantics.md) | SimAntics: the VM, entities, threads, variables, primitives, scheduling |
| [lot.md](nso/lot.md) | The lot model: positions, the tile index, walls, floors, rooms, blueprints |
| [tools.md](nso/tools.md) | `tsofiles-check` and the install differences report |

### [results/](results/README.md): how NSOClient measures up

| Page | Covers |
| --- | --- |
| [nso-review.md](results/nso-review.md) | `fso-oracle` and `nso-oracle` run side by side on each install, compared: matches, mismatches, what NSOClient doesn't support yet, and timings. Written after each phase of the roadmap |
| [install-differences.md](results/install-differences.md) | How the production and beta installs differ: files, archive entries, IFF chunks, and object GUIDs, with no game data. The reference for keeping NSOClient working on the beta |

### [fso/](fso/README.md): FreeSO's code, at update-46

Written from reading the source in `TSOClient/`. Each page explains how one part of FreeSO works.
The "Modern .NET rewrite" sections are from an earlier plan to modernize FreeSO itself, which
SimsCraft dropped in favor of NSOClient; they're kept for reference.

| Page | Covers |
| --- | --- |
| [README.md](fso/README.md) | Index, coverage, and conventions |
| [architecture.md](fso/architecture.md) | Layers, project dependencies, runtime flows |
| [modernization.md](fso/modernization.md) | The earlier modern .NET rewrite plan, kept for reference |
| [common.md](fso/common.md) | FSO.Common: settings, rendering framework, threading, utilities |
| [files.md](fso/files.md) | FSO.Files: FAR, DBPF, IFF and its chunks, PIFF patches, OTF, audio and image formats |
| [content.md](fso/content.md) | FSO.Content: finding the game, providers, objects, TS1 hybrid mode |
| [simantics.md](fso/simantics.md) | FSO.SimAntics: the VM, primitives, routing, lockstep multiplayer, saves |
| [rendering.md](fso/rendering.md) | LotView, Vitaboy, the city view, shaders |
| [audio.md](fso/audio.md) | FSO.HIT: the HIT sound VM and playback |
| [protocol.md](fso/protocol.md) | Server protocol, clients, data and database services |
| [client.md](fso/client.md) | FSO.Client and FSO.UI |
| [server.md](fso/server.md) | FSO.Server: city and lot servers, database, watchdog |
| [tools.md](fso/tools.md) | Volcanic IDE, debug tools, patcher, installer, Charvatia |
| [releases.md](fso/releases.md) | FreeSO's updates by name, from the early tags to the Archive Beta, with the snapshot (beta/update-46) marked |
| [future/](fso/future/README.md) | FreeSO's branches before and after the snapshot: lot serialization, the server rebuild, and 2017–2019 development |

### [simantics/](simantics/README.md): the SimAntics Wiki, in Markdown

A copy of the community wiki at simantics.wikidot.com, under its own license (CC BY-SA 3.0; see
[its README](simantics/README.md)). Each page ends with notes where FreeSO's code differs.

| Page | Covers |
| --- | --- |
| [introduction.md](simantics/introduction.md) | The model, terminology, Edith, interactions |
| [primitives.md](simantics/primitives.md) | Every TSO primitive, with operand layouts |
| [generic-sims-online-call.md](simantics/generic-sims-online-call.md) | The calls behind primitive 1 |
| [scopes.md](simantics/scopes.md) | Variable scopes and object definition fields |
| [object-data.md](simantics/object-data.md), [person-data.md](simantics/person-data.md), [motive-data.md](simantics/motive-data.md), [global-data.md](simantics/global-data.md) | The values objects, Sims, and the lot carry |
| [body-strings.md](simantics/body-strings.md), [walking-animations.md](simantics/walking-animations.md) | Sim appearance strings and walk animations |

## Elsewhere in the repository

- [`NSOClient/FSO.Oracle/README.md`](../NSOClient/FSO.Oracle/README.md): `fso-oracle`, which runs FreeSO's
  SimAntics code to produce reference answers for the Swift tests.
- [`AGENTS.md`](../AGENTS.md): the workspace map and the rules for working in this repository.
