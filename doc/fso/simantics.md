# FSO.SimAntics: the simulation VM

FSO.SimAntics (`TSOClient/tso.simantics`) reimplements SimAntics, the
bytecode virtual machine that runs every object and Sim in The Sims and
The Sims Online. The behavior itself is the original game's code (BHAV
chunks in the IFF files). FreeSO supplies the interpreter, the primitives,
the lot model, and a lockstep multiplayer layer. Both the client and the
lot server run this same library.

It depends on [FSO.Files](./files.md), [FSO.Content](./content.md),
[FSO.LotView](./rendering.md) (the VM drives world rendering objects
directly), FSO.Vitaboy, [FSO.HIT](./audio.md), and Mina.NET.

## How it works (2017)

### Main types

| Type | Role |
| --- | --- |
| [`VM`](../../TSOClient/tso.simantics/VM.cs) | One running lot. Owns the entities, the global state array, the scheduler, the network driver, and events the UI listens to (dialogs, chat, EOD messages, lot switching). |
| [`VMContext`](../../TSOClient/tso.simantics/VMContext.cs) | The lot's world: the primitive table, the clock, architecture, room map, object placement and collision queries, and the deterministic random number generator. |
| [`VMArchitecture`](../../TSOClient/tso.simantics/VMArchitecture.cs) | Walls, floors, terrain, and rooms per level, mirrored into the LotView `Blueprint`. |
| [`VMEntity`](../../TSOClient/tso.simantics/entities/VMEntity.cs) | Base for everything on the lot: object data, attributes, flags, relationships, a `VMThread`, and its world component. |
| [`VMGameObject`](../../TSOClient/tso.simantics/entities/VMGameObject.cs), [`VMAvatar`](../../TSOClient/tso.simantics/entities/VMAvatar.cs) | Objects and Sims. Avatars add motives, animation, outfits, and skills. |
| [`VMMultitileGroup`](../../TSOClient/tso.simantics/entities/VMMultitileGroup.cs) | Ties the tiles of a multi-tile object together for moving and deleting. |
| [`VMThread`](../../TSOClient/tso.simantics/engine/VMThread.cs) | Per-entity interpreter: a stack of `VMStackFrame`s and the action (interaction) queue. |
| [`VMScheduler`](../../TSOClient/tso.simantics/Engine/VMScheduler.cs) | Decides which entities run on which tick. |

### Ticks and timing

