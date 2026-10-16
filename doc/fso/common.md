# FSO.Common: shared foundations

FSO.Common (`TSOClient/tso.common`) is the shared base for client,
server, and tools. It mixes four unrelated concerns: process-wide
settings, a small game and rendering framework on top of MonoGame, the
`cTSO*` wire serialization, and general utilities. It references
MonoGame (WindowsGL), Mina.NET, Mp3Sharp, Ninject, NLog, Common.Logging,
and Newtonsoft.Json.

## How it works (2017)

### Process-wide state

- [`FSOEnvironment`](../../TSOClient/tso.common/FSOEnvironment.cs) is a set
  of static fields the client fills at startup: content directories, the
  game thread, `DirectX` versus OpenGL, `Linux`, DPI scale, refresh rate,
  and mobile flags such as `SoftwareKeyboard`.
- [`IniConfig`](../../TSOClient/tso.common/IniConfig.cs) is an abstract
  key-value settings file with defaults. The client's `GlobalSettings`
  (in FSO.UI) derives from it.
- [`Log`](../../TSOClient/tso.common/Log.cs) is a 1,000-line logging class
  (`LogThis`) with its own file rotation. NLog and Common.Logging are
  referenced alongside it, so the codebase has three logging paths.

### Game and rendering framework

`rendering/framework/` holds a thin layer over MonoGame that the client and
tools build on:

- [`Game`](../../TSOClient/tso.common/rendering/framework/Game.cs) derives
  from MonoGame's `Game` and owns a
  [`GameScreen`](../../TSOClient/tso.common/rendering/framework/GameScreen.cs).
- `GameScreen` holds an ordered list of `IGraphicsLayer`s. Each frame it
  builds an [`UpdateState`](../../TSOClient/tso.common/rendering/framework/model/UpdateState.cs)
  (time, keyboard, mouse and touch, text input) and passes it to each
  layer, then draws the layers in order. The client uses two layers: the
  3D scene layer (`_3DLayer`) and the UI layer.
- `_3DLayer`, `_3DScene`, `_3DComponent`, and the cameras
  (`BasicCamera`, `OrthographicCamera`, `ManualCamera`) form a minimal
  scene graph.
- [`InputManager`](../../TSOClient/tso.common/rendering/framework/io/InputManager.cs)
  handles keyboard focus, text editing keys, and IME-style text input.
- [`CursorManager`](../../TSOClient/tso.common/rendering/framework/CursorManager.cs)
  loads the original game's `.cur` and `.ani` cursors.
- [`PPXDepthEngine`](../../TSOClient/tso.common/utils/PPXDepthEngine.cs)
  manages render targets for the 2D lot renderer's depth buffer, with a
  software fallback when multiple render targets aren't available.

### Threading

[`GameThread`](../../TSOClient/tso.common/utils/GameThread.cs) is the bridge
between background threads (network, content loading) and the MonoGame
update loop. `NextUpdate` queues a callback for the next frame,
`InUpdate` runs it now if already on the game thread, and `SetTimeout`
and `SetInterval` give JavaScript-style timers driven by frame updates.
Most cross-thread work in the client goes through this class.

### Caching

[`TimedReferenceController`](../../TSOClient/tso.common/utils/TimedReferenceCache.cs)
keeps recently used objects alive in a ring of hash sets that rotates on
a timer, so content survives a few seconds after its last use before the
garbage collector can take it. `TimedReferenceCache<TKey, TValue>` is a
`ConcurrentDictionary` of weak references built on it. Content providers
and `IffFile` (through its finalizer) use this. Under DirectX the client
switches it to `CacheType.PERMANENT`, which never releases anything.

[`FileSystemCache`](../../TSOClient/tso.common/utils/Cache/FileSystemCache.cs)
is a disk cache, bound as `ICache` by the client's `CacheModule` and used
by `ClientLotProvider` and the person selection screen.

### Wire serialization

`Serialization/` implements the `cTSO*` value encoding used by the
Voltron and data service protocols (see [protocol.md](./protocol.md)):

- [`ModelSerializer`](../../TSOClient/tso.common/Serialization/ModelSerializer.cs)
  maps CLR types and `cTSO` type IDs to `ITypeSerializer`s.
