# SimAntics oracle

`fso-oracle` runs FreeSO's 2017 SimAntics VM headless on modern .NET, to produce
reference results for the Swift port (roadmap decision 2, the West Darrington
milestone). It compiles the 2017 SimAntics, Files, Content, LotView, HIT, and
Vitaboy sources unchanged: `SnapshotSources.props` links them read-only from
`TSOClient/`, and nothing under `TSOClient/` is ever edited.

## Running it

```sh
dotnet run --project NSOClient/Oracle -c Release -- run-lot --ticks 1800 --every 300
```

It reads the game from `TSO_GAME_DIR` (or `--game`), loads a lot from blueprint XML
(FreeSO's `empty_lot_fso.xml` by default), ticks it, and prints one line per digest:

```text
tick 0 seed 0f50d0c5eed00001 entities 12 digest daa28213a5e94dc0fc7678d346b6f691998fae08a839aadfe49d795303d78700
```

The 2017 code also prints its own diagnostics to standard output (such as
`Failed to get Object ID`), so only lines starting with `tick` are results.

Options: `--game`, `--content` (FreeSO's `Content` folder), `--blueprint`,
`--ticks`, `--every`, and `--seed`. Run without arguments for help.

Runs are repeatable: the same install, blueprint, seed, and tick count give the
same digests.

## The state digest (version 0)

SHA-256 over little-endian values, in this order:

1. the VM's random seed (64 bits);
2. the entity count (32 bits);
3. for each entity, in object ID order:
   object ID (16), object GUID (32), tile x (16), tile y (16), level (8),
   direction (8), the object data count (32) and values (16 each), the thread's
   stack depth (32), then each frame's routine ID (16) and instruction pointer (16).

The Swift port must compute the same digest from the same state. Fields will be
added in later versions; bump the version when they are.

## How it stands in for the 2017 build

Four kinds of help, each kept as small as possible:

| Part | Why |
| --- | --- |
| `Stubs/MinaIoBuffer.cs` | A working `IoBuffer` with the members the sources call. FreeSO's Mina.NET fork isn't checked out. |
| `Stubs/MonoGameFork.cs` | C# 14 extension members for what stock MonoGame 3.8 lacks: XNA 4.0's `Color.TransparentBlack` and the fork's `RenderTarget2D.InheritDepthStencil`. |
| `Stubs/GlobalUsings.cs` | Resolves `Color` to XNA's, which the 2017 build saw without ambiguity. |
| `Stubs/Ninject.cs`, `Stubs/MP3Player.cs` | Names the VM never uses at run time. |

Two files are left out (`Base64JsonConverter.cs`, `MP3Player.cs`) because they need
libraries the oracle doesn't reference. Stock MonoGame DesktopGL supplies the XNA
types; no window or graphics device is ever created.

## Older installs: the game overlay

FreeSO was built against TSO's 2003 production files. An older install, such as the
2002 beta, lacks some files and has a different shape for others, and the 2017
content system stops on both. `GameOverlay` builds a temporary folder of links to
the install, adds placeholders or adapted copies only where needed, and reports
each one on standard error:

- empty sound groups for `relationships`, `tsov3`, and `turkey` (the VM runs
  without audio);
- empty wall and floor expansion archives (`walls2` to `walls4`, `floors2` to
  `floors4`);
- `packingslips/objecttable.xml` and `catalog.xml` copies with display names
  filled in from file names, since the beta's tables have none;
- blueprint objects the install doesn't have are left out of the lot.

The install is never written to. The 2017 code's user data (such as the sandbox
ban list) goes to a scratch folder inside the overlay, which is deleted on exit.

## Keeping it current

If the list of 2017 projects or their files changes, regenerate the source list:

```sh
python3 -I NSOClient/Oracle/generate_sources.py
```

AGENTS.md allows `dotnet` for this project only.