The VM runs at 30 ticks per second. `VM.Update` is called once per frame
(the game's refresh rate, usually 60 Hz) and runs as many ticks as the
elapsed time and `SpeedMultiplier` require. `Fraction` is kept for
rendering interpolation between ticks.

A tick in single-player still goes through the network driver:
`VM.Tick` asks the driver for the next tick, and the driver calls
`VM.InternalTick`. `InternalTick` advances the clock, copies time of day
into the global state array, ticks the architecture, then runs the
scheduler. With `VM.UseSchedule` (the default) only entities scheduled for
that tick run. Entities that are sleeping or waiting on routing stay idle
until their wake tick.

### Executing behavior

BHAV code is assembled on first use into a `VMRoutine` by
[`VMTranslator`](../../TSOClient/tso.simantics/engine/translator/VMTranslator.cs),
which decodes each instruction's operand once. `VM.Assemble` caches
routines, and `BHAVChanged` clears the cache when the IDE edits code.

`VMThread.Tick` runs instructions on the top stack frame until one
yields. For each instruction:

- Opcodes 256 and up are subroutine calls. 256 to 4095 call the global
  IFF, 4096 to 8191 call the object's own IFF, and 8192 and up call its
  semi-global.
- Opcodes below 256 are primitives, looked up in `VMContext.Primitives`.
  Each primitive returns a `VMPrimitiveExitCode`: go to the true or false
  branch, return true or false from the routine, continue next tick, or
  error.

Unknown primitives take the true branch. An `ERROR` result unwinds the
whole stack. A .NET exception thrown inside a thread (including the
infinite-loop guard at 500,000 instructions per tick) is caught in
`VMThread.Tick`, shown as a "SimAntics Exception" dialog at most once
every 20 seconds, and the entity is reset. A game object that keeps
failing inside that window is deleted instead.

Primitives live in [`primitives/`](../../TSOClient/tso.simantics/primitives/),
one class each, registered in the `VMContext` constructor with their
opcode and operand type. They cover expressions (`VMExpression`, the
most-used one), animation, routing (`VMGotoRoutingSlot`,
`VMGotoRelativePosition`), object creation, dialogs, sound, relationships,
motives, money (`VMTransferFunds`), inventory, the TSO-specific
`VMGenericTSOCall`, and their TS1 equivalents.

Variables are read and written through
[`VMMemory`](../../TSOClient/tso.simantics/engine/VMMemory.cs), which maps a
`VMVariableScope` (params, locals, attributes, globals, object data,
tuning, and others) to storage. Tuning reads a BCON, falling back to an
OTF table (see [files.md](./files.md#patching-with-piff-and-otf)).

### Interactions and routing

The pie menu offers interactions from each object's `TTAB`.
`VMThread.CheckAction` runs their check trees. Choosing one queues a
`VMQueuedAction`, and the thread pushes the action's BHAV when it reaches
the front of the queue, respecting priorities and interruption.

Movement is handled by
[`VMRoutingFrame`](../../TSOClient/tso.simantics/engine/VMRoutingFrame.cs),
a special stack frame that plans a path with
[`VMRectRouter`](../../TSOClient/tso.simantics/engine/Routing/VMRectRouter.cs)
(free rectangles grown from obstacles) and walks the Sim along it,
handling doors, blocked paths, and failure trees.

### Platform state and the global link

The VM separates the lot from the outside world:

- `VMTSOLotState`, `VMTSOAvatarState`, and `VMTSOObjectState` in
  [`Model/TSOPlatform/`](../../TSOClient/tso.simantics/Model/TSOPlatform/)
  hold TSO-only state: roommates and permissions, budgets, jobs, and lot
  size.
- [`IVMTSOGlobalLink`](../../TSOClient/tso.simantics/Engine/TSOGlobalLink/IVMTSOGlobalLink.cs)
  is how the VM reaches persistent data: money transfers, object
  persistence, relationships, and plugin data. The lot server implements
  it against the database (`LotServerGlobalLink`, see [server.md](./server.md)).
  [`VMTSOGlobalLinkStub`](../../TSOClient/tso.simantics/Engine/TSOGlobalLink/VMTSOGlobalLinkStub.cs)
  is the offline version for sandbox mode, optionally backed by
  `VMTSOStandaloneDatabase`.

### Multiplayer: deterministic lockstep

Every client simulates the whole lot. The server only orders inputs:

1. A client action (interact, buy, move, chat) becomes a
   `VMNetCommandBodyAbstract` subclass in
   [`NetPlay/Model/Commands/`](../../TSOClient/tso.simantics/NetPlay/Model/Commands/).
   [`VMClientDriver`](../../TSOClient/tso.simantics/NetPlay/Drivers/VMClientDriver.cs)
   serializes it and raises `OnClientCommand` with the bytes. The client's
   lot connection sends them to the lot server.
2. [`VMServerDriver`](../../TSOClient/tso.simantics/NetPlay/Drivers/VMServerDriver.cs)
   collects commands, assigns them to the next tick with the current
   random seed, runs the tick itself, and broadcasts ticks in batches of
   four (`TICKS_PER_PACKET`) through its `OnTickBroadcast` event.
3. Each client executes the same commands on the same tick. Before each
   tick, `VMNetDriver.InternalTick` compares its random seed with the
   server's. A mismatch means the simulation has diverged, so the client
   sends `VMRequestResyncCmd`, and the server answers with a
   `VMStateSyncCmd` holding a full save state.

Determinism is therefore a hard rule: VM code must not use wall-clock
time, unordered collections where order affects results, floating point
that differs by platform, or any randomness except `VMContext.NextRandom`.
`VMSyncTrace` (under `Engine/Debug`) and the `VM_DESYNC_DEBUG` symbol
exist to trace divergence.

Sandbox mode (`SandboxGameScreen` in the client) runs `VMServerDriver`
in-process with a stub global link and one local client.

### Saving: marshals

[`Marshals/`](../../TSOClient/tso.simantics/Marshals/) converts VM state to
and from a binary form with `BinaryWriter` and `BinaryReader`, through the
`VMSerializable` interface. `VM.Save` produces a `VMMarshal` (context,
entities, threads, multitile groups, global state, platform state) at
`LATEST_VERSION = 19`. Readers branch on the version, so older saves still
load. This one format serves lot saves on the server, resync snapshots,
and sandbox saves. `HollowSave` writes a reduced form (`hollow.fsoh`) that the lot server
saves next to each full state (`state_N.fsov`).
`VMLotTerrainRestoreTools` loads neighboring lots' hollow states to draw
surrounding lots.

### EODs (plugins)

EODs ("Electronic Online Dialogs") are TSO's object minigames and job
UIs. An object calls the Invoke Plugin primitive, and
[`VMEODHost`](../../TSOClient/tso.simantics/NetPlay/EODs/VMEODHost.cs) and
`VMEODServer` route events between the object, the server-side handler,
and each client's UI panel. Handlers live in
[`NetPlay/EODs/Handlers/`](../../TSOClient/tso.simantics/NetPlay/EODs/Handlers/):
band, dance floor, dresser, card draw, paper chase, pizza maker, racks,
scoreboard, signs, slots, timer, trunk, war game, and permission doors.
Their client panels are in `tso.client/UI/Panels/EODs/`.

### Other pieces

- `utils/VMWorldActivator` builds a VM from an XML house, and
  `VMTS1Activator` from a TS1 house IFF.
- `utils/VMArchitectureTools` (wall and floor tools), `VMLotRotate`, and
  `Utils/VMLotTerrainRestoreTools` support build mode and lot moves.
- `Entities/VMAvatarMotiveDecay` and `VMTS1MotiveDecay` model motive decay
  for each game.

### Dead and case-split files

The project has both upper- and lower-case folders (`Engine`/`engine`,
`Entities`/`entities`, `Model`/`model`, `Utils`/`utils`).
`engine/VMRouteFinder.cs` isn't compiled.

## Modern .NET rewrite

### Target

`FSO.SimAntics` as a `net10.0` library. It is the heart of both client
and server, so the rewrite must keep two things exact: the behavior of
every primitive (because the game's BHAV code depends on it) and
lockstep determinism.

### Decouple from rendering

The VM holds LotView objects directly (`VMEntity.WorldUI`,
`VMContext.World`). A headless lot server still constructs world
components. Introduce a narrow interface (for example
`IEntityPresentation` with position, direction, and animation updates)
that the client implements with LotView and the server implements as a
no-op. The SimAntics library then no longer references MonoGame.

### Determinism checks

- **Floating point.** Modern .NET uses SSE or AVX everywhere and is far
  more consistent than 2017's x87 JIT on 32-bit Mono, but results can
  still differ across ARM64 and x64 for some math functions. List every
  `float`/`double` use in VM logic (routing and animation timing are
  likely places) and move them to fixed-point or integer math, or confirm
  they don't feed back into simulation state.
- **Collections.** Iterating a `Dictionary` or `HashSet` is
  insertion-ordered in practice but not guaranteed. Anything that affects
  results should iterate a list or a sorted collection.
- **Tests.** Add replay tests: record a save state plus a command stream,
  run it, and compare the final `VMMarshal` bytes and random seed. Run
  them on Windows, Linux, and macOS in CI, on both x64 and ARM64. This is
  the single most valuable test suite for the rewrite.

### Code changes

- **Primitive registry.** Keep one class per primitive. Register them in
  a table and give each an `Execute(VMStackFrame, in TOperand)` with a
  struct operand to avoid per-instruction allocation.
- **Serialization.** Keep the binary marshal format and its version
  number, so existing server saves still load. Wrap `BinaryReader` reads
  with length checks, because resync and save data arrive from the
  network.
- **Lockstep transport.** The drivers already produce `byte[]` and raise
  events. Keep that shape. Have the transport (see [protocol.md](./protocol.md))
  deliver bytes through `System.Threading.Channels` and drain them on the
  game thread.
- **Global link.** Make `IVMTSOGlobalLink` asynchronous (`Task`-returning)
  with results applied on a later tick, which is how the lot server
  already treats it. That fits `async` database access cleanly.
- **Folder casing.** Merge the case-split folders and delete the
  uncompiled `VMRouteFinder.cs`.

### Compatibility warning

Changing primitive behavior, the random number generator, the tick rate,
or the marshal format breaks compatibility with existing lot saves and
with any client running the 2017 code. Treat each of those as a breaking
change and version it.
