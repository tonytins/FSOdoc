# FSO.Content: the content system

FSO.Content (`TSOClient/tso.content`) finds and loads everything from an
installed copy of The Sims Online: UI graphics, avatar meshes and
animations, objects, walls, floors, audio, city maps, and string tables.
It can also run in "TS1 hybrid" mode, where objects, avatars, and audio
come from an installed The Sims 1 instead. It sits on top of
[FSO.Files](./files.md) and FSO.Vitaboy (for avatar model types).

FreeSO ships none of these assets. The user must have the original game
installed, and the content system reads it in place.

## How it works (2017)

### Locating the game

The client finds the TSO install before anything else loads
([`FSOProgram`](../../TSOClient/tso.client/FSOProgram.cs)):

| OS | Locator | Path |
| --- | --- | --- |
| Windows | [`WindowsLocator`](../../TSOClient/tso.client/Utils/GameLocator/WindowsLocator.cs) | `HKLM\SOFTWARE\Maxis\The Sims Online\InstallDir` (32-bit registry view), else `C:\Program Files\Maxis\The Sims Online\TSOClient\` |
| macOS | [`MacOSLocator`](../../TSOClient/tso.client/Utils/GameLocator/MacOSLocator.cs) | `SpecialFolder.MyDocuments` + `/Documents/The Sims Online/TSOClient/` (Mono maps `MyDocuments` to the home folder on macOS) |
| Linux | [`LinuxLocator`](../../TSOClient/tso.client/Utils/GameLocator/LinuxLocator.cs) | `game/TSOClient/`, relative to the working directory |

macOS is detected by checking whether `/Users` exists, because Mono
reported macOS as `PlatformID.Unix`.

### The `Content` singleton

[`Content`](../../TSOClient/tso.content/Content.cs) is a process-wide
singleton (`Content.Get()`). `Init` takes the game path and either a
`GraphicsDevice` (client) or a `ContentMode.SERVER` flag (server, no
textures). The constructor creates one provider per asset family, and
`Init` then:

1. Recursively lists every file under the game folder into `AllFiles`
   (paths relative to the base).
2. Loads PIFF and OTF patches from `Content/Patch/` (or
   `Content/TS1Patch/`), see [files.md](./files.md#patching-with-piff-and-otf).
3. Initializes the avatar providers, audio, purchasable outfits, INI
   files, `datadefinition.dat`, and thumbnails.
4. Calls `InitWorld`: objects, the object catalog, semi-globals, walls,
   floors, and roofs.

`Content.LoadProgress` is a static progress value the loading screen
polls.

### Providers

Every asset family is an `IContentProvider<T>`. Most are built from one of
four generic providers in `framework/`:

| Provider | Source |
| --- | --- |
| [`FAR3Provider<T>`](../../TSOClient/tso.content/framework/FAR3Provider.cs) | FAR3 archives matched by a regex over `AllFiles`, such as `.*/meshes/.*\.dat`. |
| [`FAR1Provider<T>`](../../TSOClient/tso.content/framework/FAR1Provider.cs) | FAR1 archives, used for object IFFs (`objiff.far`), sprites (`objspf*.far`), and tuning (`objotf*.far`). |
| [`FileProvider<T>`](../../TSOClient/tso.content/framework/FileProvider.cs) | Loose files. |
| [`PackingslipProvider<T>`](../../TSOClient/tso.content/framework/PackingslipProvider.cs) | Files listed in a packingslip XML manifest. |

A provider pairs a source with an `IContentCodec<T>` from `codecs/`
(mesh, animation, skeleton, outfit, appearance, binding, texture, IFF,
OTF, and others) that turns bytes into the model type. Results go
through a `TimedReferenceCache` (see [common.md](./common.md#caching)).

A FAR3 asset is addressed by a 64-bit ID: `(fileID << 32) | typeID`, taken
from the archive entry. Avatar outfits, appearances, and bindings refer to
each other by these IDs.

The main families:

| Field on `Content` | Provider | Model |
| --- | --- | --- |
| `UIGraphics` | `UIGraphicsProvider` | UI bitmaps from `uigraphics/*.dat`, plus a table of loose files mapped to IDs. |
| `AvatarMeshes`, `AvatarTextures`, `AvatarSkeletons`, `AvatarAnimations`, `AvatarAppearances`, `AvatarBindings`, `AvatarOutfits`, `AvatarHandgroups`, `AvatarCollections`, `AvatarPurchasables`, `AvatarThumbnails` | `Avatar*Provider` | Vitaboy types; see [rendering.md](./rendering.md#vitaboy-avatars). |
| `WorldObjects` | [`WorldObjectProvider`](../../TSOClient/tso.content/WorldObjectProvider.cs) | `GameObject`: an `OBJD` plus its IFF, sprites, and tuning. |
| `WorldCatalog` | `WorldObjectCatalog` | Buy and build mode catalog. |
| `WorldObjectGlobals` | `WorldGlobalProvider` | Semi-global IFFs and their tuning. |
| `WorldWalls`, `WorldFloors`, `WorldRoofs` | `WorldWallProvider`, `WorldFloorProvider`, `WorldRoofProvider` | Architecture styles. |
| `Audio` | [`Audio`](../../TSOClient/tso.content/Audio.cs) | HIT resource groups, UTK and XA sounds, DBPF audio, music stations. |
| `CityMaps` | `CityMapsProvider` | City terrain, elevation, and road maps. |
| `RackOutfits` | `RackOutfitsProvider` | Clothing rack stock. |
| `GlobalTuning` | `Tuning` | `tuning.dat`. |
| `DataDefinition` | `TSODataDefinition` | `datadefinition.dat`, used by the data service. |

### Objects

`WorldObjectProvider.Init` reads `packingslips/objecttable.xml`, which
maps each object GUID to an IFF file name in `objiff.far`, a group, and a
sub-index. It then scans `Content/Objects/` for standalone `*.iff` files
and registers every `OBJD` in them, which is how FreeSO adds objects that
weren't in the original game. A `GameObject` resolves its resources on
demand through `GameObjectResource`, which pairs the object's IFF with its
sprite IFF and its semi-global (named by its `GLOB` chunk). The
semi-global supplies shared BHAVs and tuning constants.

### TS1 hybrid mode

When `Content.TS1Hybrid` is set (the `-ts1` command-line switch), the
object, avatar, and audio providers are swapped for the ones in `TS1/`,
which read an installed The Sims 1. `TS1BCFProvider` reads BCF/CFP
animations and skeletons, `TS1NeighborhoodProvider` reads families and
neighbors, and `TS1Audio` reads `.hsm`/`.hit` files. The default path,
`D:/Games/The Sims/`, is hard-coded in `Content` and overridden from
settings.

### Editing support

[`ChangeManager`](../../TSOClient/tso.content/ChangeManager.cs) tracks IFFs
and chunks changed by the Volcanic IDE, can discard them, and saves them
as PIFFs through `PiffEncoder`. See [tools.md](./tools.md).

### Preloading

[`ContentPreloader`](../../TSOClient/tso.content/ContentPreloader.cs) is
created by the client's `LoadingScreenController` to warm content in the
background while the loading screen shows.

## Modern .NET rewrite

### Target

`FSO.Content` as a `net10.0` library, with GPU upload moved out (see
below). Servers need objects, tuning, and data definitions but no
graphics, so the server-safe part must not reference MonoGame.

### Changes

- **Replace the singleton** with a `ContentManager` registered in DI.
  Providers become constructor dependencies. That allows two content sets
  side by side (for example TSO and TS1) and makes tests possible.
- **Find the game portably.** Keep the per-OS locators behind one
  `IGameLocator`, but check, in order, a configured path, an environment
  variable (`FSO_GAME_DIR`), then the OS default. Put the registry lookup
  behind `OperatingSystem.IsWindows()` and `[SupportedOSPlatform("windows")]`
  (registry access needs the `Microsoft.Win32.Registry` APIs, which are
  Windows-only). On Linux, don't depend on the working directory; use XDG
  paths (`$XDG_DATA_HOME`).
- **Case-insensitive file index.** Original installs mix case
  (`UIGraphics` versus `uigraphics`), and FreeSO's regexes assume lower
  case. Build `AllFiles` once as a dictionary keyed by normalized
  lower-case relative path with `/` separators, and resolve every lookup
  through it. That one change fixes most Linux and macOS content failures.
- **Async loading.** `Init` blocks for seconds and reports progress
  through a static field. Make it `Task InitializeAsync(IProgress<ContentLoadingProgress>, CancellationToken)`.
- **Decode without a device.** Codecs should produce CPU-side data. A
  separate `ITextureFactory` in the rendering layer uploads to the GPU.
- **XML.** Replace `XmlDocument` packingslip reads with `XmlReader` or
  `XDocument`. Both are cross-platform; the change is for clarity and
  validation (check attributes exist instead of assuming them).
- **Patch folder.** Keep the PIFF and standalone object folders, but read
  them from a configured mod directory instead of `Content/` next to the
  executable.
- **Tests.** Provider lookup, ID packing, and packingslip parsing can be
  tested with small synthetic files.
