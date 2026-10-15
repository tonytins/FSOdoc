# Servers

FreeSO's backend is one executable, `server.exe` (project
`TSOClient/FSO.Server`), that runs any combination of services from one
`config.json`. Supporting libraries:

| Project | Assembly | Role |
| --- | --- | --- |
| `FSO.Server` | `server` | Host process, all server roles, admin API |
| `FSO.Server.Database` | FSO.Server.Database | MySQL data access (Dapper) and schema scripts |
| `FSO.Server.Common` | FSO.Server.Common | Password hashing, JWT, version info, IP helpers |
| `FSO.Server.Domain` | FSO.Server.Domain | Shard domain helper (`Shards`) |
| `FSO.Server.Api` | FSO.Server.Api | ASP.NET Web API controllers for the user API |
| `FSO.Server.Updater` | `watchdog` | Restarts and updates `server.exe` |
| `FSO.Server.Debug` | FSO.Server.Debug | WinForms packet inspector (see [tools.md](./tools.md)) |
| `FSO.Server.Framework` | FSO.Server.Framework | Placeholder with only `Class1.cs` |

The wire protocols are in [protocol.md](./protocol.md). The lot
simulation is [SimAntics](./simantics.md).

## How it works (2017)

### Startup

[`Program`](../../TSOClient/FSO.Server/Program.cs) parses a verb with
CommandLineParser:

- `server run [-d]` runs [`ToolRunServer`](../../TSOClient/FSO.Server/ToolRunServer.cs),
  which starts every enabled service. `-d` starts the network debugger UI.
- `server db-init` runs [`ToolInitDatabase`](../../TSOClient/FSO.Server/ToolInitDatabase.cs),
  which compares the database to `DatabaseScripts/manifest.json` and
  applies missing scripts after asking for confirmation.

Dependency injection is Ninject: `ServerConfigurationModule`,
`DatabaseModule`, `GlobalDataServiceModule`, and `GluonHostPoolModule`.
`ToolRunServer` creates a Ninject child kernel for the API and for each
city, so each city gets its own data service and handlers. `ToolRunServer` loads
the game content in server mode (`Content.Init(path, ContentMode.SERVER)`)
because the lot server runs SimAntics against the real object files.

### Configuration

[`config.json`](../../TSOClient/FSO.Server/config.json) holds:

- `gameLocation`: the TSO install (content is required on the server too).
- `secret`: the JWT signing key for the admin API.
- `simNFS`: a folder for lot saves and other shared files.
- `database.connectionString`: MySQL.
- `services`: `tasks`, `api`, `userApi`, and lists of `cities` and
  `lots`. Each Aries service has a `call_sign`, a `binding`, internal and
  public host names, and an optional TLS `certificate`.

### Services

| Service | Class | What it does |
| --- | --- | --- |
| API | [`ApiServer`](../../TSOClient/FSO.Server/Servers/Api/ApiServer.cs) | Nancy, self-hosted. Login (`AuthController`), city selection (`CitySelectorController`), and admin endpoints (users, shards, hosts, tasks, OAuth for the admin panel) behind JWT. |
| User API | [`UserApi`](../../TSOClient/FSO.Server/Servers/UserApi/UserApi.cs) | OWIN self-host that runs the ASP.NET Web API controllers from `FSO.Server.Api`: login, avatar data, shard selection and status, registration, city JSON, and lot thumbnails. |
| City | [`CityServer`](../../TSOClient/FSO.Server/Servers/City/CityServer.cs) | One per city (shard). Accepts client Voltron sessions and serves the data service, database requests, messaging, purchases, roommates, moderation, and finding lots. |
| Lot | [`LotServer`](../../TSOClient/FSO.Server/Servers/Lot/LotServer.cs) | Hosts running lots for one or more cities. |
| Tasks | [`TaskServer`](../../TSOClient/FSO.Server/Servers/Tasks/TaskServer.cs) | Runs scheduled jobs from cron expressions: `prune_database` and `bonus` (daily property and visitor bonuses and top 100 lists). |

The API and the user API overlap: both implement `AuthLogin` and the city
selector, one on Nancy and one on ASP.NET Web API. `FSO.Server.Api` also
has `Global.asax` and `Web.config`, so it can be hosted in IIS on its own.

