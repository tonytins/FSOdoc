# Tools, installers, and legacy code

Everything here is outside the game's main runtime path: editors, debug
windows, installers, and older code kept in the repository. Almost all of
it is WinForms on .NET Framework.

## How it works (2017)

### Volcanic: the object IDE

`TSOClient/FSO.IDE` builds `Volcanic.exe`, a WinForms editor for objects
and SimAntics code. It runs the real game inside it:

1. [`Program.Main`](../TSOClient/FSO.IDE/Program.cs) loads the client
   assembly by reflection, finds `FSO.Client.GameStartProxy` (falling
   back to `Simitone.Windows.GameStartProxy`, from a separate TS1-focused
   project), and runs `FSOProgram.InitWithArguments`.
2. `VolcanicStartProxy.InitVolcanic` sets `IffFile.RETAIN_CHUNK_DATA` so
   edits can be diffed into PIFFs, sets `VM.SignalBreaks` so SimAntics
   errors become breakpoints, plugs in the sprite quantizer, and registers
   itself with `IDEHook.SetIDE`. The game then runs on the main thread.
3. When the client starts a lot (sandbox mode), it calls
   `IDEHook.IDE.StartIDE(vm)`. Volcanic starts a separate thread for its
   WinForms windows and attaches to that live VM.

Main parts:

| Area | Files | Purpose |
| --- | --- | --- |
| Object browser | `ObjectBrowser`, `ObjectWindow` | Browse objects by GUID and open their resources. |
| BHAV editor | `BHAVEditor`, `EditorComponent/` | Visual flowchart editor for SimAntics routines. Each primitive has a descriptor in `EditorComponent/Primitives/` that renders and edits its operand. Supports breakpoints and stepping in the running VM. |
| Resource browser | `ResourceBrowser/` | Edit IFF chunks: OBJD, DGRP, strings, sprites (SPR2 encoding in `Common/SpriteEncoderUtils`), and others. |
| Entity inspector | `EntityInspector` | Live view of a VM entity's state. |
| Change tracking | `Managers/IffEditManager`, `BHAVEditManager` | Track edits through `Content.Changes` (see [content.md](./content.md#editing-support)) and save them as PIFFs. |
| Embedded rendering | `FSOUIControl`, `Common/UIInteractiveDGRP`, `UIThumbnailRenderer` | Draw the game's MonoGame output inside WinForms controls. |

### Client debug tools

- **FSO.Debug** (`TSOClient/tso.debug`) is a WinExe with WinForms windows
  for SimAntics (`Simantics`, `ActionQueue`) and content browsing. The
  client references it as a project, and `UIDebugMenu`, `UIModMenu`, and
  `CoreGameScreen` use its types. `ActionQueue.cs` calls `user32.dll`
  `SendMessage` through P/Invoke. `Vitaboy.cs` isn't compiled.
- **FSO.UI `Debug/`** holds older WinForms tools (`TSOClientTools`,
  `TSOEdith`, `TSOSceneInspector`, and others) that are not compiled.

### Server debug tools

**FSO.Server.Debug** (`TSOClient/FSO.Server.Debug`) is a WinForms packet
inspector. `server run -d` opens its `NetworkDebugger`, which shows
Aries, Voltron, and Electron packets as they pass. Analyzers in
`PacketAnalyzer/` guess at unknown fields: Pascal strings, constants,
byte counts, and data definition structs (from `datadefinition.dat`).
It uses ScintillaNET and Be.Windows.Forms.HexBox.

### Patcher

**FSO.Patcher** (`TSOClient/FSO.Patcher`, assembly `update.exe`) is a
WinForms window that extracts `PatchFiles/patch.zip` over the client
folder, retrying locked files. It renames an incoming `update.exe` to
`update2.exe`, since it can't overwrite itself.

### FSOInstaller

`FSOInstaller/` is a WinForms wizard (.NET 4.5.2) that downloads the
original TSO files from EA's public mirror
(`http://largedownloads.ea.com/pub/misc/tso/`) using a manifest, then
unpacks them. **Unverified:** whether that mirror is still online.

### Charvatia

`Charvatia/` is a console program (.NET 4.5.2) that hosts one SimAntics VM
as a standalone server (`CVMInstance`, port 37564). It predates the
current `FSO.Server` lot server. It references `GonzoNet` and
`ProtocolAbstractionLibraryD` under `Other/libs/`, which no longer exist,
and the old `NetworkClient`/`PacketHandlers` API that the client no
longer compiles. It cannot build as-is.

### Other/libs

| Library | Used by | Notes |
| --- | --- | --- |
| `FSOMonoGame` (submodule, not checked out) | Everything graphical | FreeSO's MonoGame fork. See [rendering.md](./rendering.md#engine-choice). |
| `FSOMina.NET` (submodule, not checked out) | Protocol, servers, client | FreeSO's Mina.NET fork. See [protocol.md](./protocol.md#keep-the-wire-format-replace-the-plumbing). |
| `mp3sharp` | FSO.Common | Managed MP3 decoder (.NET 4.5). `ManagedDirectsoundDemo` beside it is a sample. |
| `TargaImage` | FSO.Content, FSO.Debug, FSO.UI, server | TGA loader on `System.Drawing`. A `VS2008/` copy targets .NET 2.0. |
| `TargaImagePCL` | FSO.Files | Portable TGA loader (PCL Profile 7). |
| `ColorQuantizer` | Volcanic | Palette quantization for sprite encoding. |
| `CityDataModel`, `LoginDataModel` | none in the solution | .NET 3.5 leftovers from Project Dollhouse. |

### Other/tools

Older standalone tools, none in `FreeSO.sln`. All are .NET 3.0 to 4.0,
and several need XNA Game Studio, which isn't available anymore.

| Tool | Framework | Purpose |
| --- | --- | --- |
| `CityRenderer` | 3.5, XNA | Early city map renderer prototype. |
| `FarExtractor` | 3.5 | Extract FAR archives. |
| `Iffinator` | 3.0 | IFF viewer built on `SimsLib`. |
| `SimsLib` | 4.0, XNA content pipeline | Early file format library, superseded by FSO.Files. |
| `TSO MeshViewer` | 3.5, XNA | Avatar mesh viewer built on `SimsLib`. |
| `XaToWav` | 3.5 | Convert XA audio to WAV. |
| `PDChat` | 3.5 | Project Dollhouse chat client. |
| `Mr. Shipper` | 4.0 | Builds a database of UI graphics files and their IDs. |
| `libfar` | C++ | A C FAR library and `FARDive` viewer, vendoring libpng and zlib. |

## Modern .NET rewrite

### What to keep

- **Volcanic** is valuable: it's the only way to read and edit SimAntics
  visually. It is also the hardest tool to port, because WinForms only
  runs on Windows. Options, in order of preference:
  1. **Rebuild it inside the game** as in-game panels using FSO.UI. It
     already embeds the game, so its rendering problems disappear, and it
     runs everywhere the client runs.
  2. **Avalonia UI** for a cross-platform desktop app, with MonoGame
     rendered to a texture and shown in an Avalonia control.
  3. **Keep WinForms on modern .NET** (`net10.0-windows`) as a
     Windows-only tool. It's the cheapest port, but it doesn't meet the
     cross-platform goal.
- **Server packet inspector**: replace the WinForms window with
  structured logging of packets (packet type and fields as log scope
  properties) plus a CLI that decodes captured traffic. That works over
  SSH on a Linux server, which a WinForms window can't.

### What to replace

- **Patcher and watchdog updater**: use the platform's packaging
  instead (an installer on Windows, AppImage or Flatpak on Linux, a
  signed app bundle on macOS), or a small cross-platform updater that
  verifies a signature before extracting. The 2017 patcher extracts any
  zip it finds without checking it.
- **FSOInstaller**: replace with a cross-platform CLI or a first-run
  screen in the client that downloads over HTTPS and verifies file
  hashes against the manifest.

### What to delete

- `Charvatia/` (superseded by the lot server; can't build).
- `Other/tools/` (superseded by FSO.Files and Volcanic; needs XNA).
- `CityDataModel`, `LoginDataModel`, the `TargaImage/VS2008` copy, and
  `ManagedDirectsoundDemo`.
- `FSO.Server.Framework` (only a placeholder class).
- The uncompiled WinForms tools in `FSO.UI/Debug`.

Deleting is a judgment call for the owner. Moving these to an archive
branch keeps the history without carrying them into the new solution.
