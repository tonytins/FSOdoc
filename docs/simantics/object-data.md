# Object Data

> From the SimAntics Wiki ([Object Data](https://simantics.wikidot.com/wiki:object-data)), retrieved 2026-10-16, by its contributors, under
> [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Converted to Markdown and lightly
> edited; sections headed "Notes for NSOClient" are ours. See [README.md](README.md).

**Object Data** is an objects' built in fields such as which graphic is displaying or how dirty the object is. There are 80 in total, and each can be accessed by SimAntics via a [Scope](scopes.md). The relevant fields are usually set in the object's init function. NOTE: People also have object data, though some fields will not function for them.

## Object Data Entries

| id | name | notes |
|---|---|---|
| 0 | Graphic | This number should be added to OBJD.BaseGraphicID to calculate the DGRP ID when refreshing the graphic. |
| 1 | Direction | 0-7 in steps of 45 degrees clockwise, where 0 is facing the road (north) |
| 2 | Container ID | The object that contains this one. |
| 3 | Slot Number | The slot of the Container object that this object is contained in. |
| 4 | Allowed Height Flags |  |
| 5 | Wall Adjacency Flags |  |
| 6 | Route ID |  |
| 7 | Room Impact |  |
| 8 | Flags |  |
| 9 | Route Preference |  |
| 10 | Route Penalty |  |
| 11 | Object ID | This object's ID. |
| 12 | Target ID | Seems to be set for "Pickup from slot" entry point, most likely set to the object in question. |
| 13 | Wall Placement Flags |  |
| 14 | Slot hier number |  |
| 15 | Repair State |  |
| 16 | Light Source |  |
| 17 | Walk Style | 0 = walk, 1 = run, 2 = leave lot |
| 18 | Sim Age | Unused. The field in Person Data is used for this. |
| 19 | Unused Gender | Unused. |
| 20 | Tree Table Entry |  |
| 21 | Birth Minute |  |
| 22 | Speed |  |
| 23 | Rotation Notches |  |
| 24 | Birth Hour |  |
| 25 | Lockout Count | If this is >0, the object is not considered by the Find Best Object for Function primitive. Decrements once every tick until 0. |
| 26 | Parent ID |  |
| 27 | Weight |  |
| 28 | Support Strength |  |
| 29 | Room |  |
| 30 | Room Placement |  |
| 31 | Prep Value |  |
| 32 | Cook Value |  |
| 33 | Surface Value |  |
| 34 | Hidden | 0: Object is visible, 1: Object is hidden |
| 35 | Temperature |  |
| 36 | Dispose Value |  |
| 37 | Wash Dish Value |  |
| 38 | Eating Surface Value |  |
| 39 | Dirty Level | How dirty an object is. The maid will run the clean tree of any cleanable object with this > 400. |
| 40 | Flag Field 2 | See below this table. |
| 41 | Unused41 |  |
| 42 | Placement Flags |  |
| 43 | Movement Flags |  |
| 44 | Maximum Grade |  |
| 45 | Birth Year | Defaults to 1997? |
| 46 | Birth Month | Defaults to 6? |
| 47 | Birth Day | Defaults to 15? |
| 48 | Age in Months |  |
| 49 | Size |  |
| 50 | Hide Interaction | If this is set to 1 in the caller of an interaction check tree, the interaction is hidden from the pie menu. |
| 51 | Lighting Contribution | Range 0-100 |
| 52 | Primitive Result | Very interesting. I'll have to keep a eye out for anything accessing this. |
| 53 | Wall Block Flags |  |
| 54 | Primitive Result ID |  |
| 55 | GlobalWearRepairState |  |
| 56 | AgeInvenQtrDaysStart |  |
| 57 | AgeQtrDays |  |
| 58 | Object Version |  |
| 59 | Category | Objects set this so that they can be identified as part of a category, eg. counters. |
| 60 | SimIndependent |  |
| 61 | Serving Surface Value |  |
| 62 | Use Count |  |
| 63 | Exclusive Placement Flags |  |
| 64 | Gardening Value |  |
| 65 | Wash Hands Value |  |
| 66 | Function Score |  |
| 67 | Slot Count |  |
| 68 | PersistedFlags |  |
| 69 | kUnused_RandomSeedLO |  |
| 70 | SalePriceHi |  |
| 71 | SalePriceLo |  |
| 72 | Group ID |  |
| 73 | Reserved73 |  |
| 74 | Reserved74 |  |
| 75 | Reserved75 |  |
| 76 | Reserved76 |  |
| 77 | Reserved77 |  |
| 78 | Reserved78 |  |
| 79 | Reserved79 |  |

## Flag Fields

There are various flag fields used by behaviors to determine if certain interactions will work on an object.

### 40 - Flag Field 2

| bit | name | notes |
|---|---|---|
| 0 | CanBreak |  |
| 1 | CanDie |  |
| 2 | CanBeRepossessed |  |
| 3 | ObstructsView |  |
| 4 | Floats |  |
| 5 | Burns |  |
| 6 | Fixable |  |
| 7 | CannotBeStolen |  |
| 8 | GeneratesHeat |  |
| 9 | CanBeLighted |  |
| 10 | GeneratesLight |  |
| 11 | CanGetDirty |  |
| 12 | ContributesToAsthetic |  |
| 13 | unused |  |
| 14 | Architectual Window |  |
| 15 | Architectual Door |  |

## Notes for NSOClient

Checked against the 2017 FreeSO snapshot (`VMEntity.GetValue` and `SetValue`):

- **1 (direction):** read from the object's facing, not the stored value; a write is reduced to 0 to 7.
- **2 and 26 (container and parent ID), 3 (slot number), 62 (use count), 67 (slot count):** computed
  from containment, interactions, and slots rather than stored.
- **11 (object ID):** always the object's ID.
- **25 (lockout count):** counts down one per tick from when it was last written.
- **79:** FreeSO's own `FSOEngineQuery`, not reserved: writing 1 asks whether the object is safe to
  delete, and the answer (0 or 1) is stored.
- Indexes above 79 fail with "Object Data out of range!".