Every Aries service derives from
[`AbstractAriesServer`](../../TSOClient/FSO.Server/Framework/Aries/AbstractAriesServer.cs):
a Mina.NET acceptor with the Aries codec, optional TLS, a session list,
session interceptors, and an `AriesPacketRouter` that dispatches each
packet type to a handler class by reflection over handler methods.

### City server

The city server owns the world's state for one shard:

- **Sessions.** `VoltronConnectionLifecycleHandler` tracks connected
  avatars and their claims (`AvatarClaims`), so an avatar can only be
  online once.
- **Data service.** `DataServiceWrapperHandler` serves avatar, lot, and
  city data from `ServerAvatarProvider` and `ServerLotProvider`, and
  applies client updates after security checks.
- **Lots.** `JoinLotHandler` uses
  [`LotAllocations`](../../TSOClient/FSO.Server/Servers/City/Domain/LotAllocations.cs)
  and `LotServerPicker` to choose a lot server, ask it over Gluon to open
  the lot, and answer the client with the lot server's address and a
  ticket. `JobMatchmaker` places players into job lots.
- **Other handlers.** Purchases, roommates, avatar retirement, instant
  messages, moderation, registration, preferences, and find player.

### Lot server

[`LotHost`](../../TSOClient/FSO.Server/Servers/Lot/Domain/LotHost.cs) holds
running lots, up to `max_lots`. Each lot is a
[`LotContainer`](../../TSOClient/FSO.Server/Servers/Lot/Domain/LotContainer.cs)
with its own `VM`, a `VMServerDriver`, and a dedicated thread running
`LotContainer.Run`:

1. Load the lot's latest save from `simNFS/Lots/<id>/state_<n>.fsov`, or
   create it from a blueprint, then restore surrounding terrain.
2. Tick the VM in a loop. Broadcast tick batches to the lot's clients as
   `FSOVMTickBroadcast` packets.
3. Save the lot and its avatars periodically. Lot saves rotate through
   numbered backups and also write a hollow state (`hollow.fsoh`).
4. Shut down when no one is left, or when the city asks.

If the VM throws, the lot shuts down. A background thread watches for a
stuck lot thread; on .NET Framework it suspends the thread to log a stack
trace, then aborts it.

[`LotServerGlobalLink`](../../TSOClient/FSO.Server/Servers/Lot/Domain/LotServerGlobalLink.cs)
implements SimAntics' `IVMTSOGlobalLink` against the database: money
transfers, object persistence, roommates, relationships, and plugin data.
Database calls are queued to the lot's background thread with
`LotHost.InBackground`. Their results come back into the VM as network
commands such as `VMNetAsyncResponseCmd`, so the simulation never waits on
the database and every client applies the result on the same tick.

The lot server connects to each city it serves through
[`CityConnections`](../../TSOClient/FSO.Server/Servers/Lot/Lifecycle/CityConnections.cs)
over Gluon, advertising its capacity.

### Server-to-server: Gluon

