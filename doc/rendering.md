# Rendering: LotView, Vitaboy, and the city

Three pieces draw the game world:

- **FSO.LotView** (`TSOClient/tso.world`) draws a lot: terrain, floors,
  walls, roofs, objects, and Sims, in TSO's isometric style.
- **FSO.Vitaboy** (`tso.vitaboy.model`) holds the avatar model types, and
  **FSO.Vitaboy.Engine** (`tso.vitaboy.engine`) draws and animates them.
- The **city view** lives in the client itself
  (`tso.client/Rendering/City`).

All three use MonoGame (the FSOMonoGame fork) and HLSL effects compiled
through the MonoGame content pipeline.

## How it works (2017)

### Shaders and compiled content

Effect and font sources are in
[`tso.content/ContentSrc/`](../TSOClient/tso.content/ContentSrc/). There
are three MonoGame Content Builder files:

| File | Output | Platform |
| --- | --- | --- |
| `TSOClientContent.mgcb` | `Content/OGL` | DesktopGL (OpenGL, used on Windows, Linux, and macOS) |
| `TSOClientContentDX.mgcb` | `Content/DX` | DirectX 11 (Windows only) |
| `TSOClientContentiOS.mgcb` | iOS | iOS, with `*iOS.fx` variants |

Effects: `2DWorldBatch` (lot sprites with depth), `Vitaboy` (skinned
avatars), `GrassShader` (terrain), `LightMap2D` and `gradpoly2D`
(lighting), and `colorpoly2D`, `PixShader`, and `VerShader` (city and
utilities). `compileForMono.bat` and the checked-in `*.mgfx` files are
leftovers of a manual build for Mono. The client picks `Content/OGL/` or
`Content/DX/` at startup from the `-dx` and `-gl` switches (see
[client.md](./client.md#startup)).

### LotView

[`World`](../TSOClient/tso.world/World.cs) is a `_3DScene` (see
[common.md](./common.md#game-and-rendering-framework)) that renders one
lot. It holds:

- a [`Blueprint`](../TSOClient/tso.world/model/Blueprint.cs): the
  rendering model of the lot (walls, floors, terrain, objects, rooms, and
  lights) that SimAntics fills and updates;
- a [`WorldState`](../TSOClient/tso.world/WorldState.cs): camera
  position, zoom (`WorldZoom`: near, medium, far), rotation
  (`WorldRotation`, four directions), current floor level, and lighting;
- [`World2D`](../TSOClient/tso.world/World2D.cs) and
  [`World3D`](../TSOClient/tso.world/World3D.cs), which draw the
  sprite-based world and the 3D avatars on top.

TSO's objects are pre-rendered sprites with per-pixel depth (SPR2 frames
carry a z-buffer). `World2D` reproduces that with
[`_2DWorldBatch`](../TSOClient/tso.world/utils/_2DWorldBatch.cs), a
sprite batch that writes color and depth so that sprites and 3D avatars
sort correctly. To keep frame cost down, the static parts of the lot
(terrain, floors, walls, and objects that aren't moving) are drawn once
into a cached render target and redrawn only when something changes
("damage" in `BlueprintDamage`). Moving objects are drawn on top each
frame. Six render targets are kept: static color, static depth, object
ID, two for thumbnails, and one for lot thumbnails.

Picking uses the object ID buffer: each object is drawn with its ID
encoded as a color, and `GetObjectIDAtScreenPos` reads back one pixel.

Components draw each part of the lot:

| Component | Draws |
| --- | --- |
| `TerrainComponent` | Grass and terrain height, using `GrassShader`. |
| `FloorComponent`, `_3DFloorGeometry` | Floor tiles and pools. |
| `WallComponent` | Walls, with cutaway modes (walls down, cutaway, up) and junctions. 1,200 lines. |
| `RoofComponent` | Roofs generated from room shapes. |
| `ObjectComponent` | Object sprites from DGRPs via `DGRPRenderer`. |
| `AvatarComponent` | A Vitaboy avatar placed in the lot. |
| `SubWorldComponent` | A neighboring lot drawn around the current one. |

[`LMap/`](../TSOClient/tso.world/LMap/) adds per-room lighting and shadow
maps when `WorldConfig.AdvancedLighting` is on. [`WorldConfig`](../TSOClient/tso.world/WorldConfig.cs)
holds the user's lighting, smooth zoom, and surrounding-lot settings.

[`XmlHouse`](../TSOClient/tso.world/model/XmlHouse.cs) reads the
original game's XML lot blueprints in `housedata/blueprints/`. The lot
server loads job lots from them, and the client's debug export writes
`house_00.xml` in the same format.

### Vitaboy avatars

Vitaboy is TSO's skeletal animation system. The data model in
[`tso.vitaboy.model`](../TSOClient/tso.vitaboy.model/) chains together:

```text
PurchasableOutfit -> Outfit (light/medium/dark skin) -> Appearance
  -> Binding -> Mesh + Texture (bound to bones of a Skeleton)
Animation -> AnimationMotion per bone (+ time property lists for events)
HandGroup -> HandSet -> Hand -> Gesture (18 hand appearances per group)
```

All of these are loaded by the content system by 64-bit asset ID (see
[content.md](./content.md#providers)). `BCF` and `CFP` are the TS1
equivalents used in hybrid mode.

The engine:

- [`Avatar`](../TSOClient/tso.vitaboy.engine/Avatar.cs) holds a skeleton
  and a set of bindings and draws them with the `Vitaboy` effect. Skinning
  is done on the GPU: the shader receives up to 50 bone matrices
  (`SkelBindings`).
- [`SimAvatar`](../TSOClient/tso.vitaboy.engine/SimAvatar.cs) adds the
  head, body, hands, accessories, and skin tone.
- [`Animator`](../TSOClient/tso.vitaboy.engine/Animator.cs) advances
  animations and blends bone poses. During lot play, SimAntics keeps each
  avatar's current animation and frame in `VMAnimationState` and calls
  `Animator.SilentFrameProgress` every tick, so animation timing is part
  of the deterministic simulation.

### City view

The city view draws the whole city map (terrain, roads, and lot
markers) when the player is not on a lot.
[`Terrain`](../TSOClient/tso.client/Rendering/City/Terrain.cs)
(about 1,650 lines) builds textures and atlases from the city's
elevation, terrain type, road, and vertex color maps (from
`CityMapsProvider`), handles zoom and panning, and draws lot thumbnails, requesting them through its controller.
`LotTileEntry` describes each lot on the map. `CityDataRetriever` still
has a method that reads thumbnails from a local `housethumb\` folder,
using a Windows path separator.

Many older city renderer files in that folder (`CityGeom`, `RhysGeom`,
`NioGeom`, `CityCamera`, and others) are not compiled; see
[client.md](./client.md#dead-files).

### Dead and case-split files

LotView has both `Components`/`components` and `Model`/`model`. All its
files are compiled. FSO.LotView references `Lidgren.Network` and
`Tao.Sdl`, but no source file in the solution uses Lidgren.

## Modern .NET rewrite

### Engine choice

Stay on **MonoGame**, but on the stock 3.8.x release with the
**DesktopGL** backend (Windows, Linux, macOS) and, where wanted, the
**WindowsDX** backend. Stock MonoGame is maintained, ships as NuGet
packages, and runs on modern .NET. The code is written against the XNA
API shape, so a port keeps most of it.

Before switching, list what the FSOMonoGame fork adds. The submodule is
not checked out in this repo, so this list must come from upstream. Look
for: render target and depth format changes, `Texture2D` loading
changes, `TextInput` (now standard), a software depth mode
(`FSOEnvironment.SoftwareDepth`), and multiple render targets
(`FSOEnvironment.UseMRT`). Each one needs a stock equivalent or a small
extension in the new code.

Alternatives, if MonoGame's limits show up:

- **FNA**: XNA 4.0 accurate, SDL-based, cross-platform. Very close to the
  current code; uses its own shader toolchain (FXC-compiled effects).
- **Silk.NET or Veldrid**: lower-level and more work, but full control of
  render targets and modern APIs (Vulkan, Metal).

### Content pipeline

- Build effects with the MonoGame Content Builder as a .NET tool
  (`dotnet tool install dotnet-mgcb`) driven by `MonoGame.Content.Builder.Task`
  in the project, so content builds as part of the normal build on any OS.
- Drop the checked-in `*.mgfx` files and `compileForMono.bat`.
- Since MonoGame 3.8.1, shader compilation on Linux and macOS goes
  through a Wine-hosted compiler. Plan for that in CI, or keep compiled
  shader output as a build artifact.
- Replace the separate iOS effect files with preprocessor branches in one
  `.fx` file where possible.

### Code changes

- **Separate model from GPU.** `Mesh`, `MeshVertex`, and the sprite
  frames create GPU buffers directly. Keep them as plain data in the
  model and content libraries, and create GPU resources in the renderer.
  This also lets the server load avatars without a device.
- **Rendering cache.** Keep the static-layer cache in LotView; it is the
  main reason the 2D renderer is fast. Give render targets a clear owner
  and dispose them on resize and on `ChangedWorldConfig`.
- **Picking.** Reading back a pixel stalls the GPU. A CPU-side hit test
  against sprite bounds and masks (the `IntersectRectTree` already
  exists) avoids that.
- **HiDPI.** Handle DPI scale with the window's backbuffer size instead
  of `FSOEnvironment.DPIScaleFactor`.
- **Remove dead references** to Lidgren.Network and Tao.Sdl.
