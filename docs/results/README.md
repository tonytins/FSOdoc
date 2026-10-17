# Results

SimsCraft is rebuilding the engine of *The Sims Online* (Maxis and EA, 2002) in Swift, as
NSOClient, using FreeSO, an open-source C# reimplementation of the game as it stood at its beta/update-46 build (August 2017), as
its reference. This folder records how close NSOClient is, measured on real copies of the game.

Neither project ships the game's files, so the measurements are run on copies installed on the
maintainer's machine, and only the outcome is published here. Tools write both files, not people.
They hold counts, object IDs (GUIDs), file and chunk names, and values, never the game's own data.

| File | What it shows | Written by | When |
| --- | --- | --- | --- |
| [nso-review.md](nso-review.md) | Whether NSOClient and FreeSO behave the same, experiment by experiment: where they agree, every disagreement, and what's inconclusive | `NSOClient/scripts/oracle-review.sh --review` | After each phase of work |
| [install-differences.md](install-differences.md) | How the two copies of the game used here differ, file by file | `tsofiles-check` | Once |

## nso-review.md

A report for peer review that asks one question: given the same game files and inputs, do
NSOClient and FreeSO behave the same? Two command-line programs run the same experiments on the
same copy of the game: `fso-oracle` runs FreeSO's code, and `nso-oracle` runs NSOClient's. They
record which objects load and what they contain, which routine each object runs on each event,
the state of the simulation as each object or lot runs, how each primitive behaves case by case,
and how walls divide test lots into rooms. The report counts where the two agree, lists every
disagreement with both results, and says why the rest are inconclusive (FreeSO failed, or NSOClient
doesn't support something yet). The page explains each experiment in full.

Agreement is the aim, since FreeSO's results are NSOClient's source of truth for the simulation,
but the report doesn't assume it. A disagreement is a finding to explain: a bug in NSOClient, a
quirk of FreeSO, or a deliberate difference. Some findings go NSOClient's way, such as objects it
loads that FreeSO can't.

Each copy of the game gets its own section, with the date and the commit it was run on. A new run
replaces only the sections of the copies it covered, and earlier reports are in the file's git
history. Results can differ from one copy of the game to another.

The same experiments also run as checks in the repository. The report is written only after a
phase of work, because it reruns every experiment on every copy; on every push, continuous
integration runs them on `NSOClient/MockInstall`, a small made-up install with no game data, and
stops a change that introduces a new disagreement until someone has looked at it.

## install-differences.md

The project uses two copies of the game: a 2002 production release (FreeSO was built against a
2003 one) and a 2002 beta. This file lists the files only one of them has and, for files in both
that differ, which objects and resources inside changed. When NSOClient or FreeSO behaves
differently on the two copies, it shows what changed in the game's files, before anyone looks for a
bug in the code. It's written once; deleting it and running `tsofiles-check` on both copies
writes it again.
