# `lot-serialize`: saving a running lot (October 2015)

**Status:** merged; part of the snapshot. The branch's tip is the merge of pull request #5
(`ide-work`) on October 16, 2015.

## What it added

The branch's main commit, "Lot serialization" (October 11, 2015, RHY3756547), made it possible to
save the complete state of a running VM and restore it. Before this, a lot could only be rebuilt
from its blueprint XML, which loses everything that was happening on it.

It introduced the **marshal layer**, `tso.simantics/Marshals/`: one plain data class per piece of
VM state, each able to write itself to and read itself from a binary stream.

| Marshal | Saves |
| --- | --- |
| `VMMarshal` | The whole VM: context, entities, multi-tile groups, globals |
| `VMContextMarshal` | The architecture, clock, random seed, and other context state |
| `VMArchitectureMarshal` | Walls, floors, and terrain |
| `VMEntityMarshal`, `VMGameObjectMarshal`, `VMAvatarMarshal` | Object data, attributes, position, relationships; for Sims, motives, person data, animations |
| `VMMultitileGroupMarshal` | Which entities form one multi-tile object |
| `VMThreadMarshal`, `VMStackFrameMarshal`, `VMRoutingFrameMarshal`, `VMQueuedActionMarshal` | Each entity's running routines, routing in progress, and interaction queue |
| `VMAnimationStateMarshal` | Animations in progress |

Each live class gained `Save()` and `Load()` methods to convert to and from its marshal, which is
why the commit touched nearly every VM type (`VMEntity`, `VMAvatar`, `VMThread`, `VMStackFrame`,
`VMRoutingFrame`, `VMArchitecture`, `VMClock`, `VMContext`, and more).

On top of it came **state sync** for multiplayer: `VMStateSyncCmd` sends a full serialized lot to a
client, and `VMServerDriver` uses it so a joining or desynced client can catch up to the server's
state instead of replaying every command since the lot started.

## The rest of the branch

- **Volcanic's beginnings** (`ide-work`): the first `FSO.IDE` project, with a BHAV tree viewer
  (`BHAVViewComponent`, `BHAVViewEngine`), TPRP-based parameter names, special naming for person
  data and constants, and `MGWinFormsControls`, a library for drawing MonoGame inside WinForms.
- Smaller fixes from the same weeks: the Suit primitive, an initial `kTurnOnTV`, stereos and
  mailboxes no longer crashing, input zeroed while the window is inactive.

## In the snapshot

The marshal layer is how FreeSO's lot server saves lots (`.fsov` files) and how clients resync.
See [simantics.md](../simantics.md) for how the snapshot uses it. NSOClient's state digest covers
far less (IDs, positions, object data, stacks); a saved-lot format compatible with these marshals
would be needed to load lots saved by FreeSO servers.
