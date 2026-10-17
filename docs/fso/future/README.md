# Beyond the snapshot: FreeSO's other branches

The rest of [`docs/fso/`](../README.md) describes FreeSO at beta/update-46 (August 2017), the snapshot in
[`TSOClient/`](../../../TSOClient/). This repository also carries four of FreeSO's branches. Two of
them led *into* the snapshot; two carry FreeSO's development *after* it. "Future" is relative to the
snapshot: all of this work was finished long ago.

The pages come from reading each branch's commit history and the shape of its changes (which
projects and files changed). The branches weren't built or run, and individual features weren't
read line by line, so details are as the commit messages describe them.

| Branch | When | Relation to the snapshot | Page |
| --- | --- | --- | --- |
| `lot-serialize` | Oct 2015 | Merged; it's in the snapshot | [lot-serialize.md](lot-serialize.md) |
| `feature/server-rebuild` | Aug 2015 – May 2017 | Merged in May 2017; it's in the snapshot | [server-rebuild.md](server-rebuild.md) |
| `feature/upgrades` | Aug 2017 – Jul 2019 | 265 commits past the snapshot | [upgrades.md](upgrades.md) |
| `feature/lotview-refactor` | Apr – Oct 2019 | All of `feature/upgrades`, plus 72 commits | [lotview-refactor.md](lotview-refactor.md) |

```text
2015 ── lot-serialize ──┐
2015 ── server-rebuild ─┴─▶ main (snapshot, 2017-08-09/10)
                                 │
                                 └─▶ feature/upgrades (to 2019-07) ─▶ feature/lotview-refactor (to 2019-10)
```

To look at one yourself:

```sh
git log --oneline origin/feature/upgrades ^main          # commits past the snapshot
git diff --stat main...origin/feature/lotview-refactor   # what changed since they split
```

## Why I stuck with the update-46 snapshot

FreeSO's later work has a lot of great features, but I wasn't too
fond of 3D. At that point, you might as well have just made The Sims 2 Online. It made an already
complicated engine even more daunting and confusing, and it would have gone well beyond the scope
of what this project remains about: understanding the original game. The update-46 snapshot is still close
enough to TSO to learn from, so that's where I drew the line.

## Why it matters here

NSOClient matches the snapshot's results, so these branches aren't its reference. They're useful
in two ways:

- **What came next.** Many fixes past the snapshot (desyncs, interactions, collisions, crashes)
  show where the snapshot's behavior was wrong or fragile. When NSOClient decides how to handle a bug in
  the snapshot, the later fix is evidence of what FreeSO itself settled on.
- **Ideas past the baseline.** NSOClient's third goal goes beyond the snapshot (SimAntics extensions,
  scripting). FreeSO later added an ahead-of-time SimAntics compiler, new TSO calls, object
  upgrades, and tuning presets, which are worth knowing about before designing our own.
