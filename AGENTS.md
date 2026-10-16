# AGENTS.md: guide for AI agents and contributors

SimsCraft started as a documentation fork of [FreeSO](https://github.com/riperiperi/FreeSO),
a reimplementation of The Sims Online in **C#** on a forked MonoGame. It keeps
FreeSO's source frozen at a single snapshot (August 9, 2017), written for
classic **.NET Framework** (mostly 4.5) and Visual Studio 2017 on Windows, and
builds on it. Write the name as **SimsCraft** in prose. The upstream game is
**FreeSO**, and the original game is **The Sims Online** (TSO).

The project's goals:

1. Explain the 2017 codebase: what each project does, how the pieces fit,
   and how data flows through the client, the simulation, and the servers.
2. Serve as a guide for rewriting it on modern, cross-platform .NET (SDK-style
   projects, .NET 10 LTS at the time of writing) that runs on Windows,
   Linux, and macOS.
3. Rewrite FreeSO's engine-free libraries in **Swift** as independent
   packages under [NSOClient/](./NSOClient/): TSOFiles (file formats),
   TSOContent (the content system), and SimAntics (the VM), compatible with
   FreeSO and the TSO beta (see Library rules, rule 2).
4. Go past that baseline: extend SimAntics (such as the
   [scripting proof of concept](./NSOClient/SimsScript/README.md)) and,
   later, support older games' data, such as The Sims 1.

The first two goals produce Markdown under [docs/fso/](./docs/fso/). The
others produce Swift packages, planned in [docs/roadmap.md](./docs/roadmap.md) and
tracked in [docs/scorecard.md](./docs/scorecard.md). This is solo work held to
production standards. Read this file first, then
[README.md](./README.md) and [docs/fso/README.md](./docs/fso/README.md).

## 1. Workspace map

```text
AGENTS.md                    this file
README.md                    project purpose
docs/                        the Markdown documentation
  README.md                  overview and outline of everything in docs/
  roadmap.md                 NSOClient milestones, alpha gate, estimates, owner decisions
  scorecard.md               NSOClient status per feature, with evidence (wins over the roadmap)
  fso/                       documentation of the 2017 FreeSO snapshot
    README.md                index, coverage table, and conventions (start here)
    architecture.md          layers, dependency graph, runtime flows
    modernization.md         C# rewrite plan: layout, replacements, phases, decisions, risks
    common.md, files.md, content.md, simantics.md, rendering.md,
    audio.md, protocol.md, client.md, server.md, tools.md   one page per subsystem
  simantics/                 SimAntics Wiki pages in Markdown, with notes against 2017 (CC BY-SA 3.0, see its README)
.agents/skills/
  dotnet-guidelines/         C# and .NET conventions for the rewrite guidance
  swift-guidelines/          Swift conventions for the NSOClient packages
TSOClient/                   the 2017 FreeSO snapshot (all paths below are relative to it)
  FreeSO.sln                 the main solution (36 projects, including ../Other/libs)
  GlobalSettings.*           shared settings designer file
NSOClient/                   Swift rewrite of the engine-free libraries (independent SwiftPM packages)
  Oracle/                    .NET tool that runs the 2017 SimAntics sources headless, for reference results
  NSOClient.slnx             solution for the oracle only (pick this one in VS Code)
  TSOFiles/                  file format readers; no dependencies
  TSOFilesCheck/             tsofiles-check, which scans an install; depends on ../TSOFiles and swift-argument-parser
  TSOContent/                content system; depends on ../TSOFiles
  SimAntics/                 the VM; depends on ../TSOContent and ../TSOFiles
  SimsScript/                proof of concept: BHAV text assembly and an LSL-like compiler; depends on ../SimAntics
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

## 2. Golden rules

### REA-assisted inspection

For tasks that inspect a shipped application, executable, or other runtime
artifact, check that the global REA CLI is available and working before
starting manual reverse engineering:

```sh
command -v rea
rea --help
```

If both checks succeed, use REA's relevant command to help inspect the target.
For an application overview, start with `rea analyze <path>` and consult
`rea analyze --help` for its options. Treat its output as inspection evidence
to cross-check against the artifact and source, not as a replacement for
verification. If `rea` is missing or cannot run, continue with the available
local tools and state that REA was unavailable; do not install it as part of
the inspection. Skip REA for ordinary source-repository architecture analysis.

### Never crash (outranks feature work)

The NSOClient libraries read game files nobody controls: original installs,
patched objects, user mods, and lot saves from servers. A truncated archive,
a corrupt chunk, or a hostile save must produce an error the caller can act
on, never a trap. Don't ship a feature by adding a crash path; fix a crash
before building on top of it.

- **Library code never traps.** No force unwraps (`!`), `try!`, `as!`,
  implicitly unwrapped optionals, `fatalError`, `precondition`,
  `preconditionFailure`, or `assert`-based control flow in `Sources/`.
  Throw a typed error (`FAR3Error`, `IFFError`, and so on) and propagate it
  with `try`; use `guard let … else { throw … }`. Unfinished features throw
  rather than trap.
- **No silent fallbacks for bad data.** Invalid input is reported, never
  quietly replaced. The one exception is a tolerance the 2017 code had and
  real files may rely on (such as `ByteReader.readBytes(upTo:)` for .NET's
  short reads): keep it, and say so in the doc comment.
- **File-derived numbers are hostile.** Check every size, offset, and count
  read from a file against the bytes that remain before slicing or
  allocating. Convert with checks, use `addingReportingOverflow` or clamp
  for values that can grow, and check indices with `indices.contains`
  before subscripting.
- **Bound loops and recursion** that data can drive: decompression output,
  nested containers, BHAV execution (the 2017 VM stops a thread after
  500,000 instructions in one tick), call depth, and graph walks.
- **Failures change nothing.** A reader that throws returns nothing partial.
  Build results in locals and return them only when complete.
- **Contain failures.** One bad file or entry must not stop a scan or a
  content load: collect it and report it, as `InstallScanner` does. In
  SimAntics, an error in one entity's thread is contained to that entity,
  as in 2017.
- **Prove it.** Every crash or bad-input fix comes with a small regression
  test that failed before the fix.
- **Checked by hand for now.** Until a lint runs in CI (scorecard TST-5),
  run the search in [section 4](#4-before-you-finish-a-task) before
  finishing.

### Library rules

These apply to everything under [NSOClient/](./NSOClient/).

1. **Engine-free.** No MonoGame, AdaEngine, UI, rendering, audio playback,
   logging, or printing in library targets. Decode to plain values (RGBA
   pixels, PCM samples, typed chunks) and report through errors and
   results. Command-line executables such as `tsofiles-check` may print.
2. **Compatibility is the baseline, not the ceiling.** Every change keeps
   two baselines:
   - **FreeSO.** The 2017 snapshot is the specification for the behavior it
     has. Read the C# before writing the Swift, match it on valid input
     (quirks included) and on TSO's 2003 production files, which FreeSO
     targets, and name the C# type a Swift type ports in its doc comment.
     Differ only to avoid a crash, to reject hostile input, or to fix a
     clear bug, and record each difference in the doc comment and in the
     scorecard's "Known differences from 2017". Check against `fso-oracle`
     where 2017 has an answer.
   - **The TSO beta.** The owner's 2002 beta install must keep working.
     Where its files differ from production, degrade gracefully: skip what
     doesn't fit, report it, and keep going, never fail outright.

   Past the baseline, new behavior is welcome: SimAntics extensions,
   scripting, and support for older games' data. An addition must not
   change behavior on FreeSO's or the beta's data, must be opt-in or
   clearly separate from the ported code, and needs its own tests.
3. **Deterministic.** SimAntics must give the same results on every
   machine for lockstep play: wrap 16-bit arithmetic (`&+`, `&-`, `&*`),
   never iterate a `Dictionary` or `Set` in VM logic (Swift randomizes hash
   seeds per process), process entities in object ID order, take randomness
   only from the VM's seed, never read the clock, and review any floating
   point that feeds simulation state.
4. **Values, not shared state.** Model data as `Sendable` structs and enums
   that are immutable once loaded. Archives are values over memory-mapped
   bytes. No singletons: where 2017 used `Content.Get()` or `HITVM.Get()`,
   pass the dependency in.
5. **Independent packages.** Each package builds and tests on its own.
   Dependencies point one way through local paths (TSOFiles, then
   TSOContent, then SimAntics, then SimsScript). Foundation is allowed; don't declare
   `platforms:`. The only other approved dependency is swift-argument-parser,
   for command-line tools such as `tsofiles-check`. Any other needs the
   owner's approval.
6. **No EA data in the repository.** Tests build synthetic files in code
   (see `Tests/TSOFilesTests/Support/ByteWriter.swift`). Checks against real
   files read `TSO_GAME_DIR` and skip when it isn't set.
7. **Tests are the gate.** Swift Testing (`import Testing`, `@Test`), never
   XCTest. Cover every kept quirk and every error path, keep tests
   deterministic, and use `@Test(arguments:)` for shared checks.
8. **Public API is documented, and breaking changes are said out loud.**
   Every public declaration gets a documentation comment. Removing or
   renaming public API, or adding a case to a public enum such as an error,
   breaks callers in the other packages: update them and call it out.
9. **Follow the [Swift guidelines](./.agents/skills/swift-guidelines/SKILL.md)**,
   and match the surrounding code when they disagree.
10. **Measure before optimizing.** Time a release build against a real
    install (`tsofiles-check` prints counts; `time` it) before and after.

### Documenting the 2017 snapshot

#### The source is the ground truth

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

#### Separate the two goals

Each doc keeps "how it works" apart from "how to rewrite it":

- **How it works (2017)** describes the code as it is, including its
  Windows-only parts, without judging them.
- **Modern .NET rewrite** gives a concrete plan: target framework, project
  layout, which APIs and packages replace the old ones, and what to check.
  Follow the [.NET guidelines skill](./.agents/skills/dotnet-guidelines/SKILL.md).

#### Cross-platform is the bar

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

#### Don't run dotnet

Don't run the `dotnet` command, `msbuild`, `mono`, or `nuget`. The
snapshot doesn't build as-is on Linux, so findings come from reading code,
project files, and `packages.config`. Use `grep`, `find`, `git`, and
ordinary shell tools. Never present rewrite code as compiled or tested.

**One exception: the SimAntics oracle.** `NSOClient/Oracle/` is a small
.NET console tool that compiles the 2017 SimAntics, Files, and Content
sources (linked read-only, never copied or edited) on modern .NET, with
stubs for the rendering and audio types they touch. It exists only to
produce reference results for the Swift port (roadmap decision 2). `dotnet`
may be run for that project and nothing else, either directly or through
`NSOClient/NSOClient.slnx`, which contains only the oracle. Don't add other
projects to that solution. The exception doesn't cover
building or running the 2017 solution itself, and the oracle must never
change a file under `TSOClient/`.

## 3. Code style

This covers the docs and any C# shown in them.

### Markdown

- One `#` heading per file, matching the doc's purpose. File names are
  lowercase kebab-case (`simantics-vm.md`), except the index,
  `README.md`.
- Write plain, short sentences without em dashes. Explain why, not only
  what. Prefer tables for inventories and short lists for steps.
- Use relative links, so they work on GitHub and locally. Every new doc is
  linked from [docs/fso/README.md](./docs/fso/README.md).
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

### NSOClient work

```sh
for package in TSOFiles TSOFilesCheck TSOContent SimAntics SimsScript; do  # every package, even ones you didn't touch
    swift build --package-path "NSOClient/$package" &&
    swift test --package-path "NSOClient/$package"
done
grep -rnE 'try!|as!|fatalError|precondition|preconditionFailure' NSOClient/*/Sources  # must print nothing
swift run --package-path NSOClient/TSOFilesCheck -c release tsofiles-check  # if you touched a reader; needs TSO_GAME_DIR
dotnet build NSOClient/Oracle -c Release                               # if you touched the oracle
python3 -I NSOClient/Oracle/check_protocol.py                          # if you touched the oracle; needs TSO_GAME_DIR
NSOClient/scripts/oracle-fixtures.sh /tmp/oracle                       # if you touched content, SimAntics, or the oracle; needs TSO_GAME_DIR
TSO_ORACLE_DIR=/tmp/oracle swift test --package-path NSOClient/TSOContent  # then compare with 2017
TSO_ORACLE_DIR=/tmp/oracle swift test --package-path NSOClient/SimAntics
git status --short -- TSOClient                                        # must print nothing
```

- Every package must build with no new warnings and pass all tests.
- Look over your diff for force unwraps (`!`) by eye; the search above can't
  tell them apart from `!=` and `!condition`.
- If you touched a reader and `TSO_GAME_DIR` is set, the scan must still
  report 0 failures. Without an install, say that you couldn't run it.
- In SimAntics, check new code against the determinism rule: no
  `Dictionary` or `Set` iteration, wrapping arithmetic only.

Then bring the docs up to date in the same change:

- [docs/scorecard.md](./docs/scorecard.md): flip the rows you moved, with
  their new evidence; update the summary counts and the "As of" line; add
  any new difference from 2017 under "Known differences".
- [docs/roadmap.md](./docs/roadmap.md): update the milestone row's done
  percentage and remaining estimate, the alpha gate if a row changed, the
  current focus, and the status line, and add a revision-history row.
- [docs/fso/](./docs/fso/README.md) only if the port showed that a page
  describes the 2017 code wrongly.

### Documentation work

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
- Keep [docs/fso/README.md](./docs/fso/README.md) up to date: link new docs,
  and update the coverage list (which projects are documented and which
  aren't yet).

### Always

- Update this file if the workspace layout or these rules change.
- Leave `README.md` alone unless asked.

Describe only what works today. Sessions can end abruptly, so keep every
package building and its tests green at every step; the roadmap's revision
history and the git log are how the next session picks up.

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
- For NSOClient, list every deliberate difference from the 2017 behavior
  and every addition past the compatibility baseline, and say which checks
  ran: the tests, the real-install scan, and the `fso-oracle` comparisons.
- If you notice a risk in the snapshot, such as a security issue, a
  committed secret, or a licensing question for a third-party library,
  report it. Don't fix it in the source as part of a docs change.
