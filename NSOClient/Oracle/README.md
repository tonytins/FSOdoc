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

Standard output carries only results. The 2017 code's own messages (such as
`Failed to get Object ID`) are sent to standard error.

Options: `--game`, `--content` (FreeSO's `Content` folder), `--blueprint`,
`--seed`, and for `run-lot`, `--ticks` and `--every`. Run without arguments for help.

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

## Single primitives: `run-primitive` (protocol version 1)

```sh
dotnet run --project NSOClient/Oracle -c Release -- run-primitive < requests.jsonl
```

Loads the same lot as `run-lot`, then reads JSON requests from standard input, one
per line, and writes one JSON response per line. Blank lines and lines starting
with `#` are skipped. Each request runs on a freshly loaded lot, so requests never
see each other's effects. [Examples/expression.jsonl](Examples/expression.jsonl)
has annotated examples.

The oracle calls the primitive's 2017 handler directly, the way
`VMThread.ExecuteInstruction` does. The handler runs on a one-instruction routine
whose frame is pushed onto the caller's thread, with the caller as the callee and
code owner. The oracle reports the exit code but doesn't act on it: no branching
and no scheduling.

Request fields (only `opcode` is required; unknown fields are rejected):

| Field | Meaning | Default |
| --- | --- | --- |
| `id` | any JSON value, echoed back | none |
| `opcode` | primitive opcode, 0 to 255 | |
| `operand` | operand bytes as in the BHAV, hex, up to 8 bytes; padded with zeros | all zeros |
| `caller` | object ID of the caller | the lowest object ID on the lot |
| `stackObject` | stack object ID | 0 (none) |
| `seed` | the VM's random seed, hex | `--seed` |
| `temps`, `tempXL` | up to 20 temps and 2 extended temps; the rest are 0 | all 0 |
| `locals`, `args` | the frame's locals and arguments | none, and four 0 arguments |
| `globals` | `{"index": value}` to set before running | |
| `objects` | `{"objectID": {"data": {"index": value}, "attributes": {"index": value}}}` to set before running | |

Response fields:

| Field | Meaning |
| --- | --- |
| `protocol`, `id` | the protocol version (1) and the request's `id` |
| `primitive` | the 2017 primitive's name |
| `exit` | the exit code name, such as `GOTO_TRUE` or `CONTINUE_NEXT_TICK` |
| `exception` | instead of `exit`, if the handler threw: `Type: message` (2017 resets the thread when this happens) |
| `noPrimitive` | `true` if 2017 has no primitive for the opcode; it then counts as `GOTO_TRUE` |
| `temps`, `tempXL`, `locals`, `args`, `stackObject`, `seed` | the values after running |
| `frames` | stack frames from the request's frame up; more than 1 means the primitive pushed one |
| `globals` | `{"index": value}` for each global the primitive changed |
| `objects` | for each object the primitive changed: changed `data` and `attributes` entries, and the new `position` (`[x, y, level]`) and `direction` |
| `created`, `removed` | object IDs added to or taken off the lot |
| `requestError` | instead of all of the above, if the request couldn't be run, such as malformed JSON or an object not on the lot |

`objects` and `globals` hold only the primitive's effects: the requested state is
applied first, and the difference is taken from there.

[check_protocol.py](check_protocol.py) runs the examples and checks the answers. It's
a regression check for the oracle itself; run it after changing the oracle:

```sh
python3 -I NSOClient/Oracle/check_protocol.py
```

Responses depend on the install, so generated answer files must not be committed.

Not covered yet: avatars (the default lot has none, so person data, motives, and
relationships can't be tested), and state outside the fields above, such as
contained objects and object lists.

## Content: `list-objects`

```sh
dotnet run --project NSOClient/Oracle -c Release -- list-objects > objects-2017.tsv
TSO_ORACLE_OBJECTS=$PWD/objects-2017.tsv swift test --package-path NSOClient/TSOContent
```

Loads every object registered at startup through the 2017 content system and prints one
tab-separated line per GUID, sorted by GUID:

| Result | Fields after the GUID (8 hex digits) |
| --- | --- |
| loaded | the `OBJD` label, the resource name, the semi-global (lower-case file name without extension, or `-`), the number of routines by name, the number of BHAVs, and the number of tuning tables |
| no `OBJD` with the GUID | `missing` |
| loading threw | `error` and the exception type; the full exception goes to standard error |

The TSOContent real-install tests compare each line with the Swift content system when
`TSO_ORACLE_OBJECTS` names the file. The output depends on the install, so don't
commit it.

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