- `TypeSerializers/` has one serializer per wire type: integers, strings,
  booleans, vectors and maps of them, and `cTSOValueDecorated`, which
  handles any class marked with the `[cTSOValue]` attribute and
  implementing `IoBufferSerializable`.
- `Primitives/` has the composite messages: `cTSOTopicUpdateMessage`,
  `cTSONetMessageStandard`, `cTSOProperty`, and `cTSOGenericData`.
- [`IoBufferUtils`](../../TSOClient/tso.common/Serialization/IoBufferUtils.cs)
  adds Pascal string and other helpers to Mina.NET's `IoBuffer`.

### Utilities

Highlights from `utils/`:

| Type | Purpose |
| --- | --- |
| `Binding`, `DotPathBinding`, `ValuePointer` | Bind UI labels to `INotifyPropertyChanged` data service objects by dotted path, using reflection. |
| `Promise<T>`, `StateMachine<TState>`, `Callback` | Small async and state helpers that predate common `async` use in the codebase. |
| `TextureGenerator`, `TextureUtils` | CPU-generated textures and pixel operations (masking, palettes, resizing). |
| `TSOTime` | Converts real time to the game clock. |
| `MoneyFormatter` | Formats Simoleons. |
| `PathCaseTools.Insensitive` | Finds a file by case-insensitive match. Only TS1 audio uses it. |
| `IntersectRectTree` (in `Model/`) | A k-d tree for rectangle intersection, used by the 2D lot sprite batcher (`_2DSprite`). |
| `HTMLPrinter`, `IffPrinter` | Debug dumps of parsed content to HTML. |
| `MP3Player` (in `Audio/`) | Streams MP3 through Mp3Sharp into a MonoGame `DynamicSoundEffectInstance`. |

`Security/` defines `ISecurityContext` and `AvatarPermissions`, used by
the data service to check who may change a value.

### Dead and case-split files

The folder has both `Content/` and `content/`. `content/IContent.cs`
isn't compiled.

## Modern .NET rewrite

FSO.Common is the project to split, not port as-is. Today a server that
only wants the wire serializers must reference MonoGame.

| New project | Takes | Depends on |
| --- | --- | --- |
| `FSO.Common` | `TSOTime`, `MoneyFormatter`, enums, security, collection helpers | BCL only |
| `FSO.Common.Serialization` | `Serialization/` | `FSO.Common`, a byte-buffer abstraction (see [protocol.md](./protocol.md)) |
| `FSO.Common.Rendering` | `rendering/framework/`, `PPXDepthEngine`, texture helpers, cursors | MonoGame DesktopGL |
| (dropped) | `Log`, `Promise<T>`, `Callback`, `TimedReferenceController` | replaced as below |

Replacements:

- **Logging.** Replace `Log`, NLog, and Common.Logging with
  `Microsoft.Extensions.Logging`. Keep NLog or Serilog only as a sink if
  file output is wanted.
- **Settings.** Replace `IniConfig` and the static `FSOEnvironment` with
  `Microsoft.Extensions.Configuration` (JSON plus command line) bound to
  options records, passed in through DI. Store user settings under
  `Environment.GetFolderPath(SpecialFolder.ApplicationData)` instead of the
  working directory.
- **Threading.** Keep the idea of `GameThread` but implement it as a
  `SynchronizationContext` pumped once per frame. Background code can then
  `await` and resume on the game thread without explicit
  `NextUpdate` calls. Replace `Promise<T>` with `Task<T>`.
- **Caching.** Replace the timed reference ring with
  `Microsoft.Extensions.Caching.Memory` using sizes and sliding
  expiration, owned by the content layer. That makes memory use bounded
  and predictable. The project's former FAQ noted memory use as a known problem.
- **Bindings.** The reflection-based dotted-path bindings break under
  trimming. Use source-generated property change notifications (for
  example CommunityToolkit.Mvvm) or explicit subscriptions.
- **MP3.** MonoGame can play MP3 through `Song`, or use NLayer as a
  managed decoder if streaming into `DynamicSoundEffectInstance` is still
  needed.
- **Paths.** Use `Path.Combine` and real directory APIs everywhere, and
  make every lookup of original game files case-insensitive through one
  helper (see [content.md](./content.md)).
