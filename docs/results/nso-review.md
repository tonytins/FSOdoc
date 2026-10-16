# NSOClient review

`fso-oracle` runs FreeSO's code (the 2017 snapshot) and `nso-oracle` runs NSOClient, on the
same install and the same questions. This page compares their answers, one section per
install, for sessions picking up the work and for public peer review. It's written by
`NSOClient/scripts/oracle-review.sh --review` after a phase or milestone; earlier reviews are
in its git history. It holds counts, GUIDs, case IDs, and values, never game data.

The primitive-by-primitive comparisons run as tests (scorecard FID-9) until `nso-oracle` can
load a lot by itself.

<!-- install: production -->
## Production

Run on 2026-10-16 at commit `6711e871`.

| Comparison | Matched | Mismatched | Skipped | Answered where FreeSO failed |
| --- | ---: | ---: | ---: | ---: |
| Content | 2833 | 0 | 0 | 44 |
| Entry points | 2833 | 0 | 0 | 0 |
| Objects run alone | 2743 | 0 | 134 | 0 |
| Room maps | 62 | 0 | 0 | 0 |

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

| Command | Seconds |
| --- | ---: |
| `fso list-objects` | 3.5 |
| `fso room-maps` | 3.8 |
| `fso run-objects` | 25.8 |
| `nso list-objects` | 1.7 |
| `nso room-maps` | 0.9 |
| `nso run-objects` | 9.6 |
<!-- end install -->

<!-- install: beta -->
## Beta

Run on 2026-10-16 at commit `6711e871`.

| Comparison | Matched | Mismatched | Skipped | Answered where FreeSO failed |
| --- | ---: | ---: | ---: | ---: |
| Content | 2650 | 0 | 0 | 44 |
| Entry points | 2649 | 0 | 0 | 0 |
| Objects run alone | 2559 | 0 | 135 | 0 |
| Room maps | 62 | 0 | 0 | 0 |

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

| Command | Seconds |
| --- | ---: |
| `fso list-objects` | 3.5 |
| `fso room-maps` | 3.1 |
| `fso run-objects` | 25.4 |
| `nso list-objects` | 1.6 |
| `nso room-maps` | 0.9 |
| `nso run-objects` | 9.1 |
<!-- end install -->
