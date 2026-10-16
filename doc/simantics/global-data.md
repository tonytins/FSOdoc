# Global Data

> From the SimAntics Wiki ([Global Data](https://simantics.wikidot.com/wiki:global-data)), retrieved 2026-10-16, by its contributors, under
> [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Converted to Markdown and lightly
> edited; sections headed "Notes for NSOClient" are ours. See [README.md](README.md).

**Global Data** refers to the fields containing information about the game state. There are 33 in total, and each can be accessed by SimAntics via a [Scope](scopes.md).

| id | name | notes |
|---|---|---|
| 0 | Hour (Deprecated, see CityTime, TST or GameTime) | Accessed via TST, CityTime, GameTime scopes in TSO. Unsure if they are still meant to be functional. |
| 1 | Day Of Month (DEPRECATED) | See 0 |
| 2 | Zoom Level (S/M/L) | Only used by tutorial, unused by TSO objects. 1=near, 2=med, 3=far |
| 3 | Selected Person ID | The ID of the Person currently selected by the client. |
| 4 | Time of Day (DEPRECATED) | See 0 |
| 5 | Minute (DEPRECATED) | See 0 |
| 6 | Second (DEPRECATED) | See 0 |
| 7 | Month (DEPRECATED) | See 0 |
| 8 | Year (DEPRECATED) | See 0 |
| 9 | Current Family | Unused by any TSO objects. There are some holdovers in the unused pet show object. |
| 10 | Current House | Probably Unused. Lots of holdovers for eg. phone globals (can't call people already over, etc) but doesn't look like they get called… |
| 11 | Online Job Lot Grade | Set when creating the job lot's simulator. Controls whether Sims can access via the door etc. |
| 12 | Last GZ Button ID | Only used in help system, which is not used. |
| 13 | Budget Mod 10000 | Low part of budget. Not used by any TSO objects, but again there are holdovers in unused ones. |
| 14 | Budget Div 10000 | High part of budget. |
| 15 | Current Language | There are a few special cases in newspaper for the german language code, where it uses a special model for the newspaper. |
| 16 | Speed | Only used in help system (since speed cannot be changed in TSO! 1000 seems to be the max. |
| 17 | Runtime Code Version | Changes behaviour of some TSO functions depending on value. 3 seems to be the max/ideal/new and improved version. |
| 18 | Unused_18 |  |
| 19 | Mode | Live/Buy/Build… Used by awnings to change display, counters and help system. |
| 20 | Game Edition | A bitfield. Probably to detect which expansion packs are installed… Too bad TSO doesn't have any! |
| 21 | Controller ID | The Job Controller's ID, used by the three OnlineJobs. One of the few globals actually used… |
| 22 | InHardCoreCity | Affects tuning of several objects to make things "harder". Used in Dragon's Cove in the original. |
| 23 | Lot Size | I was unable to locate a single use of this. Most likely the current lot size, probably only used by non simantics things like build/buy and the lot size upgrade UI. |
| 24 | Is Online? | 1 or 0. I don't see why this would ever be 0, but there are special cases for it when dealing with people |
| 25 | Debug flags | If flag 1 is set, the game enables "Debug Balloons" using a function in globals. Not sure what these are, but I'd like to find out! Some other flags are used too. |
| 26 | Sims1.0 Is Tutorial House (No/Yes) | No. Definitely not. Always 0. |
| 27 | Unused_27 |  |
| 28 | Days Running | How many Sim days the house has been running. Used to start the easter egg messages in The Sims 1 past 100. Objects occasionally set Day Created to this. |
| 29 | Unused_29 |  |
| 30 | Free Will | If 0, food objects do not call everyone to eat when they are served. |
| 31 | House radio station | The radio station playing throughout the house. Set by various sound systems and the piano when an NPC is playing. |
| 32 | Unused32 |  |

Most of these are unused, especially the UI related ones, probably to avoid risking a client/server desync.

## Notes for NSOClient

Checked against the 2017 FreeSO snapshot (`VM.cs`):

- 2017 keeps 38 globals (0 to 37); reading or writing past them fails.
- A new lot starts with 17 (runtime code version) at 4, 20 (game edition) at 255, and 25 at 4.
  FreeSO's comments say EA-Land used 4 for both, and that 25 must be 4 for Sims' idle interactions.
- Every tick, the clock is copied into 0 (hour), 4 (time of day), 5 (minute), and 6 (second).
