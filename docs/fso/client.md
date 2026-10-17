# FSO.Client and FSO.UI: the game client

The game client is the `FreeSO.exe` assembly, built from
`TSOClient/tso.client/FSO.Client.csproj`. Its UI framework is a separate
library, **FSO.UI** (`TSOClient/FSO.UI`), whose code mostly lives in
`FSO.Client.*` namespaces. The client ties together everything else:
[content](./content.md), [rendering](./rendering.md),
[SimAntics](./simantics.md), [audio](./audio.md), and the
[network protocols](./protocol.md).

## How it works (update-46)

### Startup

1. [`Program.Main`](../../TSOClient/tso.client/Program.cs) creates
   [`FSOProgram`](../../TSOClient/tso.client/FSOProgram.cs) and calls
   `InitWithArguments`:
   - registers an `AssemblyResolve` handler and a crash handler that
     shows a WinForms `MessageBox`;
   - detects the OS and picks a game locator (see
     [content.md](./content.md#locating-the-game));
   - parses arguments: `WIDTHxHEIGHT`, `w` or `f` (windowed or full
     screen), `-dx`/`-dx11` or `-gl`/`-ogl`, `-ts1` or `-tso`, `-lang<N>`,
     and `-hz<N>`;
   - calls `MonogameLinker.Link`, which points `AssemblyResolve` at
     `Monogame/WindowsGL/`, `Monogame/Windows/` (DirectX), `Monogame/Linux/`,
     or `Monogame/MacOS/`, so one build can load the right MonoGame
     binary at run time;
   - fills `FSOEnvironment` and `GlobalSettings` (content folders, game
     path, version from `version.txt`).
2. [`GameStartProxy.Start`](../../TSOClient/tso.client/GameStartProxy.cs)
   creates and runs `TSOGame`. It exists so that `Program` itself never
   references MonoGame types before the linker has chosen a binary.
3. [`TSOGame.Initialize`](../../TSOClient/tso.client/TSOGame.cs) creates the
   Ninject kernel (`RegulatorsModule`, `NetworkModule`, `CacheModule`,
   later `ClientDomainModule`), initializes content with the
   `GraphicsDevice`, creates the 3D scene layer and the UI layer, starts
   the HIT audio VM, binds the data service, and calls
   `GameController.StartLoading`.
4. `TSOGame.LoadContent` loads the compiled fonts and the Vitaboy effect
   from `Content/OGL/` or `Content/DX/`. If they're missing, the game
   exits silently.

Settings live in [`GlobalSettings`](../../TSOClient/FSO.UI/GlobalSettings.cs),
an `IniConfig` stored as `config.ini` in `FSOEnvironment.UserDir`
(the working directory's `Content/` folder on desktop).

### Facades

Two static classes give global access:

- [`GameFacade`](../../TSOClient/FSO.UI/GameFacade.cs) (in FSO.UI): the
  game, screens (`UILayer`), scenes, graphics device, fonts, cursor,
  strings, and platform flags.
- [`FSOFacade`](../../TSOClient/tso.client/FSOFacade.cs): the Ninject kernel
  and the `GameController`.

### Screens and controllers

[`GameController`](../../TSOClient/tso.client/GameController.cs) moves the
player between screens: loading, login, person selection, Create-a-Sim,
the city (`CoreGameScreen`), sandbox mode, and credits. It also handles
disconnects and fatal errors.

Each screen in [`UI/Screens/`](../../TSOClient/tso.client/UI/Screens/) is a
view. Its logic is in a matching controller in
[`Controllers/`](../../TSOClient/tso.client/Controllers/), created by
Ninject with the view and services injected (for example
`CoreGameScreenController(CoreGameScreen view, Network network, IClientDataService dataService, ...)`).
Panels such as the lot page and person page follow the same pattern
(`Controllers/Panels/`).

### Regulators

Network workflows are written as state machines called regulators,
derived from [`AbstractRegulator`](../../TSOClient/FSO.Server.Clients/Framework/AbstractRegulator.cs)
(in FSO.Server.Clients). A regulator declares named states with allowed
transitions and data triggers:

```csharp
AddState("FindLot").OnlyTransitionFrom("SelectLot")
    .OnData(typeof(FindLotResponse)).TransitionTo("FoundLot");
```

Each regulator starts its own background thread (at highest priority)
in its constructor, and `AsyncTransition` queues work onto it. A source
comment explains why: network work triggered from a button press would
otherwise run inside the UI update loop and deadlock when it shows a
dialog. The regulator's `OnTransition` event tells controllers what
happened.

| Regulator | Workflow |
| --- | --- |
| [`LoginRegulator`](../../TSOClient/tso.client/Regulators/LoginRegulator.cs) | Auth login, initial connect (version check), avatar data, shard status. |
| [`CityConnectionRegulator`](../../TSOClient/tso.client/Regulators/CityConnectionRegulator.cs) | Select city, get a shard ticket, open the Aries socket, answer `RequestClientSession`, wait for the host, load avatar data. |
| [`LotConnectionRegulator`](../../TSOClient/tso.client/Regulators/LotConnectionRegulator.cs) | Find lot through the city, connect to the lot server, then stream VM ticks (`LotCommandStream`). |
| `CreateASimRegulator` | Create an avatar on the city server. |
| `PurchaseLotRegulator` | Buy a lot. |

### Playing on a lot

When a lot connection reaches its command stream, `CoreGameScreen`
creates a LotView `World`, a `VMClientDriver`, and a `VM`. The driver's
`OnClientCommand` sends the player's commands to the lot server as
`FSOVMCommand` packets. `FSOVMTickBroadcast` packets from the server feed
the driver. [`UILotControl`](../../TSOClient/tso.client/UI/Panels/UILotControl.cs)
handles input on the lot (pie menus, object selection, build and buy
tools) and turns it into VM commands. See
[simantics.md](./simantics.md#multiplayer-deterministic-lockstep).

[`SandboxGameScreen`](../../TSOClient/tso.client/UI/Screens/SandboxGameScreen.cs)
does the same offline, with an in-process `VMServerDriver`.

### UI framework (FSO.UI)

- [`UIElement`](../../TSOClient/FSO.UI/Framework/UIElement.cs) is the base
  for everything: position, scale, opacity, and per-frame
  `Update(UpdateState)` and `Draw(UISpriteBatch)`.
  [`UIContainer`](../../TSOClient/FSO.UI/Framework/UIContainer.cs) holds
  children, and `UICachedContainer` renders them to a texture.
- [`UILayer`](../../TSOClient/FSO.UI/UILayer.cs) is the graphics layer that
  draws the current `UIScreen`, dialogs, and tooltips.
- **UIScript.** TSO describes most windows in `.uis` files under
  `gamedata/uiscripts/` in the original install.
  `UIContainer.RenderScript("chatdialog.uis")` parses one with a parser
  generated by the GOLD Parser Builder (`UIScriptParser`, grammar table
  `Content/UIScript.egt`, runtime `GOLDEngine.dll`). It creates the
  controls and assigns each one to the C# property with the same name on
  the owning class, using reflection. Panels declare those properties
  (`public UIButton ChatHistoryScrollUpButton { get; set; }`).
- Controls in [`Controls/`](../../TSOClient/FSO.UI/Controls/): buttons,
  labels, images (with nine-slice), list boxes, sliders, the
  1,300-line `UITextEdit`, dialogs, alerts, and grid viewers.
- `UITween` animates element properties, and `TextRenderer` lays out
  text with the bitmap fonts.
- [`UIFileIDs`](../../TSOClient/FSO.UI/UIFileIDs.cs) lists the 64-bit asset
  IDs of the original UI graphics.

The client's own panels are in
[`tso.client/UI/Panels/`](../../TSOClient/tso.client/UI/Panels/): the
control panel (`UIUCP`), live, buy, build, and house modes, the gizmo
(city search and top 100), chat, messaging, the person and lot pages,
options, and dialogs. EOD (object plugin) UIs are in `UI/Panels/EODs/`,
one per server-side handler.

### Debugging and the IDE

`GameController.StartDebugTools` and the debug menu open WinForms tools
from FSO.UI's `Debug/` folder. Most of those files are excluded from the
build (see below). [`IDEHook`](../../TSOClient/FSO.UI/Debug/IDEHook.cs) lets
the Volcanic IDE ([tools.md](./tools.md)) inject itself into a running
game and attach to its VM.

### Mobile hosts

`FSODroid` (Xamarin.Android) and `FSO.iOS` (Xamarin.iOS) start the same
`TSOGame` through `GameStartProxy`. They set `FSOEnvironment` for touch
devices: software keyboard, software depth instead of multiple render
targets, UI zoom, and DPI scale. Both have an installer screen for the
TSO files; the Android one downloads `The Sims Online.zip` over plain
HTTP from a host the user types in. Neither is in `FreeSO.sln`, and both
reference the FreeSO assemblies as prebuilt DLLs rather than projects.
`TSOClient/System.Drawing` is an empty assembly named `System.Drawing`
whose only class carries the comment "is this enough to fool
xamarin.android?". FSODroid references it in place of the real
`System.Drawing`.

### Windows-only code in the client

| Code | Windows-only part |
| --- | --- |
| `FSOProgram`, `Program` | WinForms `MessageBox` on crash; `WinFormsClipboard` |
| `WindowsLocator` | Registry lookup |
| [`UITTSContext`](../../TSOClient/tso.client/UI/Model/UITTSContext.cs) | `System.Speech` text-to-speech for chat. `FSOProgram` only enables it when not on Linux or macOS. |
| `InputManager` (FSO.Common) | Declares `user32.dll` `MapVirtualKey`, but never calls it |
| `MonogameLinker` | Chooses between per-OS MonoGame binaries copied next to the executable |
| `tso.client` folder | Checked-in `sdl2.dll`, `soft_oal.dll`, `OpenTK.dll`, `NVorbis.dll` (Windows native or prebuilt) |

`FSO.Client.csproj` references `LuaInterface` (x86 only), but no source
file uses it.

### Dead files

`TSOClient.csproj`, in the same folder, is a .NET 3.5 and XNA project
from FreeSO's predecessor, Project Dollhouse (its assembly name is
"Project Dollhouse Client"). It isn't in
`FreeSO.sln`, and only 3 of the 123 files it lists still exist.

49 `.cs` files in `tso.client` are compiled by neither project: the old
`Network/` stack (`NetworkClient`, `PacketStream`, `ARC4`, `SaltedHash`,
packet handlers), the old city renderer (`CityGeom`, `RhysGeom`,
`NioGeom`, `CityCamera`, and others), the old lot renderer
(`Rendering/Lot/`), `Rendering/Sim/`, `LotScreen`, `LotScreenNew`,
`MessagesCache`, `CityServerInformation`, and `GameContent/ContentManager`.
In FSO.UI, the 12 WinForms debug tool files in `Debug/` (except
`IDEHook.cs`) aren't compiled either.

## Modern .NET rewrite

### Project shape

| New project | Contents |
| --- | --- |
| `FSO.Client` (executable, `net10.0`) | Startup, DI, controllers, regulators, screens, panels |
| `FSO.UI` (library) | UI framework and UIScript, no dependency on the client |
| `FSO.Client.Desktop` (optional) | Only if per-OS integration (clipboard, TTS) needs its own project |

One executable, published per runtime identifier (`win-x64`,
`linux-x64`, `linux-arm64`, `osx-arm64`, `osx-x64`), self-contained.

### Startup

- Delete `MonogameLinker`, `GameStartProxy`, and the `AssemblyResolve`
  handler. Reference the MonoGame DesktopGL NuGet package. NuGet places
  native libraries per runtime (`runtimes/<rid>/native`), so one build
  works on every OS. If the DirectX backend is wanted on Windows, build
  it as a separate executable from the same projects.
- Parse arguments with `System.CommandLine` or
  `Microsoft.Extensions.Configuration.CommandLine`, and validate them.
  FreeSO's parser throws on input like `-hzabc`.
- Fail visibly: if the game files or compiled content are missing, show
  an error screen (or log and exit with a message) instead of exiting
  silently.
- Store settings in the user's config folder (`%APPDATA%`,
  `~/.config`, `~/Library/Application Support`) as JSON.

### Dependency injection

Replace Ninject with `Microsoft.Extensions.DependencyInjection`. Register
regulators, controllers, network clients, and the data service there.
Replace `GameFacade` and `FSOFacade` statics gradually: first wrap them
around the service provider, then inject the real dependencies.

### Regulators

The regulator state machines are a good design and can stay. Implement
transitions with `async`/`await` and `CancellationToken`, and marshal
results to the game thread through the frame-pumped
`SynchronizationContext` described in [common.md](./common.md#modern-net-rewrite).

### UIScript

- Replace GOLDEngine (an old binary-only DLL) with a small hand-written
  recursive-descent parser for `.uis`. The grammar is simple (nested
  tags with attributes), and a hand-written parser gives better errors.
- Replace reflection-based property binding with a source generator, or
  with explicit lookups (`script.Get<UIButton>("ChatHistoryScrollUpButton")`).
  Reflection over property names breaks under trimming and fails only at
  run time.

### Platform features

| Feature | Cross-platform option |
| --- | --- |
| Crash dialog | Log the exception, write a crash file, and show an in-game error screen. |
| Clipboard | SDL2's clipboard (`SDL_SetClipboardText`), which MonoGame DesktopGL already loads, or a library such as TextCopy. |
| Text-to-speech | Behind an interface: `System.Speech` (Windows), `say` (macOS), and `spd-say` or speech-dispatcher (Linux), or turn the feature off where missing. |
| Game locator | See [content.md](./content.md#changes). |

### Cleanup

- Delete `TSOClient.csproj` and the 49 uncompiled files, and the
  uncompiled `FSO.UI/Debug` forms (or rebuild the useful ones as in-game
  debug panels).
- Remove `LuaInterface`, the checked-in native DLLs, and
  `FSO.Client.csproj.rhys.nvuser`.
- Drop the Xamarin projects. If mobile comes back, use .NET for Android
  and iOS with MonoGame's mobile backends, sharing the same libraries.
