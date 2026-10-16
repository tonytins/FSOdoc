# Results

How NSOClient measures up against FreeSO and against the owner's installs. Both files are written
by tools, not by hand, and hold no game data: object GUIDs, chunk IDs, counts, and values only.

| File | Written by | When |
| --- | --- | --- |
| [nso-review.md](nso-review.md) | `NSOClient/scripts/oracle-review.sh --review` | After a phase or milestone, or when asked |
| [install-differences.md](install-differences.md) | `tsofiles-check`, with both `TSO_GAME_DIR` and `TSO_BETA_DIR` set | Once; delete it to compare again |

## nso-review.md

`fso-oracle` runs FreeSO's code (the 2017 snapshot) and `nso-oracle` runs NSOClient. Both answer
the same commands in the same formats, on the same install, and the review compares them: what
matches, every mismatch, what NSOClient doesn't support yet (ranked by how much it blocks), and
how long each side took. Each install gets its own section, with the date and commit it was run
on; a run rewrites only the sections of the installs it covered. Earlier reviews are in the file's
git history.

The review is for sessions picking up the work and for public peer review: anyone can see where
NSOClient stands without a copy of the game. The numbers depend on the install they came from, so
another install can give different ones.

The comparisons the review covers also run as tests (`TSO_ORACLE_DIR`), which are the gate on
every change; the review is the readable record, written only when asked so everyday runs stay
light.
