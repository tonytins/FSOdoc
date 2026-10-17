# Modernization guide

> **Status: shelved.** SimsCraft chose to reimplement FreeSO's libraries in Swift (NSOClient)
> instead of modernizing FreeSO itself. This plan is kept for its survey of FreeSO's dependencies
> and platform blockers, which still applies to the code in `TSOClient/`. Nothing in it is being
> worked on.

This guide plans a rewrite of the FreeSO snapshot (update-46) onto modern,
cross-platform .NET. It collects the "Modern .NET rewrite" sections of
the other pages into one plan. It follows the
[.NET guidelines skill](../../.agents/skills/dotnet-guidelines/SKILL.md).

Nothing here has been built. Every code and project sample is a sketch.

## Goals

- Runs on **Windows, Linux, and macOS**, on x64 and ARM64, from one
  source tree and one build command.
- **SDK-style projects** on **.NET 10** (the current LTS), with nullable
  reference types and central package management.
- No Windows-only dependency in the game client, the servers, or the
  libraries. Windows-only tools are allowed only as optional extras.
- **Tests** for the parts that can be tested without the game files:
  formats (with synthetic data), protocol, data service, and SimAntics
  replay.
- Behavior stays the same unless a change is recorded as a decision (see
  [Decisions for the maintainer](#decisions-for-the-maintainer)).

Not goals: new gameplay, a new renderer design, or new server features.
Those come after the port.

## Target solution layout

```text
FreeSO.slnx
Directory.Build.props            shared settings: net10.0, nullable, analyzers, warnings as errors
Directory.Packages.props         central package versions
src/
  FSO.Common/                    BCL-only utilities, enums, security
  FSO.Common.Serialization/      cTSO wire serializers
  FSO.Files/                     file formats, no graphics
  FSO.Vitaboy/                   avatar model data, no graphics
  FSO.Content/                   content manager and providers, no graphics
  FSO.SimAntics/                 VM, no graphics or audio (presentation interfaces)
  FSO.HIT/                       HIT interpreter, audio output interface
  FSO.Protocol/                  Aries, Voltron, Electron, Gluon packets and codec (Pipelines)
  FSO.DataService/               data service and models (source-generated serializers)
  FSO.Domain/                    shared domain logic
  FSO.Rendering/                 MonoGame: framework, LotView, Vitaboy engine, city
  FSO.Audio.MonoGame/            HIT output on MonoGame SoundEffect
  FSO.UI/                        UI framework and UIScript
  FSO.Client/                    the game executable
  FSO.Server.Database/           Dapper + MySqlConnector
  FSO.Server/                    Generic Host: API, city, lot, tasks
tests/
  FSO.Files.Tests/
  FSO.Protocol.Tests/
  FSO.DataService.Tests/
  FSO.SimAntics.Tests/           includes replay tests
  FSO.HIT.Tests/
  FSO.Server.Tests/
tools/
  FSO.Tools.Cli/                 FAR/IFF extraction, packet decoding, db migrations
```

The main structural change is direction: graphics and audio move to the
top of the graph. Today MonoGame sits under FSO.Common and reaches almost
every project (see [architecture.md](./architecture.md#project-dependencies)).
In the new layout the server references nothing graphical.

### Project mapping

| FreeSO project | New home |
| --- | --- |
| `tso.common` (FSO.Common) | Split into `FSO.Common`, `FSO.Common.Serialization`, and `FSO.Rendering` |
| `tso.files` (FSO.Files) | `FSO.Files` |
| `tso.vitaboy.model` (FSO.Vitaboy) | `FSO.Vitaboy` (GPU buffers move to `FSO.Rendering`) |
| `tso.content` (FSO.Content) | `FSO.Content` (texture upload moves to `FSO.Rendering`) |
| `tso.vitaboy.engine`, `tso.world` | `FSO.Rendering` |
| `tso.simantics` | `FSO.SimAntics` |
| `tso.sound` (FSO.HIT) | `FSO.HIT` plus `FSO.Audio.MonoGame` |
| `FSO.UI` | `FSO.UI` |
| `tso.client` (FSO.Client.csproj) | `FSO.Client` |
| `FSO.Server.Protocol`, `FSO.Server.Clients` | `FSO.Protocol` |
| `FSO.Server.DataService`, `FSO.Common.DatabaseService` | `FSO.DataService` |
| `FSO.Common.Domain`, `FSO.Server.Domain` | `FSO.Domain` |
| `FSO.Server`, `FSO.Server.Api`, `FSO.Server.Common` | `FSO.Server` |
| `FSO.Server.Database` | `FSO.Server.Database` |
| `FSO.Server.Updater` (watchdog), `FSO.Patcher` | Dropped (platform service managers and packaging) |
| `FSO.IDE` (Volcanic) | Later phase; see [tools.md](./tools.md#what-to-keep) |
| `tso.debug`, `FSO.Server.Debug` | Rebuilt as in-game panels and CLI tools |
| `FSO.Server.Framework`, `System.Drawing`, `TSOClient.csproj`, `FSODroid`, `FSO.iOS`, `Charvatia`, `Other/tools`, `Other/libs/*DataModel` | Dropped |

### Shared build settings (sketch)

```xml
<!-- Directory.Build.props -->
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
</Project>
```

Turn on `IsTrimmable` and `IsAotCompatible` for the libraries once the
reflection-heavy parts are replaced. The analyzers will then report
every remaining trimming problem at build time.

## Dependency replacements

| FreeSO dependency | Used for | Replacement |
| --- | --- | --- |
| FSOMonoGame (fork, submodule) | Graphics, input, audio | MonoGame 3.8 DesktopGL from NuGet (see [rendering.md](./rendering.md#engine-choice)) |
| OpenTK, Tao.Sdl, checked-in `sdl2.dll`, `soft_oal.dll` | MonoGame backends | Included in MonoGame's NuGet packages per runtime |
| FSOMina.NET (fork, submodule) | TCP framing, TLS | `System.IO.Pipelines`, `Socket`, `SslStream`, or Kestrel connection handlers |
| Ninject, Ninject.Extensions.ChildKernel | Dependency injection | `Microsoft.Extensions.DependencyInjection` (keyed services for per-city instances) |
| NLog, Common.Logging, `LogThis` | Logging | `Microsoft.Extensions.Logging` (NLog or Serilog only as a sink) |
| Newtonsoft.Json | JSON | `System.Text.Json` with source generation |
| RestSharp | HTTP client | `HttpClient` with `IHttpClientFactory` |
| Nancy, OWIN, ASP.NET MVC/Web API | HTTP server | ASP.NET Core |
| Portable.JWT, JWT | Tokens | `Microsoft.AspNetCore.Authentication.JwtBearer` |
| Portable.BouncyCastle | Crypto for JWT | Not needed with ASP.NET Core |
| MySql.Data | MySQL | MySqlConnector |
| Dapper | Data access | Dapper (keep) |
| IBatisNet, Castle.DynamicProxy, log4net | Nothing (unused) | Remove |
| CommandLineParser 1.x, Mono.Options | Server CLI | `System.CommandLine` |
| GOLDEngine (binary DLL) | UIScript parser | Hand-written parser |
| LuaInterface (x86) | Nothing (unused) | Remove |
| Lidgren.Network | Nothing (unused) | Remove |
| Mp3Sharp | MP3 streaming | NLayer, or MonoGame `Song` |
| TargaImage, TargaImagePCL | TGA loading | One TGA decoder in FSO.Files, or ImageSharp or SkiaSharp |
| `System.Drawing` (Bitmap use in Volcanic, TargaImage) | Images | ImageSharp or SkiaSharp |
| `System.Speech` | Chat text-to-speech | Per-OS implementations behind an interface |
| `System.Runtime.Caching` | Server cache | `Microsoft.Extensions.Caching.Memory` |
| ScintillaNET, Be.Windows.Forms.HexBox | Server packet inspector | Dropped with the WinForms tool |
| Application Insights (in FSO.Server.Api) | Telemetry | OpenTelemetry, if wanted |

Every new package is a suggestion for the maintainer to approve.

## Cross-platform blockers

| Blocker | Where | Fix | Page |
| --- | --- | --- | --- |
| WinForms (156 files) | Volcanic, FSO.Debug, FSO.Server.Debug, FSO.Patcher, FSOInstaller, client crash dialog and clipboard | In-game panels, CLI tools, Avalonia, or drop | [tools.md](./tools.md), [client.md](./client.md#platform-features) |
| `MonogameLinker` and per-OS MonoGame copies | Client startup | One NuGet MonoGame package | [client.md](./client.md#startup-1) |
| Registry | `WindowsLocator` | Configured path and environment variable first; registry guarded by `OperatingSystem.IsWindows()` | [content.md](./content.md#changes) |
| Case-sensitive paths | Content lookups, case-split source folders | Case-insensitive file index; merge folders | [content.md](./content.md#changes), [files.md](./files.md#changes) |
| `\` separators and Windows default paths | `CityDataRetriever`, `config.json`, locators | `Path.Combine`, configuration | [rendering.md](./rendering.md#city-view) |
| `user32.dll` P/Invoke | `InputManager` (unused), `ActionQueue` | Remove | [client.md](./client.md#windows-only-code-in-the-client) |
| `System.Speech` | `UITTSContext` | Per-OS interface | [client.md](./client.md#platform-features) |
| `AppDomain` | Watchdog | systemd or Windows service | [server.md](./server.md#replace-removed-and-windows-only-apis) |
| `Thread.Abort`, `Suspend`, `Resume` | `LotHost`, `CityConnections`, `TaskEngine`, `GluonHostPool`, `MP3Player` | Cooperative cancellation with `CancellationToken` | [server.md](./server.md#replace-removed-and-windows-only-apis) |
| DirectX 11 content and backend | `-dx` switch, `Content/DX` | DesktopGL by default; optional WindowsDX build | [rendering.md](./rendering.md#content-pipeline) |
| x86-only references | `LuaInterface`, some `PlatformTarget` settings | Remove; build AnyCPU | [client.md](./client.md#cleanup) |

## Phased plan

Each phase leaves the new tree building and its tests passing. Phase
order follows the dependency graph from the bottom up, so each phase has
something real to test against.

### Phase 0: scaffolding

- Create `FreeSO.slnx`, `Directory.Build.props`, `Directory.Packages.props`,
  `.editorconfig`, and empty projects for the layout above.
- CI on Windows, Linux, and macOS (x64 and ARM64) that runs build and
  tests.
- Decide the [open decisions](#decisions-for-the-maintainer) that affect
  phase 1 (at least wire and save compatibility).
- Bring in the `FSOMonoGame` and `FSOMina.NET` submodules (read-only) to
  list what the forks change, since they are not checked out in this
  repo.

### Phase 1: formats and foundations

- Port FSO.Common (BCL part), FSO.Files, and FSO.Vitaboy with no graphics
  dependency.
- Port the `cTSO` serializers.
- Tests per format and per serializer.

### Phase 2: content

- Port FSO.Content with the case-insensitive file index, async
  initialization, and CPU-side decoding.
- A CLI command that loads an installed game and reports what it found.
  This becomes the first end-to-end check on each OS.

### Phase 3: simulation and audio

- Port FSO.SimAntics behind presentation interfaces, and FSO.HIT behind
  `ISoundOutput`.
- Replay tests: record save state plus commands from FreeSO's build,
  replay on the new VM, and compare state and random seed.
- A headless runner that loads a lot and ticks it, used by tests and by
  the lot server.

### Phase 4: protocol and servers

- Port the protocol on Pipelines with TLS and frame limits.
- Port the data service with source-generated serializers.
- Port the server on the Generic Host and ASP.NET Core, with Dapper and
  MySqlConnector, and the SQL scripts under a migration tool.
- Packet round-trip tests, decoder fuzz tests, and database integration
  tests in a container.

### Phase 5: rendering, UI, and client

- Port rendering on stock MonoGame DesktopGL and rebuild the content
  pipeline as part of the build.
- Port FSO.UI with the new UIScript parser.
- Port the client: startup, DI, regulators, screens, and panels.
- Manual checks on each OS: login, city view, join a lot, build and buy
  modes, an EOD, audio.

### Phase 6: tools and cleanup

- Decide Volcanic's future and port it.
- CLI tools for FAR and IFF extraction, packet decoding, and migrations.
- Delete or archive the dropped projects.

### Progress

- [ ] Phase 0: scaffolding
- [ ] Phase 1: formats and foundations
- [ ] Phase 2: content
- [ ] Phase 3: simulation and audio
- [ ] Phase 4: protocol and servers
- [ ] Phase 5: rendering, UI, and client
- [ ] Phase 6: tools and cleanup

## Decisions for the maintainer

These change compatibility or scope. Each one needs an explicit choice
before the phase that depends on it.

1. **Wire compatibility.** Keep the Aries, Voltron, and Electron packet
   layouts byte-for-byte, so FreeSO clients and new servers can mix? Or
   allow breaking changes (TLS required, new framing)? Recommended: keep
   the layouts, require TLS, and version the protocol so mixing is
   detected instead of silently failing.
2. **Save compatibility.** Keep loading `VMMarshal` saves (version 19)
   from FreeSO servers? Recommended: yes. It costs little and protects
   existing lots.
3. **Simulation compatibility.** Any change to primitives, random
   numbers, or tick rate breaks lockstep with FreeSO clients and can change
   how saved lots behave. Recommended: none during the port; fix bugs
   afterwards behind a version flag.
4. **Database schema.** Keep the MySQL schema and scripts as they are?
   Recommended: yes for the port. Supporting PostgreSQL or SQLite is a
   later, separate project.
5. **Volcanic.** In-game rebuild, Avalonia, or Windows-only WinForms?
   See [tools.md](./tools.md#what-to-keep).
6. **Mobile.** Drop for now, or plan .NET for Android and iOS from the
   start? Recommended: drop for now, but keep the libraries free of
   desktop assumptions.
7. **TS1 hybrid mode.** Keep it in the port? It doubles the content and
   audio paths. Recommended: keep the code, test TSO mode first.
8. **Identity.** The project's former FAQ mentioned a possible separate server
   and name. That affects default URLs, certificate names (FreeSO's code
   uses `auth.east.ea.com`), and branding, so decide it before phase 4.

## Risks found in the snapshot

These are risks in FreeSO's code. The rewrite should fix them, and
anyone running FreeSO's code should know about them.

| Risk | Where | Page |
| --- | --- | --- |
| JWT signing secret committed in two files | `FSO.Server/config.json`, `FSO.Server.Api/Web.config` | [server.md](./server.md#security) |
| Game traffic unencrypted (client TLS disabled) | `AriesClient.Connect` | [protocol.md](./protocol.md#tls) |
| Password in the login URL query string | `AuthClient.Authenticate` | [protocol.md](./protocol.md#security-fixes-the-rewrite-must-include) |
| Weak password hashing (PBKDF2-SHA1, 1,000 iterations) | `PasswordHasher` | [server.md](./server.md#passwords-and-tokens) |
| Unbounded frame sizes and an integer underflow in the decoder | `AriesProtocolDecoder` | [protocol.md](./protocol.md#security-fixes-the-rewrite-must-include) |
| Updates extracted without verification | `FSO.Patcher`, watchdog | [tools.md](./tools.md#what-to-replace) |
| Android installer downloads game files over plain HTTP | `FSODroid/InstallerActivity` | [client.md](./client.md#mobile-hosts) |
| Unbounded caches (sound effects; permanent texture cache under DirectX) | `Audio.SFXCache`, `TimedReferenceController` | [audio.md](./audio.md#changes), [common.md](./common.md#caching) |
| FAR3 archive opened during a read returns an empty manifest | `FAR3Archive` | [files.md](./files.md#archives) |
