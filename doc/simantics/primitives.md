# Primitives

> From the SimAntics Wiki ([Primitives](https://simantics.wikidot.com/wiki:primitives)), retrieved 2026-10-16, by its contributors, under
> [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Converted to Markdown and lightly
> edited; sections headed "Notes for NSOClient" are ours. See [README.md](README.md).

In SimAntics, the opcode of an instruction can either refer to a built-in command, known as a **primitive**, or to a subroutine. The subroutines can be privates (belong to the object) semiglobals or globals. A global will have an opcode 256 to 4095, a private will have an opcode from 4096 to 8191 and a semiglobal will have an opcode >= 8192.

Instructions are executed synchronously within the thread until something yields the thread, an error is fired or the stack becomes empty. An example of this is the Animate Sim primitive. In the behaviours found in the game, this primitive often has a loopback on the false branch which points back to itself. The primitive returns true if the animation is complete and false if it is not. The false then loops back to the Animate Sim primitive to run the next frame. If this code was executed synchronously no animations would ever be observed. Therefore some primitives yield the thread.

You can think of primitives as having the following return values. GOTO_TRUE, GOTO_FALSE, ERROR, GOTO_TRUE_YIELD, GOTO_FALSE_YIELD.

The documentation below for primitives and their operands is correct for The Sims Online. The Sims 1 and 2 operands may be slightly different.

## The Sims Online Primitives

### 0 - Sleep

Changes the current virtual thread's state to sleeping. The number of ticks to sleep for is determined by a stack variable (local) specified by the operand.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Stack Var # |
| 2–7 | Unused |

### 1 - Generic Sims Online Call

*Main article: [Generic Sims Online Call](generic-sims-online-call.md)*

This primitive is used to call upon game functions which are either not common enough to include as a primitive or very specialized with no parameters (eg. Disable/Enable Build/Buy).

#### Operand

| Bytes | Field |
|---|---|
| 0 | Call ID |
| 1–7 | Unknown (potentially any arguments?) |

### 2 - Expression

Performs a logical or mathematical expression. The operator value describes what type of expression to perform and the other values determine the left and right hand side of the expression.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | LhsData |
| 2–3 | RhsData |
| 4 | IsSigned |
| 5 | Operator |
| 6 | LhsOwner |
| 7 | RhsOwner |

The lhsdata, lhsowner, rhsdata and rhsowner are scopes as described [here](scopes.md). Possible values for operator:

| id | name | notes |
|---|---|---|
| 0 | > |  |
| 1 | < |  |
| 2 | == | equality test |
| 3 | += |  |
| 4 | -= |  |
| 5 | := | assignment |
| 6 | *= |  |
| 7 | /= |  |
| 8 | IsFlagSet | Checks the bit specified by the RHS in the LHS. |
| 9 | SetFlag | Sets the bit specified by the RHS in the LHS. |
| 10 | ClearFlag | Clears the bit specified by the RHS in the LHS. |
| 11 | ++ and < | Increments LHS then returns true if LHS < RHS, false otherwise |
| 12 | %= |  |
| 13 | &= |  |
| 14 | >= |  |
| 15 | <= |  |
| 16 | != |  |
| 17 | -- and > | Decrements LHS then returns true if LHS > RHS, false otherwise |
| 18 | Push* | If LHS is either My List or Stack Object's List, push the value from the RHS onto the position specified by the data field. |
| 19 | Pop* | If RHS is either My List or Stack Object's List, pop the value from the RHS list at the position specified and store it in the LHS. |

*These only work if the operation is performed on a list!

### 3 - Report Metric

Used to record data. Not sure where this data goes…

### 4 - grab

Places the Stack Object in the Sim's (should be the thread's "Me" reference) slot 0.

#### Operand

No Operand.

### 5 - drop

Attempts to place the caller's held object (in slot 0) on an adjacent tile, starting in front.

#### Operand

No Operand.

### 6 - Change Suit/Accessory

### 7 - Refresh

Marks an object to be redrawn, update the light map of its room or update the room's room score.

#### Operand

| Bytes | Field |
|---|---|
| 0 | TargetObj |
| 1 | Unused |
| 2 | RefreshType |
| 3–7 | Unused |

TargetObj:

- 0 - My
- 1 - Stack Object's.

RefreshType:

- 0 - Graphic
- 1 - Lighting Contribution
- 2 - Room Score Contribution

### 8 - Random Number

Sets a variable referenced by a [Scope](scopes.md) to a random number between 0 and a specified value also referenced by a scope.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | DestData |
| 2–3 | DestOwner |
| 4–5 | RangeData |
| 6–7 | RangeScope |

### 9 - burn

Spawns a fire object on the specified location if a fire object is not already there and the object on the space is not busy (or the allow busy objects flag is enabled).

#### Operand

| Bytes | Field |
|---|---|
| 0 | Location |
| 1 | Flags |
| 2–7 | Unused |

The location can either be 0: Stack Object, 1: in front of stack object or 2: floors under stack object (unused in TSO)
There is only one flag: 1: allow busy objects. If this is not enabled the fire will not spread onto objects that are not idle.

### 10 - Sims1.0 tutorial

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 11 - Get Distance To

Gets the Pythagorean distance between the stack object and the specified object in tiles, floored.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Temp # |
| 2 | Unknown (Flags?) |
| 3 | ObjectScope |
| 4–5 | OScopeData |
| 6–7 | Unknown |

### 12 - Get Direction To

Gets the direction from the specified object to the stack object and stores it in the specified [Scope](scopes.md).

The direction's basis or 0 value "North" is facing from where the house should be AWAY FROM the road. The following values 1-7 are a clockwise rotation around this direction in 45 degree steps, and each has a compass name as you would expect going clockwise corresponding with its direction. The directions of both of the objects are not considered for the calculation, just their positions.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | ResultData |
| 2–3 | ResultOwner |
| 4 | Unknown (Flags?) |
| 5 | ObjectScope |
| 6–7 | OScopeData |

### 13 - Push Interaction

Pushes an [Interaction](introduction.md#interactions) onto the Stack Object's tree queue.

#### Operand

| Bytes | Field |
|---|---|
| 0 | Interaction # |
| 1 | ObjectLocation |
| 2 | Priority |
| 3 | Flags |
| 4 | IconLocation |
| 5–7 | Unknown |

ObjectLocation's meaning differs based on flags, see below. IconLocation is only regarded when a certain flag is set.

#### Priorities

This would be better on the [Interactions](introduction.md#interactions) page, but it will remain here until we understand more about how they work.

| id | name | notes |
|---|---|---|
| 0 | inherited priority | Inherits the priority of this interaction. |
| 1 | maximum priority | Instantly goes to the front of the interaction queue. |
| 2 | autonomous priority | For interactions queued by autonomy. |
| 3 | user driven priority | Higher than autonomous priority. |
| 4 | parent idle priority | ??? |
| 5 | parent exit priority | ????what???? |
| 6 | idle priority | A sim's idle loop runs on this priority. When new interactions are queued, this one is suspended. |

#### Flags

| id | name | notes |
|---|---|---|
| 1 | Use icon from local | Uses the icon from the object stored in the local specified by IconLocation. |
| 2 | Local Variable for ObjectID | If set, the object the interaction is retrieved from is specified by the Local Variable pointed to by ObjectLocation. If not, it is specified by the Parameter pointed to by ObjectLocation. |
| 3 | continue as current | Pushes the interaction as a continuation of the existing one. (before any following interactions that the user may have queued) |
| 4 | carry name over | Uses this interaction's name for the new interaction instead of its true name. |
| 5 | Unknown |  |
| 6 | Unknown |  |
| 7 | Unknown |  |
| 8 | Unknown |  |

There is functionality for "Interaction result type" and "Server Only (DEV ONLY!)" but I haven't been able to place these on the operand.

### 14 - Find Best Object for Function

Finds an object by function with the relevant [Object Data](object-data.md) or advertisement set highest, and with its entry point for that function not set to None. This is used for finding sinks, counters, ovens etc (in conjuncton with Get Distance To). If the object's "lockout count" is greater than 0, the object is ignored. This is used to iterate over all of the objects with the function, usually to find the one with the smallest distance. If the primitive finds an object, the stack object is set to it and the primitive returns true, however if the primitive cannot find any objects, it returns false.

This is heavily used by the "Food Chain" group of interactions and NPC service sims.

#### Functions

| id | name | Object Data Referenced | Notes |
|---|---|---|---|
| 0 | prepare food | 31 - Prep Value | The food processor has a much better value for this than a counter. |
| 1 | cook food | 32 - Cook Value | Used by food chain after preparation. Oven > Microwave. |
| 2 | flat surface | 33 - Surface Value | Used to find a surface to put anything that isn't food on, like the rose gift you can receive in TS1. Causes the "homework table" effect in TS2. |
| 3 | dispose | 36 - Dispose Value | Used by objects that you can get rid of to find the nearest/most suitable way to dispose of them. Trash compactor > bin > outside bin. |
| 4 | eat | N/A | No value for this, probably just selects first object with food function set. |
| 5 | pick up from slot | N/A | Used by a person to pick up an object. |
| 6 | wash dish | 37 - Wash Dish Value | Finds somewhere to wash dishes. Would prefer a dish washer to a sink. |
| 7 | eating surface | 38 - Eating Surface Value | For instance, a dining table will be more suitable to eat on than a desk. |
| 8 | sit | N/A | Most likely selects the chair with the highest comfort advertisement. |
| 9 | stand | N/A | PersonGlobals::stand up only uses Run Functional Tree with this function, and uses the person's current Container ID to determine what the chair is. This is probably unused. |
| 10 | serving surface | 61 - Serving Surface Value | Used by people who are looking for a place to drop/serve food. A counter or table are usually the best choice. |
| 11 | clean | N/A | Used by Maid to find objects with a clean function available. |
| 12 | gardening | 64 - Gardening Value | Used by Gardener and when normal Sims water plants (to lead onto the next one). |
| 13 | wash hands | 65 - Wash Hands Value | Used by Toilets etc. to find a sink to use for neat sims. |
| 14 | repair | N/A | Used by Repairman to find objects that need repairing. |

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Function |
| 2–7 | Unused |

### 15 - Break Point

Pauses execution for further examination if the variable specified by a [Scope](scopes.md) is not 0.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Data Field |
| 2–3 | Owner |
| 4–7 | Unused |

### 16 - Find Location For

Finds a location to place the stack object. Can be along object vectors, out of the world and "smoke cloud", a specific mode used for the attack interaction.

#### Operand

| Bytes | Field |
|---|---|
| 0 | Mode |
| 1 | Local # |
| 2 | Flags |
| 3–7 | Unused |

#### Modes The possible modes are

| id | name | notes |
|---|---|---|
| 0 | Default | Places as close to reference object as possible. |
| 1 | out of world | Places the object out of the world. |
| 2 | smoke cloud | A special mode used for the attack interaction. Most likely places cloud in middle of two attacking sims. |
| 3 | along object vector | Along the vector the reference object's direction makes. |
| 4 | lateral to object vector | Along the vector perpendicular to the reference object's direction vector. |

#### Flags

| id | name | notes |
|---|---|---|
| 0 | Use Local as Ref Obj | Uses the object in the specified local (Local #) as the reference instead of the thread owner. |
| 1 | allow intersection | The placement can happen inside another object if this is set. |
| 2 | user editable tiles only | The placement can only happen on tiles accessible by Buy/Build mode if set. |

### 17 - idle for input

Behaves like the sleep primitive, but can return early if the object has been "notified" out of idle, in which case it also sets [Object Data](object-data.md) flag 1«6 "notified by idle for input". One example of this is when an interaction is canceled, or when another object uses the primitive "Notify the Stack Object out of Idle". This is commonly used (with a sleep time of 0) to detect if an interaction has been canceled.

#### Operand

| Bytes | Field |
|---|---|
| 0 | Local # |
| 1 | Allow Push? |
| 2–7 | Unused |

Local # specifies the Local Variable the number of ticks are taken from. If "Allow Push" is set to 1, this state is "interruptable" and functions can be pushed onto the stack.

### 18 - Remove Object Instance

Removes the object instance specified.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | TargetObj |
| 2 | Flags |
| 3–7 | Unused |

TargetObj: 0 = Me, 1 = Stack Object, 2 = Target (unused)

#### Flags

| id | name | notes |
|---|---|---|
| 1 | return immediately | If set, the rest of the function is not allowed to run. |
| 2 | cleanup all | "Clean up all objects involved" |
| 3 | unused |  |
| 4 | unused |  |
| 5 | unused |  |
| 6 | unused |  |
| 7 | unused |  |
| 8 | unused |  |

### 19 - make new character

Makes a new character with the specified Age, Skin Color and Gender. Not used by any objects activated in TSO.

#### Operand (not confirmed)

| Bytes | Field |
|---|---|
| 0 | AgeLocal |
| 1 | SexLocal |
| 2 | GenderLocal |
| 3–7 | Unused |

### 20 - Run Functional Tree

Run one of several types of functions on the stack object. Used to make sims sit down to eat, wash their hands etc as part of an automatic process.
See **Primitive 14 - Find Best Object for Function** above for a the table of functions that can be referenced.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Function |
| 2 | Flags |
| 3–7 | Unused |

The only flag seems to be bit 1: change icon. This changes the behavior icon to that of the stack object (imagine using toilet, when going to wash hands icon changes for sink.

### 21 - show string

Presumably used for debug. Some objects show interesting and original strings such as "can't get to the duck", but it doesn't look like these should normally be used. Nothing shows up in The Sims Complete Collection when this primitive is run.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | String Table # |
| 2–3 | (String ID - 1) |
| 4–7 | Unused |

### 22 - look towards

### 23 - Play Sound Event

Plays the specified sound event.

| Bytes | Field |
|---|---|
| 0–1 | Event ID |
| 2–3 | Unknown |
| 4 | Flags |
| 5 | Volume (0-100) |
| 6–7 | Unused |

Flags:

| id | name | notes |
|---|---|---|
| 1 | looped | If the sound loops or not. |
| 2 | with stack obj as source | Use the stack object as the sound's source. |
| 3 | no zoom | Sound volume does not change with zoom level if set. |
| 4 | no pan | Sound does not pan to match position on screen if set. |
| 5 | auto vary |  |
| 6 | Unknown |  |
| 7 | Unknown |  |
| 8 | Unknown |  |

### 24 - old relationship

Gets the relationship between two objects. Used by the pool table to determine the player number of people and sometimes used by social interactions to keep track of who people are talking to etc. This is an old system for doing this, but objects still use it.

#### Operand

| Bytes | Field |
|---|---|
| 0 | Get/Set |
| 1 | Relationship Var |
| 2 | Parameter # |
| 3 | Affected Parties |
| 4 | Flags |
| 5–7 | Unknown |

Get/Set determines whether or not the relationship value will be retrieved from or set to the parameter specified by Parameter #. 0 = Get, 1 = Set.
Relationship Var determines the relationship variable to access. Not sure what these are right now - looks like each object has its own specific strings!
Flags: 1 = fail if too small, 2 = use neighbors

### 25 - Transfer Funds

A more fleshed out version of Alter Budget from The Sims 1, allowing more options such as transfer of funds between people, to maxis, from maxis and to generic objects such as the tip jar! Not sure how this works or what the operand is right now.

### 26 - Relationship

Tracks "relationship" variables of one object to another. Relationships are kept between avatar-lot transfers (not sure about object relationships), so care will have to be taken when storing relationships to avatars (use avatar id instead of object id).

| Bytes | Field |
|---|---|
| 0 | Relationship Var |
| 1 | Mode |
| 2 | Flags |
| 3 | Local # |
| 4–5 | Variable Scope |
| 6–7 | Variable Data |

The primitive usually gets/sets the relationship variable into/to the specified variable.

#### Modes

There are 4 modes for the Relationship primitive:
0: from me to stack object
1: from stack object to me
2: from stack object to object in local (Specified by Local #)
3: from object in local to stack object (Specified by Local #)

#### Flags

| id | name | notes |
|---|---|---|
| 1 | use neighbor ids | Used to get and set relationships to sims off of the lot in the sims 1. Not used in TSO. |
| 2 | fail if matrix is not large enough | If unset, a new relationship is created when this happens. (maybe means "fail if relationship doesn't yet exist"?) |
| 3 | get/set | If set, relationship is set to the value in the specified variable. If unset, the relationship is retrieved into it. |

### 27 - Go To Relative Position

### 28 - Run Tree by Name

This primitive runs the tree referenced by the name in the specified string on either the stack object or itself.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | String Table ID for Tree Names |
| 2 | String Scope (1: global, 0: private) |
| 3 | Unused |
| 4 | String# - 1 |
| 5 | Destination |
| 6–7 | Unused |

#### Destination Values

0: run in my stack (non-yielding)
1: run in stack object's stack (non-yielding)
2: push onto my stack (yielding)

### 29 - Set Motive Change

Sets a motive to change at a specific rate until it hits the specified value. You can clear all changes by setting the Clear All? flag.

#### Operand

| Bytes | Field |
|---|---|
| 0 | PerHrOwner |
| 1 | StopValueOwner |
| 2 | Target Motive |
| 3 | Clear All? |
| 4–5 | PerHrData |
| 6–7 | StopValueData |

The values for the change per hour and value to stop at are accessed via [Scopes](scopes.md). If Clear All? is set, all motive changes on this sim are cleared. The Target Motive uses the same ID format as [Motive Data](motive-data.md).

### 30 - Syslog

Used to log information from objects. Seems to always log a string from private String Table 308.

### 31 - Set to Next

Sets the specified variable referenced by a [Scope](scopes.md) to the object ID of the first object it can find (after the last one) using the search parameters. Used to iterate over objects of a specific type, people etc. Returns false after all objects of that type have been iterated over.

#### Operand

| Bytes | Field |
|---|---|
| 0–3 | GUID (if applicable) |
| 4 | Mode |
| 5 | LhsOwner |
| 6 | Value |
| 7 | LhsData |

#### Modes

| id | name | notes |
|---|---|---|
| 0 | object | Every object (including people) |
| 1 | person | Just people. |
| 2 | non-person | Just ordinary objects. |
| 3 | part of a multi-tile object | Should be in the correct order. |
| 4 | object of type | Uses GUID field to specify object type. |
| 5 | neighbor id |  |
| 6 | obj with category == sp 0 |  |
| 7 | neighbor of type | Uses GUID field to specify neighbor type. |
| 8 | obj on same tile | Used counters most often, but also destroying objects fires are inside. |
| 9 | obj adjacent to object in local | Local specified by value field. |
| 10 | carreer (sic) | Used to iterate over careers in TS1 for the job finder. Not used in TSO. |
| 11 | closest house | Not used in TSO. There's a holdover from this though in beds2::Dream Person, presumably made sims dream about neighbours. |

If the highest bit (128) of the Modes field is set the left hand side field is used. If not then the object ID is stored in the stack object.

### 32 - Test Object Type

Tests an object's type against a specified GUID.

#### Operand

| Bytes | Field |
|---|---|
| 0–3 | GUID |
| 4–5 | TargetData |
| 6–7 | TargetOwner |

### 33 - find 5 worst motives

Places 5 worst motives into temps 0-4. Each temp references a [Motive Data](motive-data.md) entry, and they are ordered by lowest first. Only used twice in TSO… npcportal.iff and pedportal.iff (for determining why a sim decided to leave).

#### Operand

| Bytes | Field |
|---|---|
| 0–3 | Unused |
| 4–5 | Target |
| 6–7 | Motive Type |

Target: 0 = me, 1 = stack object, 2 = target object (?)
Motive Type: 0 = Motive, 1 = Mental Motive, 2 = Physical Motive

### 34 - ui effect

Only used by tutorial to flash buttons.

### 35 - Special Effect

Shows a Picture in Picture display on the specified object (always the stack object). Can also center the camera on an object and slow time down to 1 speed (like the fire).

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Timeout (seconds) |
| 2 | Window Size |
| 3 | Zoom Level |
| 4 | Flags |
| 5 | (Caption STR# - 1) |
| 6–7 | Unused |

Window Size: 0 = small, 1 = medium, 2 = large
Zoom Level: 1 = near, 2 = mid, 3 = far

The caption is always read from string table 305.

#### Flags

| id | name | notes |
|---|---|---|
| 1 | activate | If unset, the primitive clears the current PIP window. |
| 2 | live/one frame | 1 = live: shows live window of event. 0 = one frame: shows static picture of event at call time. |
| 3 | ignore visibility |  |
| 4 | center | If set, the main screen is also centered on the event. |
| 5 | snapshot | If set, a snapshot will be taken and saved of the event. |
| 6 | timeout as Local Variable | If set, instead gets the timeout from the Local Variable referenced by the timeout field. |
| 7 | slow down | Slows the game down to normal speed for events that require quick actions. Not relevant in TSO… |
| 8 | unknown |  |

### 36 - Dialog - Private Strings

Very complicated, not much info on this one and the text exported versions seem to be missing a lot of info. I probably won't be able to get the operand for this one until much later.

#### Dialog Types

| id | name | notes |
|---|---|---|
| 0 | message | Displays a dialog with a message and yes button. |
| 1 | yes-no | Displays a dialog with a message, a yes button and a no button. Returns true on yes and false on no. |
| 2 | yes-no-cancel | Same as above, but on "No" the primitive returns false and sets the specified temp to 0. Cancel returns false and sets the temp to 1. |
| 3 | text entry | Displays a dialog with text input and OK. The next call to "make new character" will use the input as the name of the new character. (used for babies in ts1, pets in tso?) Has behavior relating to Temps in some way… |
| 4 | Sims1.0 tutorial | The dialogs that pop up in the sims 1 tutorial. Deprecated in TSO! |
| 5 | Numeric Entry | Puts the result in the specified Temp. Can use TempXL instead (for biiig numbers). Used for tip jars. |

Text Entry also has a "filter profanity" flag which causes the text entry to return false on detecting any profanity. Temp can either be 0 or 1.

#### Behavior

Engage (OLD) - ???
Continue (OLD) - ???
Engage - ???
Continue - ???

Not sure what the difference between these is. Both are used in their fair share of dialogs.

#### Icon

| id | name | notes |
|---|---|---|
| 0 | automatic | This is the only type used in TSO. |
| 1 | none | Not used. |
| 2 | neighbor | Not used. |
| 3 | indexed | Takes a value, possibly attribute. Not used. |
| 4 | named | Not used. |

Strings can be set for the Message, Yes Button, No Button, Title, Cancel Button and Icon Name. Each presumably takes up a byte in the operand to reference the relevant string id, leaving 2 bytes for the other data… This will most likely be complicated. Strings are always chosen from string table ID 301 (called "Dialog prim string set").

Do not take any information in this section as final!

#### Local reference

Local variable to reference.

### 37 - Test Sim Interacting With

Returns true if this sim is interacting with the Stack Object, false otherwise. Used to allow interactions like "wake up" for sims already sleeping in the tent and disallow it otherwise.

#### Operand

No Operand.

### 38 - Dialog - Global Strings

Same as 36 except instead accessed global strings. TSO only.

### 39 - Dialog - Semi-Global Strings

Same as 36 except instead accessed semi-global strings. TSO only.

### 40 - OnlineJobsCall

Calls one of the built in functions relating to OnlineJobs. Any that require input, like "Is Job Available" use the value in temp 0.

#### Operand (NOT VERIFIED)

| Bytes | Field |
|---|---|
| 0 | Call# |
| 1–7 | Unused |

#### Calls

| id | name | notes |
|---|---|---|
| 0 | Goto Job Lot | Sends the Sim in the Stack Object to their Job Lot. |
| 1 | Set Controller ID | Sets the controller ID to the ID in the stack object. Used by each respective job controller. |
| 2 | AttemptToValidateWorker | Returns true if sim works on lot, false otherwise. Used by OnlineJobs doors to block sims that aren't employed. |
| 3 | Unused |  |
| 4 | Unused |  |
| 5 | AddStatusMessage | Temp 0: String List to use, Temp 1: String ID to use |
| 6 | RemoveStatusMessage | Removes the current status message |
| 7 | SetTimeRemaining | Temp 0: Minutes, Temp 1: Seconds. |
| 8 | Get Random Job | Gets a random job that is available. |
| 9 | Is Job Available | Checks if the job referenced by Temp 0 is available. Returns true or false. |
| 10 | Signal Job Type Change | Updates Server info with new Job ID (The one in [Person Data](person-data.md), "OnlineJobID") |
| 11 | Signal Job Grade Change | Updates Server info with new grade (The one in [Person Data](person-data.md), "OnlineJobsGrade") |
| 12 | SetWorkMode | Sets the work mode to the value of the Job Controller's attrWorkMode attribute. |

### 41 - Set Balloon/Headline

Sets the balloon over a Sim's head to display with the specified icon or clear.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Target |
| 2 | Icon # |
| 3 | Icon Group |
| 4–5 | Duration (Ticks/Loops) |
| 6 | Balloon Type |
| 7 | Flags |

Target: 0 = Me, 1 = Stack Object

If Ticks is 0, the Balloon/Headline is cleared. If Ticks is -1 (all bits set), the duration will be forever

#### Flags

| id | name | notes |
|---|---|---|
| 1 | show when inactive |  |
| 2 | crossed out | Sets the icon to be crossed out. Used to say things like "no money". |
| 3 | animation reversed | Reverses the balloon's animation. |
| 4 | loops | If set, duration will be in animation loops instead of ticks. |
| 5 | + Local Variable 0 | Adds local variable 0 to the Icon #. |
| 6 | unused |  |
| 7 | unused |  |
| 8 | unused |  |

#### Balloon Types

| id | name | notes |
|---|---|---|
| 0 | Thought |  |
| 1 | Scream |  |
| 2 | Speak | These have animations? |
| 3 | None | Used for things with no backgrounds like the relationship plusses. |

#### Balloon Icons

The wiki links to a Balloon Icons list, but that page was never written.

### 42 - Create New Object Instance

Creates a new Object Instance with the GUID specified in the location specified. The new object ID is placed in the stack object. If the object cannot be created, the primitive returns false.

#### Operand

| Bytes | Field |
|---|---|
| 0–3 | GUID |
| 4 | Position |
| 5 | Flags |
| 6 | Local To Use (if specified) |
| 7 | Interaction Callback |

#### Interaction Callback

Upon running the init function of the created object, if the Return immediately flag is set the [Interaction](introduction.md#interactions) specified by Interaction Callback is queued onto the Stack Object (at the time and same thread this primitive was run) with its Parameter 0 set to the object ID. This is used extensively by the social interaction objects to create AND INIT the objects before running the function from them. This functionality replaces the default where the new object is placed into the stack object, but the primitive still returns true or false depending on whether the creation succeeded or not.

A value of 254 means "Call This Tree".

#### Positions

| id | name | notes |
|---|---|---|
| 0 | in front of me |  |
| 1 | on top of me |  |
| 2 | in my hand |  |
| 3 | in front of stack object |  |
| 4 | in slot 0 of stack object |  |
| 5 | underneath me | Apparently only for walk-overable-objects. Not sure if it works otherwise |
| 6 | out of world | Object ID is in stack, so it can still be controlled and positioned manually. |
| 7 | below object in stack param 0 | Uses the Local To Use field in some manner… |
| 8 | below object in local | References object in the specified local variable. |
| 9 | next to me in direction of local | References object in the specified local variable. |

#### Flags (bitfield)

| id | name | notes |
|---|---|---|
| 0 | do not duplicate |  |
| 1 | pass object ids to main | Edith strings describe this as: "transfer current stack object to new object and put my id in stack param 0" |
| 2 | use neighbor in stack obj | Obsolete apparently… disregards the GUID and creates a visitor using the neighbour in the stack object. (TS1 only?) |
| 3 | fail if tile is non-empty |  |
| 4 | pass temp 0 to main | Assuming this puts this thread's temp 0 into the new object's temp 0 on init. |
| 5 | flag 32 | face same direction as stack object? |
| 6 | Return Immediately | See Interaction Callback above. |
| 7 |  | Persist new object in DB? objects with this unset probably wouldn't be there upon reloading the lot. |

### 43 - drop onto

Drops an object from the specified slot of the Me object onto the specified slot on the Stack Object.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | SrcSlotMode |
| 2–3 | SrcSlotNum |
| 4–5 | DestSlotMode |
| 6–7 | DestSlotNum |

The mode determines where to get the slot number - 0 for literal and 1 for retrieval from a parameter.

### 44 - Animate Sim

Plays an animation on the thread this primitive is run on's Sim. After playing the animation the primitive acts as an event listener, calling the false branch when an animation event (xevt) is called and the true branch when the animation is finished, and waits in place until one of these happens. When looped back to from the false branch and still playing the animation the primitive will resume event listening. If there have been multiple events since the last time the primitive was listening, it favors the most recent one, or if the animation has already ended, the true branch.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Animation ID |
| 2–3 | LocalEventNumber |
| 4 | Source |
| 5 | Flags |
| 6–7 | ExpectedEvents |

ExpectedEvents should be set to the number of events in the animation, but can be set to 0. If it is 0, it has no effect.
If Animation ID is 0, the current animation is stopped.

#### Animation Source

| id | name | real source |
|---|---|---|
| 0 | This Object | STR# 129 for adult/pet, STR# 130 for child. |
| 1 | Global | STR# 128 in Globals.iff |
| 2 | Person Stock | STR# 130 in Globals.iff |
| 3 | Miscellaneous | STR# 156 in Globals.iff for adult/pet, STR# 157 for child (child unused in TSO) |

#### Flags

| id | name | notes |
|---|---|---|
| 0 | flag1 | unknown |
| 1 | backward | Set if the animation should be played backwards. |
| 2 | param | If set, the animation ID is retrieved from param[Animation ID]. If not set, the animation is retrieved from the literal Animation ID. |
| 3 | interruptable | If set, animation will interrupt when notified by input (eg. action cancelled) |
| 4 | flag5 | unknown |
| 5 | dest | Normally on receiving events, the event is stored in parameter 0, however if the dest flag is set the event is stored in local[LocalEventNumber]. |
| 6 | flag6 | unknown |
| 7 | unused |  |

The "unknown" flags are:
- Interruptable
- Hurryable
- Full Reset
- Behaviour: A 2 bit collection of animation modes, which are:

| id | name | notes |
|---|---|---|
| 0 | Play and wait | The normal mode as described above |
| 1 | Set custom background animation | Sets the animation that plays when no other animation is playing. |
| 2 | Set custom carry animation | Carry animation plays on upper half of body when walking, doing most things. Overlays hand animation for all other animations. |
| 3 | Stop standard carry, play and wait |  |

Since the only 2 bit space is 3&4, this probably fits in there.

### 45 - Go To Routing Slot

### 46 - Snap

Instantly moves the sim to a position retrieved from a routing slot without walking the sim there. Used for objects which move the sim using custom animations (or to positions inside them and back out), like stairs.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Index |
| 2–3 | Mode |
| 4 | Flags |
| 5–7 | Unused |

#### Modes

The Snap to Routing Slot primitive has multiple modes which allow the primitive to do a variety of things:

0 - Slot Number in parameter:
Snaps to a routing slot (type 3) owned by this object, with index specified by the parameter specified by the "Index" part of the operand.

1 - Be contained in stack object:
Snaps the sim into containment slot 0 (type 0, index 0) of the stack object. If the object is dragged while in this state, the sim will be attached to the object like a plate is on a table.

2 - Be in front of the stack object:
Snaps the sim to be directly in front of the stack object. Direction is supposedly unchanged.

3 - Slot Number:
Snaps to a routing slot (type 3) owned by this object, with index specified by the "Index" part of the operand.

4 - Slot Number:
Snaps to a global routing slot (type 3), with index specified by the "Index" part of the operand.

#### Flags

1: Origin only
2: Ask person to move (asks sims idling on the snap location to move)
3: Use footprint extensions (???)

### 47 - reach

Plays the appropriate reach animation on the sim depending on object height and if the sim is sitting, and can attempt to grab/drop an item on its animation event.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Mode |
| 2–3 | Attempt to grab/drop? |
| 4–5 | Slot Param |
| 6–7 | Unused |

Mode can be:
0: Reach to stack object, 1: Reach to slot on stack object, 2: Reach to mouth (unused)

When mode 1 is specified, the slot to reach to is retrieved from the parameter specified by "Slot Param".

### 48 - Stop ALL Sounds

Stops ALL sounds (yes, ALL!) of the specified object.

#### Operand

| Bytes | Field |
|---|---|
| 0 | Target |
| 1–7 | Unused |

Target: 0 = me, 1 = stack object.

### 49 - Notify the Stack Object out of Idle

Signals the Stack Object out of an idle primitive. Works for both idle for input and Sleep. Counters and Fence Objects usually use this to notify other fence objects to change their appearance, but some other objects use it to facilitate group interaction around a single animated parent object (eg. the pool table).

#### Operand

No Operand.

### 50 - Add/Change the Action String

Changes the current interaction's name to the specified string.

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | String Table ID |
| 2–3 | Unknown |
| 4 | (String# - 1) |
| 5–7 | Unused |

### 51 - prim 51 - (used in Sims 2.0)

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 52 - prim 52 - (used in Sims 2.0)

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 53 - prim 53 - (used in Sims 2.0)

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 54 - prim 54 - (used in Sims 2.0)

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 55 - Sync Field

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 56 - Ownership

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 57 - Start Persistant Dialog

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 58 - End Persistant Dialog

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 59 - Update Persistant Dialog

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 60 - Poll Persistant Dialog

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 61 - Send Maxis Letter

### 62 - Invoke Plugin

Used to hook an object into a plugin UI, aka an EOD. This is used for interactions such as the pizza table.

### 63 - Get Terrain Info

Gets information on the terrain at the position of a specified object. Can either be Me or the Stack Object. (decided by flags)

#### Operand

| Bytes | Field |
|---|---|
| 0–1 | Mode |
| 2 | Flags |
| 3–7 | Unused |

#### Modes

| id | name | notes |
|---|---|---|
| 0 | Four altitudes around object (temp 0-3) | Unknown order, unable to verify, not used. |
| 1 | Slope at object (temp 0-1, interpolatable) | Puts the X slope in 0, Y slope in 1. +slope indicates down towards that direction. Likely is difference between altitudes, default 0. |
| 2 | Fixed coordinates of object (temp 0-4) | Put into temps in order: Tile X, Sub-Tile X (0-15), Tile Y, Sub-Tile Y, Level |
| 3 | Grass height under object (temp 0) | 0-255, Dirt-Grass |
| 4 | Ceiling or roof exists above object (temp 0) | 1/0 = true/false |

#### Flags

| id | name | notes |
|---|---|---|
| 1 | Bi-linear Interpolation | If set, bi-linear interpolation is used for the slope mode. |
| 2 | Use Me instead of Stack Object | If set, the object uses the caller instead of the Stack Object. |
| 3-8 | N/A | Operand only has the two above flags. |

### 64 - Leave Lot and Goto

*This primitive isn't used in any of the behaviors found in The Sims Online.*

### 65 - Find Best Action

Same as TS1 Find Best Interaction, though Free Will was never included in TSO so this primitive was initially replaced with Report Metric. This finds the "best" interaction the sim can perform, eg. the one with the highest advertisments for their lowest motives and other factors. Used for cat and dog free will. Presumably just pushes it to their queue once it finds one, since I can't find anything that queues it afterwards… Returns false when no interaction is found (the sim is suitably satisfied with their current motives, or there is no object to cater to them).

#### Operand

No Operand.

### 66 - Set Dynamic Object Name

### 67 - Inventory Operations

## Notes for NSOClient

- **Exit codes:** 2017 has 11 (`VMPrimitiveExitCode`): go to true or false, the same on the next tick,
  return true or false, error, continue next tick, continue (a subroutine call), interrupt, and
  continue on a future tick (idle primitives).
- **Expression (2):** in 2017 the signed flag is ignored. Values are read as 32-bit integers and written
  back truncated. Arithmetic wraps and shift counts are masked to 5 bits. Dividing by zero sets -1,
  and a remainder by zero leaves the value unchanged. NSOClient's `Primitives.Expression` lists the
  rest of the quirks and matches 2017 case for case (scorecard FID-9).
- Which primitives NSOClient has ported is tracked in [the scorecard](../scorecard.md#simantics).
