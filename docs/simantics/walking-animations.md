# Walking Animations

> From the SimAntics Wiki ([Walking Animations](https://simantics.wikidot.com/wiki:walking-animations)), retrieved 2026-10-16, by its contributors, under
> [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Converted to Markdown and lightly
> edited; sections headed "Notes for NSOClient" are ours. See [README.md](README.md).

Routing in the sims is not controlled by SimAntics, instead it is controlled by an external "Walking Engine" which takes over from the avatar's SimAntics thread when one of the routing primitives (Goto Routing Slot, Goto Relative Position) is called. As such, a few animation pointers are hard-coded into the game to use for certain types of sim (male, female, cat, dog).

## Walk Styles

| Name | Adult | Cat | Dog |
|---|---|---|---|
| Walking Start | a2o-walking-start.anim | k2o-walking-start.anim | d2o-walking-start.anim |
| Walking Loop | a2o-walking-loop.anim | k2o-walking-loop.anim | d2o-walking-loop.anim |
| Running Start | a2o-running-start.anim | k2o-running-start.anim | d2o-running-start.anim |
| Running Loop | a2o-running-loop.anim | k2o-running-loop.anim | d2o-running-loop.anim |
| Bear Walk Start | a2o-bear-walking-start.anim | N/A | N/A |
| Bear Walk Loop | a2o-bear-walking-loop.anim | N/A | N/A |
| Raccoon Walk Start | N/A | N/A | d2o-raccoon-walk-start.anim |
| Raccoon Walk Loop | N/A | N/A | d2o-raccoon-walk-loop.anim |
| Raccoon Run Start | N/A | N/A | d2o-raccoon-walk-start.anim |
| Raccoon Run Loop | N/A | N/A | d2o-raccoon-walk-loop.anim |

Rotations while moving are achieved simply by gradually rotating the character while the walking loop is playing.

## Rotations before and after routing

| Direction | Adult | Adult (running) | Cat | Dog |
|---|---|---|---|---|
| 180 CCW | a2o-standing-turn-180-ccw.anim | a2o-running-turn-180-ccw.anim | k2o-turn-180-ccw.anim | d2o-turn-180-ccw.anim |
| 90 CCW | a2o-standing-turn-90-ccw.anim | a2o-running-turn-90-ccw.anim | k2o-turn-90-ccw.anim | d2o-turn-90-ccw.anim |
| 45 CCW | a2o-standing-turn-45-ccw.anim | a2o-running-turn-45-ccw.anim | k2o-turn-45-ccw.anim | d2o-turn-45-ccw.anim |
| 0 | a2o-standing-turn-0.anim | a2o-running-turn-0.anim | k2o-turn-0.anim | d2o-turn-0.anim |
| 45 CW | a2o-standing-turn-45-cw.anim | a2o-running-turn-45-cw.anim | k2o-turn-45-cw.anim | d2o-turn-45-cw.anim |
| 90 CW | a2o-standing-turn-90-cw.anim | a2o-running-turn-90-cw.anim | k2o-turn-90-cw.anim | d2o-turn-90-cw.anim |
| 180 CW | a2o-standing-turn-180-cw.anim | a2o-running-turn-180-cw.anim | k2o-turn-180-cw.anim | d2o-turn-180-cw.anim |

NOTE: 135 degree rotations are achieved by gradually rotating the sim while playing the 90 degree rotation.