[`GluonHostPool`](../../TSOClient/FSO.Server/Utils/GluonHostPool.cs) keeps
connections between servers, pings them, and authenticates them with the
shared secret (see [protocol.md](./protocol.md#server-to-server-authentication)).

### Database

[`FSO.Server.Database`](../../TSOClient/FSO.Server.Database/) uses MySQL
through MySql.Data and Dapper. `IDAFactory.Get()` returns an `IDA` that
exposes one repository per area (users, avatars, lots, objects,
roommates, relationships, bookmarks, shards, tasks, bans, top 100,
visits, bonus, and others), each with a `Sql*` implementation in
`DA/<Area>/`. Queries use Dapper parameters. A few build SQL text from
fixed table names chosen by a flag, but never from user input.

The schema is in `DatabaseScripts/`: base scripts per table group plus
numbered change scripts (`changes/0001` to `0015`), listed in
`manifest.json`. [`DbChangeTool`](../../TSOClient/FSO.Server.Database/Management/DbChangeTool.cs)
records applied scripts in `fso_db_changes`.

The project still references IBatisNet, Castle.DynamicProxy, and log4net,
but no source file uses them.

### Passwords and tokens

[`PasswordHasher`](../../TSOClient/FSO.Server.Common/PasswordHasher.cs)
hashes with PBKDF2 (`Rfc2898DeriveBytes`, default SHA-1) at 1,000
iterations, storing the scheme name so it can be changed later. Admin
API tokens are JWTs signed with `config.json`'s `secret`.

### Watchdog

`watchdog.exe` ([`FSO.Server.Updater`](../../TSOClient/FSO.Server.Updater/Program.cs))
loads `server.exe` into a child `AppDomain`, runs it, and restarts it
unless it exits with code 2 (shutdown). With `--update` it downloads a
new build from a configured URL or TeamCity first.

## Modern .NET rewrite

### Hosting

Rebuild the host on the **.NET Generic Host** (`Host.CreateApplicationBuilder`):

- Each service (API, city, lot host, tasks) becomes an
  `IHostedService` (or `BackgroundService`), enabled by configuration.
  One process can still run them all, and each can also run alone in a
  container.
- Configuration from `appsettings.json`, environment variables, and the
  command line, bound to options classes and validated at startup
  (`ValidateDataAnnotations`, `ValidateOnStart`).
- Secrets (JWT key, database password, Gluon secret) from environment
  variables or user secrets, never from a committed file.
- Logging through `Microsoft.Extensions.Logging`.
- Run as a systemd unit on Linux (`UseSystemd`) or a Windows service
  (`UseWindowsService`). That replaces the watchdog. Updates come from the
  deployment system (containers or packages), not from the server
  downloading itself.

### Replace removed and Windows-only APIs

| 2017 | Status on .NET 10 | Replacement |
| --- | --- | --- |
| `AppDomain.ExecuteAssembly` (watchdog) | Not supported | systemd, Windows service, or container restart policy |
| `Thread.Abort`, `Thread.Suspend`, `Thread.Resume` (stuck lot detection in `LotHost`; stopping watcher threads in `CityConnections`, `TaskEngine`, and `GluonHostPool`) | Throw `PlatformNotSupportedException` | Run each lot as a task with a `CancellationToken`, check it between ticks, and on a stuck lot mark it failed, stop routing clients to it, and restart the process if needed. Capture stacks with `dotnet-stack` or `dotnet-dump`. |
| Nancy, OWIN self-host, ASP.NET Web API, `Global.asax` | Not available | **ASP.NET Core** minimal APIs or controllers, one API project. Merge the duplicate login and city selector endpoints. |
| Mina.NET acceptors | Not maintained | Kestrel connection handlers or sockets with `System.IO.Pipelines` (see [protocol.md](./protocol.md#modern-net-rewrite)) |
| Ninject, child kernels per shard | Not maintained | `Microsoft.Extensions.DependencyInjection`, with keyed services or a factory per shard |
| CommandLineParser 1.x | Old API | `System.CommandLine`, or keep only `db-init` as a separate command |
| `System.Runtime.Caching.MemoryCache` | Available as a package | `Microsoft.Extensions.Caching.Memory` |

### Database

- Keep **Dapper**. It works on modern .NET and the queries are already
  parameterized.
- Replace MySql.Data with **MySqlConnector** (MIT, async throughout).
- Make every data access method `async`.
- Keep the numbered SQL scripts, and run them with a migration tool such
  as DbUp or Evolve instead of `DbChangeTool`. They support the same
  "apply missing scripts in order" model.
- Remove the unused IBatisNet, Castle.DynamicProxy, and log4net references.

### Security

- **Rehash passwords.** Move to PBKDF2 with SHA-256 or SHA-512 at
  current iteration counts (hundreds of thousands), or Argon2id. The
  stored scheme name allows upgrading each hash on the user's next login.
- **Remove committed secrets.** `config.json` and `FSO.Server.Api/Web.config`
  contain the same JWT signing key. Anyone using these files as-is shares
  a known key and can forge admin tokens.
- **TLS** for the API and all Aries services, with certificates from
  configuration (see [protocol.md](./protocol.md#security-fixes-the-rewrite-must-include)).
- **Rate limit** login and registration with ASP.NET Core's rate
  limiting middleware.

### Lot hosting

Keep one simulation loop per lot, but drive it with a
`PeriodicTimer` on a dedicated long-running task. Database work from
`LotServerGlobalLink` becomes `async` and keeps delivering its results
as VM commands, posted into a `Channel<T>` that the lot loop drains at
the start of each tick. That
keeps the simulation single-threaded and deterministic.

### Tests

- Integration tests for the database layer against MySQL in a container
  (Testcontainers).
- Handler tests with fake sessions for the city server.
- Replay tests for lots (see [simantics.md](./simantics.md#determinism-checks)).
