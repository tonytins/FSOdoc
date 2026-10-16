# tsofiles-check

`tsofiles-check` (the TSOFilesCheck package) is the first test of the file readers against a real
install. It opens every FAR1, FAR3, DBPF, and IFF file, reads every archive entry, and parses every
supported chunk, then reports counts and failures.

```sh
swift run --package-path NSOClient/TSOFilesCheck -c release tsofiles-check
```

## Which installs it checks

- **With a folder argument,** it checks that folder.
- **Without one,** it checks every install named by `TSO_GAME_DIR` (the 2002 production copy) and
  `TSO_BETA_DIR` (the 2002 beta), in that order. `--install game` or `--install beta` picks one.
  Two variables naming the same folder check it once.

Each folder must contain an `objectdata` folder, in any letter case. One that doesn't is reported
and skipped, and the other install is still checked.

## What it prints

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

## The differences report, once

The first time it checks both installs, it compares them and writes
[`docs/install-differences.md`](../install-differences.md) (or the path in `--differences`). After
that it only says the file exists. Delete the file to compare again.

The report lists files only in one install, then, for each file that differs:

- **IFFs and archives of IFFs** (such as `objiff.far`): one row per IFF, with the chunks only in
  each install and those that changed, grouped by type, and the GUIDs of changed objects.
- **Other archives** (avatars, audio): counts of entries added, removed, and changed.

It holds names, sizes, chunk IDs, and GUIDs, never game data, so it can be committed. It's the
reference for backwards compatibility: when something behaves differently on the beta, check
there what the files change before calling it a port bug.
