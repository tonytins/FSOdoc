# Scopes

> From the SimAntics Wiki ([Scopes](https://simantics.wikidot.com/wiki:scopes)), retrieved 2026-10-16, by its contributors, under
> [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Converted to Markdown and lightly
> edited; sections headed "Notes for NSOClient" are ours. See [README.md](README.md).

Several primitives make reference to variables stored in the VM to perform their actions. For example, the random number primitive provides the location of a variable for the random range. Usually (but not always) these take the form of two fields, a variable owner and variable data. The owner can be thought of like a scope and the possible values for this are described below.

## Variable Scopes

These are the most common type of scope; they are mainly used by the expression primitive.

#### 0 - my objects attributes

Objects use attributes to store persistent information, e.g. whether the fish in the fish tank are dead or alive. This scope gets/sets an attribute for the object occupying the "My" pointer in the stack frame. The data value is the attribute index.

It seems (based on a handful of files) like a string table with ID = 256 in the objiff file contains labels for the attributes.

#### 1 - stack objects attributes

Same as "my objects attributes" except against the object occupying the stack object pointer in the stack frame.

#### 2 - targ obj attr (DO NOT USE)

Judging from the capital letters, this probably isn't used anywhere ingame.

#### 3 - my object

Accesses the object's [Object Data](object-data.md).

#### 4 - stack object

Same as my object but against the object occupying the stack object in the stack frame.

#### 5 - targ obj's (DO NOT USE)

Same as 2. Probably a leftover of an older more limited "stack object" system SimAntics used to use.

#### 6 - Global ( from avatar )

Accesses the global with the index specified in the data field. (from avatar) probably serves as a reminder that values can be different per player.

#### 7 - literal

Numeric literal. Use the value in the data field.

#### 8 - temps

Temporary registers. The data field is used as the index. The current assumption is that these are contextual to the thread but may be VM wide or related to stack objects.

#### 9 - parameters

This refers to the arguments passed into a sub-routine call when the stack was pushed. The data field represents the parameter index.

#### 10 - stack object id

This scope behaves more like a global. It allows you to reference or change the object occupying the stack object in the stack frame. For example, objects quite often in their init routine assign this to the My.objectId property.

#### 11 - Temp[temp]

Accesses a temporary register with another temp as a pointer.

#### 12 - check tree ad range

Accesses the maximum part of the object's advertisement data. See [Motive Data](motive-data.md) for what each data value references.

#### 13 - stack obj's temp

Accesses temp register of stack obj. See 8.

#### 14 - my motives

Accesses motives. See [Motive Data](motive-data.md) for what each data value references.

#### 15 - stack obj's motives

Same as above but for the stack object.

#### 16 - stack object's slot

See 20.

#### 17 - stack obj's motive[temp]

Accesses the stack object's [Motive Data](motive-data.md) using a temp variable (id as data passed) to select the motive.

#### 18 - my person data

Accesses [Person Data](person-data.md) using the data value as the field ID.

#### 19 - stack obj's person data

Same as above, but accesses the person data of the stack object instead.

#### 20 - my slot

Slots are most likely positions that objects can be placed on top of, eg. a plate is placed in a slot owned by a counter, a sitting sim is placed in a slot owned by the chair, a stacked plate is placed in a slot owned by the plate below it… Used in chairs' "sit function" methods to presumably determine if the sim is already sitting in the seat (if they are then do nothing).

(probably actually means routing slots, i'm stupid)

#### 21 - stack objects definition

Refers to OBJD attributes for the stack object. The data value refers to the field ID. It is not yet clear if these indexes change depending on the OBJD version. If so index information will need to be persisted.

| Data Field | Attribute Accessed | Notes |
|---|---|---|
| 0 | version_1 |  |
| 1 | version_2 |  |
| 2 | initial stack size |  |
| 3 | base graphic |  |
| 4 | num graphics |  |
| 5 | (old) main tree id | No longer used in favor of the entry point system. |
| 6 | (old) gardening tree id | No longer used in favor of the entry point system. |
| 7 | tree table id |  |
| 8 | interaction group |  |
| 9 | type |  |
| 10 | master id |  |
| 11 | sub index |  |
| 12 | (old) wash hands tree id | No longer used in favor of the entry point system. |
| 13 | anim table id |  |
| 14 | guid_1 | First half of GUID. |
| 15 | guid_2 | Second half of GUID. These are used by 2 type tests ingame and neither give any insight into the "endianness" of the two 16 bit parts. First part is probably lower half. |
| 16 | disabled | unused |
| 17 | (old) portal tree id | No longer used in favor of the entry point system. |
| 18 | DEPRECATED price | Room impact for paintings etc are affected directly by the price. (despite this being deprecated) |
| 19 | body strings id |  |
| 20 | slots id |  |
| 21 | (old) allow intersection tree | No longer used in favor of the entry point system. |
| 22 | uses fn table |  |
| 23 | bitfield 1 |  |
| 24 | (old) prepare food tree id | No longer used in favor of the entry point system. |
| 25 | (old) cook food tree id | No longer used in favor of the entry point system. |
| 26 | (old) place on surface tree id | No longer used in favor of the entry point system. |
| 27 | (old) dispose tree id | No longer used in favor of the entry point system. |
| 28 | (old) eat food tree id | No longer used in favor of the entry point system. |
| 29 | (old) pickup from slot tree id | No longer used in favor of the entry point system. |
| 30 | (old) wash dish tree id | No longer used in favor of the entry point system. |
| 31 | (old) eating surface tree id | No longer used in favor of the entry point system. |
| 32 | (old) sit tree id | No longer used in favor of the entry point system. |
| 33 | (old) stand tree id | No longer used in favor of the entry point system. |
| 34 | sale price | unused. |
| 35 | unused35 |  |
| 36 | unused36 |  |
| 37 | broken base graphic offset | Should probably take its word for being broken. Unused. |
| 38 | unused38 |  |
| 39 | has critical attributes |  |
| 40 | buy mode type |  |
| 41 | catalog strings id | Unused in SimAntics. |
| 42 | is global sim object |  |
| 43 | (old) init tree id | No longer used in favor of the entry point system. |
| 44 | (old) place tree id | No longer used in favor of the entry point system. |
| 45 | (old) user pickup tree id | No longer used in favor of the entry point system. |
| 46 | wall style |  |
| 47 | (old) load tree id | No longer used in favor of the entry point system. |
| 48 | (old) user place tree id | No longer used in favor of the entry point system. |
| 49 | object version |  |
| 50 | (old) room changed tree id | No longer used in favor of the entry point system. |
| 51 | motive effects id |  |
| 52 | (old) cleanup tree id | No longer used in favor of the entry point system. |
| 53 | (old) level info request | No longer used in favor of the entry point system. |
| 54 | catalog popup id |  |
| 55 | (old) serving surface tree id | No longer used in favor of the entry point system. |
| 56 | level offset |  |
| 57 | shadow |  |
| 58 | num attributes | This one seems to lie sometimes >:( |
| 59 | (old) clean tree id | No longer used in favor of the entry point system. |
| 60 | (old) queue skipped tree id | No longer used in favor of the entry point system. |
| 61 | front direction |  |
| 62 | (old) wall adjacency changed tree id | No longer used in favor of the entry point system. |
| 63 | mt lead object | Uh, do you mean "my" lead object? |
| 64 | dynamic sprites base id |  |
| 65 | num dynamic sprites |  |
| 66 | chair entry flags |  |
| 67 | tile width |  |
| 68 | lot categories |  |
| 69 | build mode type |  |
| 70 | original guid 1 | Part 1 of Original GUID |
| 71 | original guid 2 | Part 2 of Original GUID |
| 72 | suit guid 1 | Part 1 of "suit guid" |
| 73 | suit guid 2 | Part 2 of "suit guid" |
| 74 | (old) pickup tree id | No longer used in favor of the entry point system. |
| 75 | thumbnail graphic |  |
| 76 | shadow flags |  |
| 77 | footprint mask |  |
| 78 | (old) dynamic multi-tile update tree id | No longer used in favor of the entry point system. |
| 79 | shadow brightness |  |
| 80 | (old) repair tree id | No longer used in favor of the entry point system. |
| 81 | wall style sprite id |  |
| 82 | rating hunger | Hunger rating as shown in catalog. |
| 83 | rating comfort | Comfort rating as shown in catalog. |
| 84 | rating hygiene | Hygiene rating as shown in catalog. |
| 85 | rating bladder | Bladder rating as shown in catalog. |
| 86 | rating energy | Energy rating as shown in catalog. |
| 87 | rating fun | Fun rating as shown in catalog. |
| 88 | rating room | Room rating as shown in catalog. |
| 89 | rating skill flags | Skill flags as shown in catalog, eg. Bookcase shows as having cooking, mechanical… |
| 90 | num type attributes |  |
| 91 | misc flags |  |
| 92 | type attr guid 1 | Part 1 of "type attr guid" |
| 93 | type attr guid 2 | Part 2 of "type attr guid" |
| 94 | interaction result strings |  |
| 95 | (old) client house join tree id | No longer used in favor of the entry point system. NOTE!!! THIS IS ACTUALLY USED BY THE POOL SLIDE'S ALLOW INTERSECTION TREE! |
| 96 | (old) prepare for sale tree id | No longer used in favor of the entry point system. |

#### 22 - stack object's attr[stack param]

Accesses the attribute of the stack object referenced by the parameter with id specified by the data field.

#### 23 - room[temp 0]

Accesses properties of the room referenced by temp 0. 0: ambient light(0..100), 1: outside, 2: level, 3: area, 4: is pool

#### 24 - neighbor in stack object

Accesses data for the presumably neighbouring sim in the stack object's household. Most likely not used in The Sims Online.

Data field references:
0: person instance id, 1: belongs in house, 2: person age, 3: relationship raw score, 4: relationship score, 5: friend count, 6: house number, 7: has telephone, 8: has baby, 9: family friend count

#### 25 - local

Local variables for the BHAV. When the stack is pushed the BHAV may alloc space for locals. The data field is the local index.

#### 26 - stack object tuning

Tuning constants for the stack object. The most significant 9 bits of the data field are used to calculate the table ID as such: 4096 + (data » 7). The first 7 bits of the data field are the tuning variable index. The values can be stored in either BCON or OTF tables.

#### 27 - Dyn. Sprite Flag[temp] of Stack Object

Checks if one of the stack object's Dynamic Sprite Flags are set. Returns 1 for true and 0 for false.

#### 28 - check tree ad personality var

Similar to 12, but with the "Vary by personality" part of the advertisements instead. See [Motive Data](motive-data.md) for what each data value references.

#### 29 - check tree ad min

Similar to 12, but with the minimum part of the advertisements instead. See [Motive Data](motive-data.md) for what each data value references.

#### 30 - my person data [temp]

Accesses the [Person Data](person-data.md) referenced by a temp register.

#### 31 - stack obj's person data [temp]

Same as above but with the stack object.

#### 32 - neighbor's person data

Accesses the [Person Data](person-data.md) of "neighbor". Not sure what this means at the moment.

#### 33 - job data [temp 0, 1]

Most likely not used in TSO in favor of the OnlineJobs system. Probably something like temp 0 = job type, temp 1 = job level.

Data field references:

| id | name |
|---|---|
| 0 | number of levels |
| 1 | salary |
| 2 | min friend count |
| 3 | min cook skill |
| 4 | min repair skill |
| 5 | min social skill |
| 6 | min body skill |
| 7 | min logic skill |
| 8 | min creative skill |
| 9 | min req 7 |
| 10 | min req 8 |
| 11 | min req 9 |
| 12 | start hour |
| 13 | end hour |
| 14 | hourly delta - hunger |
| 15 | hourly delta - comfort |
| 16 | hourly delta - hygiene |
| 17 | hourly delta - bladder |
| 18 | hourly delta - energy |
| 19 | hourly delta - fun |
| 20 | hourly delta - social |
| 21 | car id |
| 22 | has suit |

#### 34 - neighborhood data

Not used for The Sims Online.

Data field references:
0: level complete, 1: Sims1.0 tutorial progress, 2: Sims1.0 tutorial house number, 3: hide arrow

#### 35 - stack object's function

Probably returns the BHAV id of the function specified by the data field. See entry points.

#### 36 - my type attr

Unused. Only used by TS1 Help System.

#### 37 - stack obj's type attr

Unused. Only used by TS1 Help System.

#### 38

Is selectable in Edith's dropdown for generic data types but is called "38" and has no visible use. Data value seems to reference entry in OBJD?

#### 39

Not selectable from Edith's dropdown. Definitely unused.

#### 40 - Local [temp]

Accesses the local variable referenced by the temporary variable chosed by the data value.

#### 41 - Stack Obj Attr [temp]

Same as "stack objects attributes" but chooses the attribute using the value of a temp variable chosen by the data field.

#### 42 - tempXL

Accesses one of the two 32 bit temp vars (tempXL[0], tempXL[1]). One of the few variables in SimAntics which holds a 32 bit value, mainly used for handling large sums of money. Be very careful when implementing this!

#### 43 - City Time

Returns ingame time values depending on the data value. Most commonly used over the other two… 0: Second, 1: Minute, 2: Hour, 3: TimeOfDay (unknown format)

#### 44 - TST (TSOStandardTime)

Returns the current real time from a constant time zone determined by the server (still needs to be server synced!). The data value determines which measure is returned. 0: Second, 1: Minute, 2: Hour, 3: TimeOfDay (unknown format)

#### 45 - Game Time

Like City Time, but specific to the simulation instance? The Mice seem to use this. The data value determines which measure is returned. 0: Hour, 1: DayOfMonth, 2: Unused, 3: Unused, 4: Unused, 5: Minute, 6: Second, 7: Month, 8: Year

#### 46 - My List

A list used for storing variable amounts of data. MUST only be accessed by Expression Push and Pop modes. 0: front, 1: back, 2: size

#### 47 - Stack Obj's List

Same as 46, but the one owned by the stack obj.

#### 48 - money over head 32bit

Presumably something like 1: Least Significant 16bit part, 2: Greatest Significant 16bit part. Used for money values > 32767.

#### 49 - My Lead Tile Attribute

Most likely gets attribute from lead tile of a multi-tile object. Data value is the ID of the attribute.

#### 50 - Stack Obj's Lead Tile Attribute

Same as 49 but with the stack obj.

#### 51 - My Obj's Lead Tile

Most likely returns the ID of the lead tile of a multi-tile object.

#### 52 - Stack Obj's Lead Tile

Same as 51 but with the stack obj.

#### 53 - Stack Obj's MasterDef

Accesses a value directly from the stack object's OBJD, depending on the data value passed.

#### 54 - FeatureEnableLevel

Seems to be EA Land only. Lots of stuff regarding Paypal and Custom Content in here.

I skipped a few EA-Land specific Custom Content related scopes here…

#### 59 - My Avatar ID

Returns Avatar's ID.

## Notes for NSOClient

Checked against the FreeSO snapshot (update-46) (`VMMemory.cs`), which NSOClient's `VMMemory`
matches case for case (scorecard VM-4 and FID-9). Where FreeSO differs from the text above:

- **2 and 5 (target object):** fail with "Target Object is Deprecated!".
- **12 (check tree ad range):** reads 0; writes do nothing and return false.
- **13 (stack obj's temp), 28, and 29:** not implemented in FreeSO; reading fails.
- **21 (stack object's definition):** the field table above matches FreeSO's `VMOBJDVariable` (0 to 96).
- **23 (room):** FreeSO has no lighting or level data per room: 0 always reads 100 and 2 reads 0.
  Any index other than 0 to 4 fails with "Invalid room data!". Writing fails.
- **24, 32, 33, and 38:** The Sims 1 only; in TSO, reading fails with "Only valid in TS1.".
- **26 (tuning):** the table isn't always 4096 + (data >> 7). Tables 0 to 63 are the code owner's
  (4096 and up), 64 to 127 its semi-global's (8192 and up, looked up in the owner's file first),
  and 128 to 191 the global's (256 and up); 192 and up are read like the owner's. Each looks for
  a BCON, then an OTF table, and reads 0 if neither has the table.
- **36 and 37 (type attributes):** read 0 in TSO; writes are ignored.
- **42 (tempXL):** only Expression handles 32-bit values. Other primitives fail when they read it.
- **43 and 45 (city time, game time):** FreeSO reads both the same way: 0 seconds, 1 minutes, 2 hours,
  3 time of day; any other index fails. The Game Time indexes above (0 hour to 8 year) are the
  layout of the deprecated globals instead.
- **44 (TSO standard time):** reads 0.
- **46 and 47 (lists):** reading 0 is the front, 1 the back, and 2 the count; the front or back of an
  empty list fails. Reading the stack object's list with no stack object reads 0, but Expression's
  push and pop fail without one. Writing through these scopes fails.
- **48 (money over head):** reads 0. Expression's 32-bit write treats the caller as a Sim.
- **54 (feature enable level):** reads 1; writing fails. **59 (my avatar ID):** reads 0.
