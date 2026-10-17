# Tools

## tsofiles-check

`tsofiles-check` (the TSOFilesCheck package) is the first test of the file readers against a real
install. It opens every FAR1, FAR3, DBPF, and IFF file, reads every archive entry, and parses every
supported chunk, then reports counts and failures.

```sh
swift run --package-path NSOClient/TSOFilesCheck -c release tsofiles-check
```

### Which installs it checks

- **With a folder argument,** it checks that folder.
- **Without one,** it checks every install named by `TSO_GAME_DIR` (the 2002 production copy) and
  `TSO_BETA_DIR` (the 2002 beta), in that order. `--install game` or `--install beta` picks one.
  Two variables naming the same folder check it once.

Each folder must contain an `objectdata` folder, in any letter case. One that doesn't is reported
and skipped, and the other install is still checked.

### What it prints

For each install, a header and a summary:

```text
== TSO_GAME_DIR: /home/user/Applications/tso/TSOClient
FAR1: 13 files
FAR3: 47 files
DBPF: 7 files
IFF: 29 files
entries read: 84912 (IFFs inside archives: 1578)
chunks parsed: 50798 (BCON 784, BHAV 15906, ...)
other files: 1590
failures: 0
unreferenced chunks that don't parse (the game never loads them): 5
```

Failures name the file, the archive entry, and the chunk (`objiff.far: chairs.iff: TTAB #128`).
`--max-failures N` limits how many are listed (all are counted), and `--headers-only` opens archives
without reading entries. `--far1-variant a` reads The Sims 1's FAR layout.

Exit codes: 0 when everything reads, 1 when anything fails, 2 when a folder isn't an install or
can't be listed.

### The differences report, once

The first time it checks both installs, it compares them and writes
[`docs/results/install-differences.md`](../results/install-differences.md) (or the path in `--differences`). After
that it only says the file exists. Delete the file to compare again.

The report lists files only in one install, then, for each file that differs:

- **IFFs and archives of IFFs** (such as `objiff.far`): one row per IFF, with the chunks only in
  each install and those that changed, grouped by type, and the GUIDs of changed objects.
- **Other archives** (avatars, audio): counts of entries added, removed, and changed.

It holds names, sizes, chunk IDs, and GUIDs, never game data, so it can be committed. It's the
reference for backwards compatibility: when something behaves differently on the beta, check
there what the files change before calling it a bug in NSOClient.

## nso-oracle

`nso-oracle` (the NSOOracle package) runs the experiments `fso-oracle` runs on FreeSO, on
NSOClient instead, and records the results in `fso-oracle`'s formats, so the two records can be
compared line for line. The comparison asks whether they agree, without assuming it: a
disagreement is a finding to explain, and a case one side couldn't measure is inconclusive.



| Command | Records |
| --- | --- |
| `list-objects` | What loads for every registered object: label, resource, semi-global, routine and tuning counts, entry points |
| `run-objects` | Each GUID on standard input run alone on an empty lot, with a state digest after creation and as it ticks |
| `run-lot` | One lot (`--blueprint`) loaded with its objects and run, with a state digest after loading and as it ticks; `--leave-out GUID` leaves out an object `fso-oracle` left out, and `--dump` adds every entity's digested fields |
| `run-primitive` | `fso-oracle`'s JSON requests on standard input, each on a freshly loaded lot (`--blueprint`, `--leave-out`), answered in its format: the lot as loaded, the exit code, registers, and every effect; `unsupported` where a primitive isn't ported |
| `room-maps` | Each blueprint path on standard input: its room maps and rooms |
| `compare` | Whether both sides' records agree, experiment by experiment, and with `--review FILE`, that install's section of the report written; `--strict` exits with an error on any disagreement |

Where NSOClient can't take a measurement yet, `run-objects` adds an `unsupported` line naming what
isn't ported; comparisons count those as inconclusive, ranked, so they show what to port next.
`run-lot` stops at the first tick that reaches something not ported, with `unsupported at tick
N:` and what.

```sh
cut -f1 objects.tsv | swift run --package-path NSOClient/NSOOracle nso-oracle run-objects --ticks 30 --every 10
```

`NSOClient/scripts/oracle-review.sh [--review | --mock]` runs both oracles on every install it's
given (`TSO_GAME_DIR` as "production", `TSO_BETA_DIR` as "beta") and compares them; `--mock` uses
`NSOClient/MockInstall` instead, as CI does, and stops on any disagreement (`compare --strict`) so a
person looks at it before the change goes in.
FreeSO's side comes from `oracle-fixtures.sh`. With `--review` it writes
[docs/results/nso-review.md](../results/nso-review.md); do that only after a phase of the roadmap,
since it reruns every object and primitive case. The same comparisons run as NSOOracle's tests
against FreeSO's records, sharing the same code, so the checks and the report can't contradict
each other.
