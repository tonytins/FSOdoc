# FSOdoc documentation

These pages explain the FreeSO source code as of August 9, 2017 (the
snapshot in [`TSOClient/`](../../TSOClient/)), and how to rewrite it on
modern, cross-platform .NET. Each page has two parts: **How it works
(2017)** describes the code as it is, and **Modern .NET rewrite** says
what to change.

Everything here comes from reading the source. Nothing was built or run.
Claims that couldn't be confirmed in the code are marked **Unverified**.

## Start here

1. [Architecture overview](./architecture.md): layers, project
   dependencies, runtime flows, and cross-cutting patterns.
2. [Modernization guide](./modernization.md): target layout, dependency
   replacements, cross-platform blockers, phased plan, decisions, and
   risks.

## Subsystems

| Page | Covers |
| --- | --- |
| [common.md](./common.md) | FSO.Common: settings, rendering framework, threading, caching, wire serialization, utilities |
| [files.md](./files.md) | FSO.Files: FAR1, FAR3, DBPF, IFF and its chunks, PIFF patches, OTF, HIT, UTK, XA, images |
| [content.md](./content.md) | FSO.Content: finding the game, providers and codecs, objects, TS1 hybrid mode |
| [simantics.md](./simantics.md) | FSO.SimAntics: the VM, primitives, routing, lockstep multiplayer, saves, EODs |
| [rendering.md](./rendering.md) | FSO.LotView, FSO.Vitaboy, FSO.Vitaboy.Engine, the city view, shaders and the content pipeline |
| [audio.md](./audio.md) | FSO.HIT: the HIT sound VM and playback |
| [protocol.md](./protocol.md) | FSO.Server.Protocol, FSO.Server.Clients, the data service, the database service, FSO.Common.Domain |
| [client.md](./client.md) | FSO.Client and FSO.UI: startup, screens and controllers, regulators, UIScript, mobile hosts |
| [server.md](./server.md) | FSO.Server and its libraries: services, city and lot servers, database, watchdog |
| [tools.md](./tools.md) | Volcanic IDE, debug tools, patcher, FSOInstaller, Charvatia, `Other/` |

## Coverage

Every project in the repository is covered by at least an overview. Depth
varies:

| Project | Page | Depth |
| --- | --- | --- |
| FSO.Common (`tso.common`) | [common.md](./common.md) | Overview of every area |
| FSO.Files (`tso.files`) | [files.md](./files.md) | Every format listed; chunk internals not described |
| FSO.Content (`tso.content`) | [content.md](./content.md) | Full |
| FSO.Vitaboy, FSO.Vitaboy.Engine | [rendering.md](./rendering.md) | Overview |
| FSO.LotView (`tso.world`) | [rendering.md](./rendering.md) | Overview; wall, roof, and lighting algorithms not described |
| FSO.HIT (`tso.sound`) | [audio.md](./audio.md) | Full; individual opcodes not described |
| FSO.SimAntics (`tso.simantics`) | [simantics.md](./simantics.md) | Engine and networking in depth; individual primitives, routing details, and EOD handlers not described |
| FSO.UI | [client.md](./client.md) | Overview |
| FSO.Client (`tso.client`) | [client.md](./client.md) | Overview; individual panels not described |
| FSO.Server.Protocol, FSO.Server.Clients | [protocol.md](./protocol.md) | Framing and flows; individual packets not described |
| FSO.Common.DataService, FSO.Common.DatabaseService, FSO.Common.Domain | [protocol.md](./protocol.md) | Overview |
| FSO.Server, FSO.Server.Database, FSO.Server.Common, FSO.Server.Domain, FSO.Server.Api, FSO.Server.Updater | [server.md](./server.md) | Overview; individual handlers and tasks not described |
| FSO.IDE, FSO.Debug, FSO.Server.Debug, FSO.Patcher | [tools.md](./tools.md) | Overview |
| FSODroid, FSO.iOS, System.Drawing stub | [client.md](./client.md#mobile-hosts) | Brief |
| FSO.Server.Framework | [server.md](./server.md) | Brief (placeholder project) |
| `TSOClient.csproj` (legacy) | [client.md](./client.md#dead-files) | Brief |
| Charvatia, FSOInstaller, `Other/libs`, `Other/tools` | [tools.md](./tools.md) | Brief |

Not covered: the internals of the `FSOMonoGame` and `FSOMina.NET`
forks, because the submodules aren't checked out in this repository.

## Conventions

- Links into the source are relative, such as
  `../TSOClient/tso.simantics/VM.cs`.
- Types and members are named exactly as in the code.
- Code samples under "Modern .NET rewrite" are sketches. They follow the
  [.NET guidelines skill](../../.agents/skills/dotnet-guidelines/SKILL.md)
  and have not been compiled.
- The rules for writing these pages are in [AGENTS.md](../../AGENTS.md).
