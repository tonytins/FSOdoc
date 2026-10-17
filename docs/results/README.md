# Results

SimsCraft is rebuilding the engine of *The Sims Online* (Maxis and EA, 2002) in Swift, as
NSOClient, using FreeSO, an open-source C# reimplementation of the game as it stood in 2017, as
its reference. This folder records how close NSOClient is, measured on real copies of the game.

Neither project ships the game's files, so the measurements are run on copies installed on the
maintainer's machine, and only the outcome is published here. Tools write both files, not people.
They hold counts, object IDs (GUIDs), file and chunk names, and values, never the game's own data.

| File | What it shows | Written by | When |
| --- | --- | --- | --- |
| [nso-review.md](nso-review.md) | How often NSOClient gives the same answers as FreeSO, and why it doesn't when it doesn't | `NSOClient/scripts/oracle-review.sh --review` | After each phase of work |
| [install-differences.md](install-differences.md) | How the two copies of the game used here differ, file by file | `tsofiles-check` | Once |

## nso-review.md

Two command-line programs answer the same questions about the same copy of the game: `fso-oracle`
runs FreeSO's code, and `nso-oracle` runs NSOClient's. They report which objects load and what
they contain, which routine each object runs on each event, the state of the simulation as each
object runs by itself, and how walls divide test lots into rooms. The review counts where the two
agree, lists every disagreement, and says why the rest were skipped (FreeSO failed too, or NSOClient
doesn't support something yet). The page explains each comparison in full.

Each copy of the game gets its own section, with the date and the commit it was run on. A new run
replaces only the sections of the copies it covered, and earlier reviews are in the file's git
history. Results can differ from one copy of the game to another.

The same comparisons also run as tests in the repository, and those tests must pass for every
change; the review is the readable record. It's written only after a phase of work, because it
reruns every object on every copy. On every push, continuous integration runs both programs on
`NSOClient/MockInstall`, a small made-up install with no game data.

## install-differences.md

The project uses two copies of the game: a 2002 production release (FreeSO was built against a
2003 one) and a 2002 beta. This file lists the files only one of them has and, for files in both
that differ, which objects and resources inside changed. When NSOClient or FreeSO behaves
differently on the two copies, it shows what changed in the game's files, before anyone looks for a
bug in the code. It's written once; deleting it and running `tsofiles-check` on both copies
writes it again.
