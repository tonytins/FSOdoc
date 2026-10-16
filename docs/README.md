# Documentation

This folder documents two things: the FreeSO source code as of August 9, 2017 (the snapshot in
[`TSOClient/`](../TSOClient/)), and NSOClient, the Swift rewrite of its engine-free libraries (in
[`NSOClient/`](../NSOClient/)). It also holds a copy of the community SimAntics reference.

## Where to start

- **To understand the 2017 code:** [fso/README.md](fso/README.md), then
  [fso/architecture.md](fso/architecture.md).
- **To see where NSOClient stands:** the [scorecard](scorecard.md) for what's done and how we know,
  and the [roadmap](roadmap.md) for what comes next.
- **To look up what a SimAntics primitive, scope, or data field means:**
  [simantics/README.md](simantics/README.md).

## Outline

### [roadmap.md](roadmap.md): the NSOClient plan

Scope, the alpha gate (the end-to-end jobs NSOClient must do before alpha), current focus,
milestones (named after The Sims Online's unused cities) with estimates and progress, the ranked
next milestones, the critical path, decisions for the owner, risks, and the revision history.

### [scorecard.md](scorecard.md): NSOClient status with evidence

One row per feature, each `done`, `partial`, or `missing`, with the code or test that proves it:
file formats, content, SimAntics, fidelity to 2017, determinism, reliability, tests and tooling,
and platforms. It also lists the known deliberate differences from 2017 and open bugs. When the
scorecard and the roadmap disagree, the scorecard wins.

### [fso/](fso/README.md): the 2017 FreeSO snapshot

Written from reading the source. Each page says how the code works in 2017 and how to rewrite it
on modern .NET.

| Page | Covers |
| --- | --- |
| [README.md](fso/README.md) | Index, coverage, and conventions |
| [architecture.md](fso/architecture.md) | Layers, project dependencies, runtime flows |
| [modernization.md](fso/modernization.md) | The modern .NET rewrite plan: layout, replacements, phases, risks |
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

### [simantics/](simantics/README.md): the SimAntics Wiki, in Markdown

A copy of the community wiki at simantics.wikidot.com, under its own license (CC BY-SA 3.0; see
[its README](simantics/README.md)). Each page ends with notes where the 2017 code differs.

| Page | Covers |
| --- | --- |
| [introduction.md](simantics/introduction.md) | The model, terminology, Edith, interactions |
| [primitives.md](simantics/primitives.md) | Every TSO primitive, with operand layouts |
| [generic-sims-online-call.md](simantics/generic-sims-online-call.md) | The calls behind primitive 1 |
| [scopes.md](simantics/scopes.md) | Variable scopes and object definition fields |
| [object-data.md](simantics/object-data.md), [person-data.md](simantics/person-data.md), [motive-data.md](simantics/motive-data.md), [global-data.md](simantics/global-data.md) | The values objects, Sims, and the lot carry |
| [body-strings.md](simantics/body-strings.md), [walking-animations.md](simantics/walking-animations.md) | Sim appearance strings and walk animations |

## Elsewhere in the repository

- [`NSOClient/Oracle/README.md`](../NSOClient/Oracle/README.md): `fso-oracle`, which runs the 2017
  SimAntics code to produce reference answers for the Swift tests.
- [`AGENTS.md`](../AGENTS.md): the workspace map and the rules for working in this repository.
