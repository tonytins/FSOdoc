# SimAntics: running object behavior

SimAntics is the virtual machine that runs The Sims Online's object behavior. Every object's
logic is a set of routines (`BHAV` chunks) built from primitives: compare and assign variables,
sleep, find another object, play a sound, and about 70 more. The port runs those routines tick by
tick and gets the same results as FreeSO's VM, which `fso-oracle` checks case by case.

What runs today: the VM core, entities and their entry points, creating and deleting objects
(multi-tile ones included), threads with subroutine calls and check threads, every variable scope
objects use, the scheduler and clock, and 8 of the 49 primitives TSO uses (Expression, Sleep,
Refresh, Random Number, Play Sound, Set To Next, Test Object Type, and Create Object Instance).
2,597 objects created alone on an empty lot match FreeSO's state tick for tick over 30 ticks. Sims,
routing, placement, slots, and lot loading come later; see the
[roadmap](../roadmap.md). The lot model (positions, walls, and rooms) has its own page,
[lot.md](lot.md).

## The VM

A `VM` is one running lot (FreeSO's `VM` and `VMContext`). It owns the entities, the 38 global
values, the clock, the random generator, the scheduler, the primitive table, and the
architecture. It reads code through a `GameContent`.

```swift
import SimAntics
import TSOContent

let content = try GameContent(.init(gameDirectory: install, freeSOContentDirectory: freeSOContent))
let vm = try VM(content: content, seed: 0x0F50_D0C5_EED0_0001)

guard let door = try vm.createObject(guid: 0x0000_01CA)?.leadObject else { return }  // nil: no such object
for _ in 0..<30 { vm.tick() }      // one second of game time

print(door.objectData[0...3], vm.reportedErrors)
print(StateDigest.hex(of: vm))     // compare with fso-oracle's digest for the same run
```

`createObject(guid:)` works as FreeSO's `CreateObjectInstance` does; see
[Creating and deleting objects](#creating-and-deleting-objects) below.

Each `tick()` follows `VM.InternalTick`:

1. The scheduler starts the tick (tick IDs start at 1).
2. The clock advances: 150 ticks make a game minute, 30 ticks a real second (`TickRate.perSecond`).
3. Globals 6, 5, 0, and 4 get the clock's seconds, minutes, hours, and time of day.
4. If walls or floors changed, rooms are regenerated and every entity's room is updated ([lot.md](lot.md)).
5. The scheduled entities run, in object ID order.
6. The random seed advances by the number of entities, as FreeSO does so desynced clients drift apart quickly.

## Entities

An `Entity` is an object on the lot (FreeSO's `VMEntity` and `VMGameObject`). It holds:

| Property | What it is |
| --- | --- |
| `objectID` | Its ID on the lot; entities are always kept in ID order |
| `object` | Its `GameObject`: definition and files |
| `objectData` | The 80 object data values, read through the `myObject` and `stackObject` scopes (see `ObjectVariable` for their names) |
| `attributes` | Per-object attributes; grow with zeros on any access past the end, as in FreeSO |
| `list` | The entity's list, for the push and pop operators |
| `position`, `direction` | Where it is and which way it faces ([lot.md](lot.md)) |
| `container`, `slot(_:)` | The object it's in, and what each of its container slots holds ([lot.md](lot.md#slots-and-containment)) |
| `entryPoints` | The routines for init, main, load, cleanup, and the rest, from the `OBJD` or its `OBJf` |
| `thread` | Its interpreter |

Each entity belongs to a `MultitileGroup` (`group`): the parts of one object. Most objects are
a group of one; a multi-tile object (a two-tile bed, a long counter) is one entity per part.
`leadObject` is the part that leads the group, and the lead-tile attribute scopes read through it.

Writing some object data has side effects, as in FreeSO. Writing the direction snaps it to the
object's rotation step (data 23); writing the category moves it in the category index; lockout
counts down. Use `setValue(_:of:)` for writes that should behave that way, and `objectData`
directly only to set up state.

```swift
try door.setValue(3, of: ObjectVariable.direction.rawValue)
let ranImmediately = try door.executeEntryPoint(.load, runImmediately: true)
door.reset()                       // clears the stack, runs cleanup, queues main
```

## Creating and deleting objects

`VM.createObject(guid:at:facing:mainStackObjectID:mainParameter:)` follows FreeSO's
`CreateObjectInstance`:

1. A multi-tile **master** definition (a master ID, and a sub-index of -1) creates one entity per
   part: each definition in the master's file with the same master ID, in file order. Each part
   keeps the master definition (`masterDefinition`), and its offset in the group comes from its
   sub-index (x tile in the high byte, y in the low byte) and level offset. Anything else creates
   one entity.
2. Each entity gets the **lowest free object ID**, so IDs freed by deletion are reused.
3. Each entity is **initialized** in turn: it's scheduled for the next tick, its init entry point
   runs to completion, and `main` is queued, with argument 0 and the stack object that the creator
   passed. An object whose definition doesn't allow the lot's category is disabled.
4. The group is **placed** with `VM.place` ([lot.md](lot.md#placing-objects)). An object that
   doesn't fit stays out of the world.

```swift
if let table = try vm.createObject(guid: tableGUID) {        // a multi-tile master
    print(table.isMultiTile, table.objects.map(\.objectID))   // true [2, 3]
    print(table.offsets)                                      // each part's offset from the group
}
```

`VM.delete(_:wholeGroup:)` takes an entity (or every part of its object) off the lot: out of the
entity list, the queries, and the schedule, and its ID is free again. While entities are running,
deletion waits until the tick ends, after the random seed has counted the entity. What the object
held leaves its slots and is placed nearby (or out of the world, if the object was). That's how
FreeSO deletes an object whose routines fail twice within 10 ticks, and the port does the same.

## Threads and routines

Each entity's `VMThread` keeps a stack of `StackFrame`s; the last one runs. A `Routine` is a
`BHAV` with every operand decoded once (FreeSO's `VMRoutine`). `thread.tick()` runs instructions
until one yields:

- **Primitives** (opcodes below 256) run and return an `ExitCode`: go to the true or false
  branch now or next tick, return, continue on a future tick (sleeping), or interrupt.
- **Branch targets** are instruction indexes, or 254 (return true), 255 (return false), and 253
  (follow whichever branch isn't 253).
- **Subroutine calls** (256 and up) push a new frame: 256–4095 call the global, 4096–8191 the code
  owner's own file, 8192 and up its semi-global. Arguments of -1 can pick temp registers.
- **When the stack empties,** the thread pushes `main` again on its next tick.

A routine can be built by hand, which is how the tests check the interpreter:

```swift
let addOne = Primitives.Expression.Operand(Variable(.temps, 0), .plusEquals, .literal(1))
let routine = Routine(id: 4096, instructions: [
    Instruction(index: 0, opcode: 2, truePointer: 254, falsePointer: 255,
                operand: PrimitiveTable.standard.decode(opcode: 2, operand: addOne.encoded())),
])
door.thread.push(StackFrame(thread: door.thread, routine: routine, caller: door, callee: door,
                            codeOwner: door.object))
door.thread.tick()
print(door.thread.tempRegisters[0], door.thread.lastExitCode)   // 1 returnTrue
```

**Check threads.** Entry point conditions and interaction tests run as check threads:
`VMThread.evaluateCheck(entity:frame:)` runs a routine to completion on a temporary thread and
returns how it exited. While the scheduler is running, a check shares its entity's temps; outside
it works on a copy.

**Errors.** A routine that fails throws a `SimAnticsError`. The thread reports it (at most once
every 600 ticks, as FreeSO's dialog cooldown does), then resets the frame's caller and callee. More
than 500,000 instructions in one tick fails as an infinite loop.

| `SimAnticsError` | FreeSO equivalent |
| --- | --- |
| `simantics(_:)` | `VMSimanticsException` |
| `indexOutOfRange(_:)`, `nullReference(_:)`, `invalidCast(_:)`, `overflow(_:)` | the .NET exception of the same name |
| `infiniteLoop` | the instruction limit |
| `content(_:)` | content that couldn't load |
| `unsupported(_:)` | nothing: behavior not ported yet |

`unsupported` never stands for a FreeSO failure, so tests can tell a gap in the port from a
behavior that matches. An unported primitive throws it when it runs; it never silently takes a
branch. Opcodes FreeSO itself has no implementation for take the true branch, as they do there.

## Variables

Primitives read and write values through a `Variable`: a scope and a data value, usually an index
(temp 3, attribute 7) and for literals the value itself. Frames resolve them; inside a primitive,
`frame` is the frame running it:

```swift
let value = try frame.value(of: Variable(.myObject, ObjectVariable.direction.rawValue))
_ = try frame.setValue(42, of: Variable(.temps, 0))
let big = try frame.bigValue(of: Variable(.tempXL, 0))      // 32-bit; only TempXL holds more than 16 bits
```

Every scope objects use is ported: temps and TempXL, parameters and locals, globals, object data
and attributes of the caller, stack object, and others, lists, definition fields, the clock, entry
points, tuning, room data, and container slots. Each scope either behaves as in FreeSO, fails as
FreeSO does, or throws `unsupported` (anything only Sims have).

**Tuning** (`Variable(.tuning, …)`) picks a table with the top 9 bits of the data and a key with
the low 7. Tables 0–63 are the code owner's, 64–127 its semi-global's, and 128–191 the global's.
Each looks in a `BCON` first, then an OTF table; nothing found reads as 0.

## Primitives

A primitive is a type conforming to `Primitive`: a name, an opcode, an `Operand` that decodes the
instruction's 8 bytes (and encodes them back), and a static `execute` that changes the VM and
returns an exit code. Primitives hold no state. `PrimitiveTable.standard` registers the ported
ones; FreeSO's names of all 49 TSO primitives are in `PrimitiveTable.fsoCompat`.

| Opcode | Primitive | What it does |
| --- | --- | --- |
| 0 | `Sleep` | Waits a number of ticks held in an argument |
| 2 | `Expression` | Compares, assigns, does arithmetic and flag operations, pushes and pops lists |
| 7 | `Refresh` | Refreshes graphics, lighting, or room score (headless: changes nothing yet) |
| 8 | `RandomNumber` | Draws a number below a limit into a variable |
| 16 | `FindLocationFor` | Places the stack object near a reference, out of the world, or along a facing |
| 23 | `PlaySound` | Plays a sound event (headless, as on FreeSO's server: changes nothing) |
| 31 | `SetToNext` | Finds the next object, by ID, GUID, category, tile, or neighbor |
| 32 | `TestObjectType` | Tests whether an object has a GUID |
| 42 | `CreateObjectInstance` | Creates an object beside, in front of, or under another, and makes it the stack object |

A VM can run its own table, which is how extensions will add primitives without touching the
ported ones:

```swift
enum Nudge: Primitive {
    static let name = "nudge"
    static let opcode: UInt8 = 200                        // an opcode TSO doesn't use

    struct Operand: PrimitiveOperand {
        var amount: Int16
        init(bytes: [UInt8]) { amount = Int16(bytes[0]) | Int16(bytes[1]) << 8 }
        func encoded() -> [UInt8] { [UInt8(truncatingIfNeeded: amount), UInt8(truncatingIfNeeded: amount >> 8), 0, 0, 0, 0, 0, 0] }
    }

    static func execute(_ operand: Operand, in frame: StackFrame) throws(SimAnticsError) -> ExitCode {
        let current = try frame.value(of: Variable(.temps, 0))
        _ = try frame.setValue(current &+ operand.amount, of: Variable(.temps, 0))   // wrap, as 16-bit SimAntics does
        return .gotoTrue
    }
}

var table = PrimitiveTable.standard
table.register(Nudge.self)
let custom = try VM(content: content, seed: 1, primitives: table)
```

## Scheduling, the clock, and randomness

- **`VMScheduler`** runs the entities scheduled for each tick in object ID order. An entity that
  doesn't schedule itself while running is scheduled for the next tick; a sleeping one is
  scheduled further ahead and skipped until then.
- **`VMClock`** counts ticks, minutes, and hours; time of day is always 0, as in FreeSO.
- **`VMRandom`** is FreeSO's xorshift64* generator. `next(below:)` draws from 0 up to a limit; a
  limit of 0 returns 0 without advancing. Every client must draw the same numbers in the same
  order, so only primitives draw, in the order FreeSO does.

## Comparing with FreeSO

`StateDigest.hex(of:)` hashes the VM state (seed, entities, positions, object data, stacks) the
same way `fso-oracle run-objects` and `run-lot` do. Equal digests after the same ticks mean the
two VMs agree. This is how the 2,597 single-object runs are checked; when a run differs, the first
tick whose digest differs points at the problem.
