# Person Data

> From the SimAntics Wiki ([Person Data](https://simantics.wikidot.com/wiki:person-data)), retrieved 2026-10-16, by its contributors, under
> [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Converted to Markdown and lightly
> edited; sections headed "Notes for NSOClient" are ours. See [README.md](README.md).

**Person Data** refers to a person's built in fields such as their age, skill points, personality, if they are a ghost etc. There are 100 in total, and each can be accessed by SimAntics via a [Scope](scopes.md). These variables should be stored with the sim in the database and applied when recreating the sim in a lot they're visiting. (eg. these should follow them around)

| id | name | notes |
|---|---|---|
| 0 | Posture | Standing/Sitting/Kneeling |
| 1 | Money Amount over Head | Defaults to -32768, presumably meaning the display is disabled. |
| 2 | Nice Personality | 0-1000 Range |
| 3 | Active Personality | 0-1000 Range |
| 4 | Generous Personality | 0-1000 Range |
| 5 | Playful Personality | 0-1000 Range |
| 6 | Outgoing Personality | 0-1000 Range |
| 7 | Neat Personality | 0-1000 Range |
| 8 | Current Outfit | The sim's current outfit ID. |
| 9 | Skill Efficiency | Involved in a lot of Global functions tagged *DEPRECATED*, so may not be functional. |
| 10 | Cooking Skill | The sim's cooking skill. Divide by 100 to get value in skill points. |
| 11 | Charisma Skill | The sim's charisma skill. Divide by 100 to get value in skill points. |
| 12 | Mechanical Skill | The sim's mechanical skill. Divide by 100 to get value in skill points. |
| 13 | Network ID | Some plants and the Magazine stack seem to set this to various values… May be a holdover from when this meant something else in TS1 though. |
| 14 | Online Status |  |
| 15 | Creativity Skill | The sim's creativity skill. Divide by 100 to get value in skill points. |
| 16 | Custom Outfit Index |  |
| 17 | Body Skill | The sim's body skill. Divide by 100 to get value in skill points. |
| 18 | Logic Skill | The sim's logic skill. Divide by 100 to get value in skill points. |
| 19 | Unused & Do NOT Use | Is actually used in fridges… |
| 20 | Allowed Social and Puppeteering? |  |
| 21 | Is Housemate? | 1:true, 0:false |
| 22 | Hand Gesture - Left | 0: Hand Open, 1: Hand Palm, 2: Hand Closed. Is set to 0 a lot and is only set to anything else by the dresser semi globals… So might be unused. |
| 23 | Hand Gesture - Right | Same as above. |
| 24 | Job Data | Completely Unused by TSO. |
| 25 | Tree Use Data Field |  |
| 26 | Chat Balloon On? |  |
| 27 | Tick Counter |  |
| 28 | Tree Use Data Field 2 |  |
| 29 | Cheats | Used to allow sims to do things normal sims cannot, eg. the maid can enter roommate only doors. 1:true, 0:false |
| 30 | Censorship Flags | 8 bits: bit 0=Pelvis, 1=Spine if Female, 2=Head, 3=Left Hand, 4=Right Hand, 5=Left Foot, 6=Right Foot, 7=Full Body |
| 31 | Neighbor ID |  |
| 32 | Person Type | 2 for NPCs. |
| 33 | Priority |  |
| 34 | Greet Status |  |
| 35 | Visitor Schedule |  |
| 36 | Autonomy Level | 0-100 |
| 37 | Route Entry Flags | Set after routing primitive, tells the object which direction the entry point is at. 1 = front, 4 = right, 16 = back, 64 = left. You can fill in the gaps. |
| 38 | Multiple Routes |  |
| 39 | Routing Complete |  |
| 40 | Walking Up Stairs | true: 1, false:0 |
| 41 | Head Seek Object |  |
| 42 | Head Seek State |  |
| 43 | Head Seek Finish Action |  |
| 44 | Head Seek Limit Action |  |
| 45 | Head Seek Timeout |  |
| 46 | i: Travel/Toys | Start interests section. These control the topics chosen by the Chat interaction. Range 1-10 |
| 47 | i: Violence/Aliens | Range 1-10 |
| 48 | i: Politics/Pets | Range 1-10 |
| 49 | i: 60's/School | Range 1-10 |
| 50 | i: Weather | Range 1-10 |
| 51 | i: Sports | Range 1-10 |
| 52 | i: Music | Range 1-10 |
| 53 | i: Outdoors | End interests section. Range 1-10 |
| 54 | Unused & Do NOT Use | These ones actually aren't used I think. |
| 55 | Unused & Do NOT Use |  |
| 56 | Job Type |  |
| 57 | Job Promotion Level |  |
| 58 | Person Age | <18 signifies a child, though 0 signals an adult (see Am I A Child/Adult behaviours). Most NPC sims are 27. |
| 59 | Interaction Status |  |
| 60 | Skin Color | Only used by petmaternitybox. Most likely 0:light, 1:med, 2:dark, unsure for pets. |
| 61 | Incoming Friends | Is a family ID of some sort. References are left but I don't think this is functional. |
| 62 | Route Result |  |
| 63 | Job Performance | Not used by TSO, though the bookcases have some references left in for kids studying for school. |
| 64 | Is Swimming? | 1:true, 0:false |
| 65 | Gender | 0=male, 1=female |
| 66 | Private |  |
| 67 | Lingering House Number |  |
| 68 | Is Ghost? | 0=Normal, 1=Ghost. Used by campfire ghost, and presumably player ghosts. |
| 69 | Chat Color | Used by game when rendering chat bubble above sim. |
| 70 | SkillLock | A bitfield containing information on which skills have skill locks on this sim. |
| 71 | Non-Interruptible | 1 means the current action cannot be interrupted. (eg. dying!) |
| 72 | Route Footprint Mask |  |
| 73 | Footprint Extension |  |
| 74 | Render Display Flags |  |
| 75 | SocialTargetID |  |
| 76 | Current Object |  |
| 77 | Hat ID | Used by the hat rack object to track what hat the person is currently wearing. |
| 78 | Decoration Flags |  |
| 79 | Decoration Dirty Flags |  |
| 80 | Interaction Mask |  |
| 81 | SkillLockBody | This avatar's skill lock for the body skill. Used by jobdegrade to determine lower bound of degrading skill. |
| 82 | SkillLockCharisma | Same as above but with charisma. |
| 83 | SkillLockCooking | Same as above but with cooking. |
| 84 | SkillLockCreativity | Same as above but with creativity. |
| 85 | SkillLockLogic | Same as above but with logic. |
| 86 | SkillLockMechanical | Same as above but with mechanical. |
| 87 | Death Ticker | Handles death duration (in minutes). Set to (#Global Tuning Auto-Revival Hours (max 540))*60 upon death and ticked over by the Death Controller. |
| 88 | Gardener Rehire Ticker | Intended to cause a delay between firing the Gardener and when you can rehire them. Set by NPC Controller when NPC is fired. |
| 89 | Maid Rehire Ticker | Same as above but with the Maid. |
| 90 | Repairman Rehire Ticker | Same as above but with the Repairman |
| 91 | OnlineJobID | Used by OnlineJobs to determine what Job this sim has. |
| 92 | OnlineJobGrade | Used by OnlineJobs to determine what grade this sim is working at. |
| 93 | OnlineJobXP | Used by OnlineJobs to keep track of job perfomance for promotions. All logic handled via SimAntics. |
| 94 | OnlineJobSickDays | Used by OnlineJobs to keep track of job sick days. All logic handled via SimAntics. |
| 95 | RandomSkinIndex | Initially -1 |
| 96 | RandomHeadIndex | Initially -1 |
| 97 | RandomSkinColor | Initially -1 |
| 98 | OnlineJobStatusFlags |  |
| 99 | NumOutgoingFriends |  |
| 100 | BadgeLevel |  |

## Notes for NSOClient

FreeSO's `VMAvatar` stores 101 values (0 to 100), matching the table above.
