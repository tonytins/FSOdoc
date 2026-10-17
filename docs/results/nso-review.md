# NSOClient review

SimsCraft is rebuilding the engine of *The Sims Online* (Maxis and EA, 2002) in Swift, as
NSOClient. Its reference is FreeSO, an open-source C# reimplementation of the same game, as it
stood in 2017 (the copy in `TSOClient/`). NSOClient counts as correct when it gives the same
results as FreeSO on the same game files. Neither project ships those files: each run reads a copy
of the game installed on the machine running it.

Two command-line programs make the check. `fso-oracle` runs FreeSO's own code, and `nso-oracle`
runs NSOClient's. Both read the same installed copy of the game and report the same things:

- **Content:** every object the game lists, whether it loads, and what it's made of: its name, the
  file it comes from, the shared library of routines it uses, and how many routines and tuning
  values it has.
- **Entry points:** for each object, which routine runs on each event, such as being created,
  each tick of the simulation, or being used.
- **Objects run alone:** each object placed by itself on an empty lot and simulated for 30 ticks.
  The whole simulation's state is compared, as a checksum, every 10 ticks.
- **Lots run:** each lot loaded with all its objects, as the game's lot server loads it, and
  simulated for 1,800 ticks, compared every 300. The lots are FreeSO's empty lot (which holds a
  mailbox and other fixtures) and a house built in-game. Where NSOClient reaches something it
  doesn't support yet, the run stops there; it's skipped if every comparison before that matched.
- **Primitives:** thousands of generated cases for each ported primitive (one of the game's
  built-in instructions), each run once on a freshly loaded lot with the state the case sets up.
  The lot as loaded, the result, and every change the primitive makes are compared.
- **Room maps:** for each test lot, how its walls divide it into rooms. The lots are generated
  layouts, FreeSO's empty lot, a house built in-game, and a small made-up lot.

Each section below covers one copy of the game. *Production* is a 2002 release of the game
(FreeSO was built against a 2003 one), and *beta* is a 2002 beta. In each table:

- **Matched:** both programs gave the same answer.
- **Mismatched:** their answers differ. Each mismatch is listed, with both answers.
- **Skipped:** cases left out, by reason: FreeSO itself failed, or NSOClient doesn't support
  something yet (such as one of the game's instructions, its *primitives*).
- **Answered where FreeSO failed:** objects NSOClient loads that FreeSO can't.

The last table shows how long each program took for each command.

`NSOClient/scripts/oracle-review.sh --review` writes this page after each phase of work; earlier
reviews are in its git history. It holds only counts, IDs, and values, never the game's own data.
The same comparisons also run as tests in the repository, and on every change, continuous
integration runs them all on a small made-up install.


<!-- install: production -->
## Production

Run on 2026-10-17 at commit `285b2708`.

| Comparison | Matched | Mismatched | Skipped | Answered where FreeSO failed |
| --- | ---: | ---: | ---: | ---: |
| Content | 2833 | 0 | 0 | 44 |
| Entry points | 2833 | 0 | 0 | 0 |
| Objects run alone | 2743 | 0 | 134 | 0 |
| Lots run | 0 | 0 | 2 | 0 |
| Primitive: create_object_instance | 1245 | 0 | 10 | 0 |
| Primitive: expression | 3809 | 0 | 0 | 0 |
| Primitive: find_location_for | 1538 | 0 | 0 | 0 |
| Primitive: play_sound | 160 | 0 | 0 | 0 |
| Primitive: random_number | 71 | 0 | 0 | 0 |
| Primitive: refresh | 40 | 0 | 0 | 0 |
| Primitive: set_to_next | 225 | 0 | 0 | 0 |
| Primitive: sleep | 135 | 0 | 0 | 0 |
| Primitive: test_object_type | 48 | 0 | 0 | 0 |
| Room maps | 63 | 0 | 0 | 0 |

**Objects run alone, skipped:**

- 89: FreeSO couldn't run it
- 8: unsupported: primitive 28 (run_tree_by_name)
- 6: unsupported: primitive 25 (transfer_funds)
- 5: unsupported: primitive 11 (get_distance_to)
- 5: unsupported: primitive 15 (breakpoint)
- 5: unsupported: primitive 17 (idle_for_input)
- 3: unsupported: primitive 18 (remove_object_instance)
- 3: unsupported: primitive 41 (set_balloon_headline)
- 3: unsupported: primitive 46 (snap)
- 2: unsupported: primitive 35 (special_effect)
- 2: unsupported: primitive 49 (stackobj_notify_out_of_idle)
- 1: unsupported: primitive 26 (relationship)
- 1: unsupported: primitive 48 (stop_all_sounds)
- 1: unsupported: primitive 63 (get_terrain_info)

**Lots run, skipped:**

- 2: unsupported: primitive 28 (run_tree_by_name)

**Primitive: create_object_instance, skipped:**

- 10: unsupported: an interaction callback on a new object needs interactions

| Command | Seconds |
| --- | ---: |
| `fso list-objects` | 3.0 |
| `fso room-maps` | 3.0 |
| `fso run-lot` | 4.8 |
| `fso run-objects` | 23.3 |
| `fso run-primitive create_object_instance` | 12.2 |
| `fso run-primitive expression` | 30.3 |
| `fso run-primitive find_location_for` | 14.9 |
| `fso run-primitive play_sound` | 4.2 |
| `fso run-primitive random_number` | 3.3 |
| `fso run-primitive refresh` | 3.0 |
| `fso run-primitive set_to_next` | 5.5 |
| `fso run-primitive sleep` | 4.0 |
| `fso run-primitive test_object_type` | 3.0 |
| `nso list-objects` | 1.9 |
| `nso room-maps` | 0.9 |
| `nso run-lot` | 0.5 |
| `nso run-objects` | 17.5 |
| `nso run-primitive create_object_instance` | 10.8 |
| `nso run-primitive expression` | 39.4 |
| `nso run-primitive find_location_for` | 13.1 |
| `nso run-primitive play_sound` | 1.5 |
| `nso run-primitive random_number` | 0.7 |
| `nso run-primitive refresh` | 0.5 |
| `nso run-primitive set_to_next` | 2.0 |
| `nso run-primitive sleep` | 1.3 |
| `nso run-primitive test_object_type` | 0.6 |
<!-- end install -->

<!-- install: beta -->
## Beta

Run on 2026-10-17 at commit `285b2708`.

| Comparison | Matched | Mismatched | Skipped | Answered where FreeSO failed |
| --- | ---: | ---: | ---: | ---: |
| Content | 2650 | 0 | 0 | 44 |
| Entry points | 2649 | 0 | 0 | 0 |
| Objects run alone | 2559 | 0 | 135 | 0 |
| Lots run | 0 | 0 | 2 | 0 |
| Primitive: create_object_instance | 1185 | 0 | 10 | 0 |
| Primitive: expression | 3809 | 0 | 0 | 0 |
| Primitive: find_location_for | 1538 | 0 | 0 | 0 |
| Primitive: play_sound | 160 | 0 | 0 | 0 |
| Primitive: random_number | 71 | 0 | 0 | 0 |
| Primitive: refresh | 40 | 0 | 0 | 0 |
| Primitive: set_to_next | 225 | 0 | 0 | 0 |
| Primitive: sleep | 135 | 0 | 0 | 0 |
| Primitive: test_object_type | 48 | 0 | 0 | 0 |
| Room maps | 63 | 0 | 0 | 0 |

**Objects run alone, skipped:**

- 90: FreeSO couldn't run it
- 8: unsupported: primitive 28 (run_tree_by_name)
- 6: unsupported: primitive 25 (transfer_funds)
- 5: unsupported: primitive 11 (get_distance_to)
- 5: unsupported: primitive 15 (breakpoint)
- 5: unsupported: primitive 17 (idle_for_input)
- 3: unsupported: primitive 18 (remove_object_instance)
- 3: unsupported: primitive 41 (set_balloon_headline)
- 3: unsupported: primitive 46 (snap)
- 2: unsupported: primitive 35 (special_effect)
- 2: unsupported: primitive 49 (stackobj_notify_out_of_idle)
- 1: unsupported: primitive 26 (relationship)
- 1: unsupported: primitive 48 (stop_all_sounds)
- 1: unsupported: primitive 63 (get_terrain_info)

**Lots run, skipped:**

- 2: unsupported: primitive 28 (run_tree_by_name)

**Primitive: create_object_instance, skipped:**

- 10: unsupported: an interaction callback on a new object needs interactions

| Command | Seconds |
| --- | ---: |
| `fso list-objects` | 3.8 |
| `fso room-maps` | 3.0 |
| `fso run-lot` | 5.2 |
| `fso run-objects` | 22.8 |
| `fso run-primitive create_object_instance` | 14.5 |
| `fso run-primitive expression` | 29.0 |
| `fso run-primitive find_location_for` | 15.3 |
| `fso run-primitive play_sound` | 4.1 |
| `fso run-primitive random_number` | 3.1 |
| `fso run-primitive refresh` | 2.7 |
| `fso run-primitive set_to_next` | 4.8 |
| `fso run-primitive sleep` | 3.9 |
| `fso run-primitive test_object_type` | 2.8 |
| `nso list-objects` | 1.5 |
| `nso room-maps` | 0.9 |
| `nso run-lot` | 0.5 |
| `nso run-objects` | 16.6 |
| `nso run-primitive create_object_instance` | 9.7 |
| `nso run-primitive expression` | 35.8 |
| `nso run-primitive find_location_for` | 12.4 |
| `nso run-primitive play_sound` | 1.4 |
| `nso run-primitive random_number` | 0.7 |
| `nso run-primitive refresh` | 0.5 |
| `nso run-primitive set_to_next` | 2.0 |
| `nso run-primitive sleep` | 1.2 |
| `nso run-primitive test_object_type` | 0.5 |
<!-- end install -->
