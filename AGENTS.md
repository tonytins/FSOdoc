# AGENTS.md: guide for AI agents and contributors

FSOdoc is a documentation fork of [FreeSO](https://github.com/riperiperi/FreeSO),
a reimplementation of The Sims Online in **C#** on a forked MonoGame. It
freezes FreeSO's source at a single snapshot (August 9, 2017), written for
classic **.NET Framework** (mostly 4.5) and Visual Studio 2017 on Windows.
Write the name as **FSOdoc** in prose. The upstream game is **FreeSO**, and
the original game is **The Sims Online** (TSO).

The project has two goals:

1. Explain the 2017 codebase: what each project does, how the pieces fit,
   and how data flows through the client, the simulation, and the servers.
2. Serve as a guide for rewriting it on modern, cross-platform .NET (SDK-style
   projects, .NET 10 LTS at the time of writing) that runs on Windows,
   Linux, and macOS.

The output of both goals is Markdown under [doc/](./doc/). This is solo work
held to production standards. Read this file first, then
[README.md](./README.md), [FAQ.md](./FAQ.md), and [doc/fso/README.md](./doc/fso/README.md).

## 1. Workspace map

```text
AGENTS.md                    this file
README.md, FAQ.md            project purpose and long-term plans
CONTRIBUTING.md              how to contribute AI-assisted source comments
doc/                         the Markdown documentation
  roadmap.md                 NSOClient milestones, alpha gate, estimates, owner decisions
  scorecard.md               NSOClient status per feature, with evidence (wins over the roadmap)
  fso/                       documentation of the 2017 FreeSO snapshot
    README.md                index, coverage table, and conventions (start here)
    architecture.md          layers, dependency graph, runtime flows
    modernization.md         C# rewrite plan: layout, replacements, phases, decisions, risks
    common.md, files.md, content.md, simantics.md, rendering.md,
    audio.md, protocol.md, client.md, server.md, tools.md   one page per subsystem
.agents/skills/
  dotnet-guidelines/         C# and .NET conventions for the rewrite guidance
  swift-guidelines/          Swift conventions for the NSOClient packages
TSOClient/                   the 2017 FreeSO snapshot (all paths below are relative to it)
  FreeSO.sln                 the main solution (36 projects, including ../Other/libs)
  GlobalSettings.*           shared settings designer file
NSOClient/                   Swift rewrite of the engine-free libraries (independent SwiftPM packages)
  TSOFiles/                  file format readers; no dependencies
  TSOContent/                content system; depends on ../TSOFiles
  SimAntics/                 the VM; depends on ../TSOContent and ../TSOFiles
Charvatia/                   standalone SimAntics VM server (console, .NET Framework)
FSOInstaller/                WinForms installer that fetches the original TSO files
Other/
  libs/                      third-party and helper libraries referenced by the solution
    FSOMonoGame/             git submodule: FreeSO's MonoGame fork (NOT checked out)
    FSOMina.NET/             git submodule: FreeSO's Mina.NET fork (NOT checked out)
    mp3sharp/                MP3 decoder
    TargaImage/              TGA loader (System.Drawing based)
    TargaImagePCL/           TGA loader, portable variant
    ColorQuantizer/          SimplePaletteQuantizer, used by the IDE
    CityDataModel/, LoginDataModel/   old data models, not in FreeSO.sln
  tools/                     legacy standalone tools (CityRenderer, FarExtractor,
                             Iffinator, libfar (C++), Mr. Shipper, PDChat,
                             SimsLib, TSO MeshViewer, XaToWav); not in FreeSO.sln
```

### Projects in TSOClient

Folder names don't always match project or assembly names. Refer to a
project by its folder in paths and by its assembly name in prose.

| Folder | Assembly | Output | Framework | Role |
| --- | --- | --- | --- | --- |
| `tso.client` (`FSO.Client.csproj`) | FreeSO | WinExe | 4.5 | game client: entry point, controllers, regulators, UI screens, networking |
| `tso.client` (`TSOClient.csproj`) | Project Dollhouse Client | WinExe | 3.5 | legacy XNA-era client project; not in the solution, shares the folder |
| `tso.common` | FSO.Common | Library | 4.5 | shared utilities, rendering helpers, audio, serialization, security |
| `tso.files` | FSO.Files | Library | 4.5 | file formats: FAR1/FAR3 archives, IFF, HIT, UTK, XA, and others |
| `tso.content` | FSO.Content | Library | 4.5 | content manager and providers over the original game files; TS1 support |
| `tso.vitaboy.model` | FSO.Vitaboy | Library | 4.5 | Vitaboy character model data: meshes, skeletons, animations |
| `tso.vitaboy.engine` | FSO.Vitaboy.Engine | Library | 4.5 | Vitaboy character rendering |
| `tso.world` | FSO.LotView | Library | 4.5 | lot (house) rendering and world components |
| `tso.simantics` | FSO.SimAntics | Library | 4.5 | SimAntics VM: BHAV interpreter, primitives, entities, multiplayer netplay |
| `tso.sound` | FSO.HIT | Library | 4.5 | HIT audio engine |
| `tso.debug` | FSO.Debug | WinExe | 4.5 | WinForms debug tools for the client |
| `FSO.UI` | FSO.UI | Library | 4.5 | UI framework: controls, UIScript, layout |
| `FSO.IDE` | Volcanic | WinExe | 4.5 | WinForms object and BHAV editor |
| `FSO.Patcher` | update | WinExe | 4.5 | client updater |
| `System.Drawing` | System.Drawing | Library | 4.5 | empty stub assembly to satisfy Xamarin.Android builds |
| `FSO.Server` | server | Exe | 4.5 | server host: auth/API, city, lot, and task servers; `db-init` tool |
| `FSO.Server.Api` | FSO.Server.Api | Library | 4.5 | ASP.NET MVC/Web API site |
| `FSO.Server.Common` | FSO.Server.Common | Library | 4.5 | shared server code, JWT |
| `FSO.Server.Protocol` | FSO.Server.Protocol | Library | 4.5 | wire protocols: Aries, Voltron, Electron, Gluon, CitySelector |
| `FSO.Server.Database` | FSO.Server.Database | Library | 4.5 | MySQL access through Dapper, schema scripts |
| `FSO.Server.DataService` | FSO.Common.DataService | Library | 4.5 | data service model shared by client and server |
| `FSO.Server.Domain` | FSO.Server.Domain | Library | 4.5 | server domain logic |
| `FSO.Server.Clients` | FSO.Server.Clients | Library | 4.5 | client side of the server protocols |
| `FSO.Server.Debug` | FSO.Server.Debug | WinExe | 4.5 | WinForms packet inspector |
| `FSO.Server.Framework` | FSO.Server.Framework | Library | 4.5.2 | near-empty placeholder |
| `FSO.Server.Updater` (`FSO.Server.Watchdog.csproj`) | watchdog | Exe | 4.5 | restarts and updates the server |
| `FSO.Common.Domain` | FSO.Common.Domain | Library | 4.5 | domain logic shared by client and server |
| `FSO.Common.DatabaseService` | FSO.Common.DatabaseService | Library | 4.5 | database service client |
| `FSODroid` | FSODroid | Library | MonoAndroid 6.0 | Xamarin.Android host; not in the solution |
| `FSO.iOS` (`FSOiOS.csproj`) | FSOiOS | Exe | Xamarin.iOS | Xamarin.iOS host; not in the solution |

`Report20160827-0456.diagsession` is a stray Visual Studio diagnostics file.
`tso.client` also holds checked-in native binaries (`sdl2.dll`,
`soft_oal.dll`, `OpenTK.dll`, `NVorbis.dll`).

Key third-party dependencies: MonoGame (forked), OpenTK, SDL2, Mina.NET
(forked), Ninject, NLog, Common.Logging, Newtonsoft.Json, Dapper,
MySql.Data, Nancy, OWIN, ASP.NET MVC/Web API, RestSharp, Portable.JWT,
BouncyCastle, LuaInterface, GOLD Engine, Lidgren.Network.

Build output (`bin/`, `obj/`, `packages/`) is ignored; never commit it.

`Stash/` may exist at the root and is ignored. It's the owner's personal
space for brainstormed material and notes. Read it for context when it
helps, but treat it as drafts rather than decisions, and don't depend on it
from docs.

## 2. Golden rules for the docs process

### The source is the ground truth

- **Read the code before you describe it.** Every claim about behavior
  must come from the source in this repo, not from memory of FreeSO,
  later FreeSO versions, or TSO lore. If you can't confirm something, mark
  it **Unverified** and say what you would need to check.
- **Cite where it lives.** Link the files and types a section describes,
  with relative paths from the doc file (for example
  `../TSOClient/tso.simantics/VM.cs`). Name types and members exactly as
  they appear in the code.
- **Describe the snapshot, not upstream.** FreeSO kept changing after
  August 2017. Don't import later designs, and don't call something a bug
  unless the code shows it.
- **Don't change the snapshot's behavior.** Documentation work doesn't
  edit `TSOClient/`, `Charvatia/`, `FSOInstaller/`, or `Other/`. Adding
  source doc comments is a separate task; do it only when asked, and never
  mix it with code changes.
- **Account for what's missing.** The `FSOMonoGame` and `FSOMina.NET`
  submodules aren't checked out. Describe those libraries from how the
  snapshot uses them, and say so. Note dead code, unused projects, and
  projects outside `FreeSO.sln` as such instead of documenting them as live.
- **Respect the IP.** The game content (FAR, IFF, and other asset files)
  belongs to EA/Maxis and isn't in this repo. Document formats and how the
  code reads them, but never paste or reconstruct game data.

### Separate the two goals

Each doc keeps "how it works" apart from "how to rewrite it":

- **How it works (2017)** describes the code as it is, including its
  Windows-only parts, without judging them.
- **Modern .NET rewrite** gives a concrete plan: target framework, project
  layout, which APIs and packages replace the old ones, and what to check.
  Follow the [.NET guidelines skill](./.agents/skills/dotnet-guidelines/SKILL.md).

### Cross-platform is the bar

The rewrite guidance must run on Windows, Linux, and macOS. For every
subsystem, call out what blocks that and propose a replacement:

- WinForms (FSO.IDE, FSO.Debug, FSO.Server.Debug, FSO.Patcher,
  FSOInstaller): name a cross-platform UI option, and say when a tool is
  better as a CLI or dropped.
- `[DllImport]` and checked-in native binaries: name the cross-platform
  package or the per-OS native asset layout (`runtimes/<rid>/native`).
- `System.Drawing`, `BinaryFormatter`, `System.Web`, OWIN, Nancy, ASP.NET
  MVC/Web API, `app.config`/`ConfigurationManager`, and the registry: give
  the modern equivalent (for example ImageSharp or SkiaSharp, an explicit
  serializer, ASP.NET Core, and `Microsoft.Extensions.Configuration`).
- File paths: case sensitivity, `\` separators, and hard-coded Windows
  install paths.
- Stock MonoGame (DesktopGL) versus the FSOMonoGame fork: list what the
  fork adds that the snapshot depends on.
- Wire and file compatibility: changes that would break the protocol, the
  database schema, or reading the original game files must be called out,
  not slipped in.

### Don't run dotnet

Don't run the `dotnet` command, `msbuild`, `mono`, or `nuget`. The
snapshot doesn't build as-is on Linux, so findings come from reading code,
project files, and `packages.config`. Use `grep`, `find`, `git`, and
ordinary shell tools. Never present rewrite code as compiled or tested.

## 3. Code style

This covers the docs and any C# shown in them.

### Markdown

- One `#` heading per file, matching the doc's purpose. File names are
  lowercase kebab-case (`simantics-vm.md`), except the index,
  `README.md`.
- Write plain, short sentences without em dashes. Explain why, not only
  what. Prefer tables for inventories and short lists for steps.
- Use relative links, so they work on GitHub and locally. Every new doc is
  linked from [doc/fso/README.md](./doc/fso/README.md).
- Use `text` code fences for trees and diagrams, and `csharp`, `xml`,
  `json`, or `sh` for code.
- Use Mermaid only where a diagram explains a flow or dependency better
  than prose.

### C# in the docs

- **Quoting the snapshot:** quote it verbatim and keep it short, with its
  file path. Don't restyle quoted code.
- **Rewrite examples:** follow the
  [.NET guidelines skill](./.agents/skills/dotnet-guidelines/SKILL.md).
  Use SDK-style projects, `net10.0`, nullable reference types, file-scoped
  namespaces, `Directory.Build.props` and central package management, the
  `Microsoft.Extensions.*` stack (hosting, DI, logging, configuration) in
  place of Ninject, NLog, and Common.Logging, and `async`/`await` with
  `CancellationToken` for I/O.
- Keep examples minimal and label them as sketches. Show the shape of the
  replacement, not a full port.
- Prefer the BCL and well-maintained packages. Every package you
  recommend gets its name and a reason. New dependencies are suggestions
  for the owner to approve.

## 4. Before you finish a task

There's no build to run, so checking the docs is the gate.

```sh
# every relative link in doc/ points at something that exists
grep -roP '\]\(\K[^)#]+(?=[)#])' doc --include=*.md | grep -v '://' |
  while IFS=: read -r file link; do
    [ -e "$(dirname "$file")/$link" ] || echo "broken: $file -> $link"
  done

# the snapshot itself is untouched
git status --short -- TSOClient Charvatia FSOInstaller Other
```

- Fix every broken link, and confirm the `git status` check prints nothing.
- Re-read the source behind any claim you changed, and confirm the cited
  paths, types, and members exist.
- Keep [doc/fso/README.md](./doc/fso/README.md) up to date: link new docs, and
  update the coverage list (which projects are documented and which aren't
  yet).
- After NSOClient work, update [doc/scorecard.md](./doc/scorecard.md) (statuses
  with evidence, summary counts, the "As of" line) and [doc/roadmap.md](./doc/roadmap.md)
  (milestone rows, alpha gate, revision history).
- Update this file if the workspace layout or these rules change.
- Leave `README.md`, `FAQ.md`, and `CONTRIBUTING.md` alone unless asked.

## 5. Calling things out

The owner often reviews changes alone, so make review easy:

- List what you documented, what you skipped, and what's still undocumented.
- List every **Unverified** claim and anything you couldn't trace in the
  code, such as behavior that depends on the missing submodules.
- State rewrite recommendations that break compatibility clearly: the
  wire protocol, the database schema, save and lot formats, or reading the
  original TSO files.
- State new dependencies and framework choices, with the alternative you
  weighed, as judgment calls for the owner to decide.
- If you notice a risk in the snapshot, such as a security issue, a
  committed secret, or a licensing question for a third-party library,
  report it. Don't fix it in the source as part of a docs change.
