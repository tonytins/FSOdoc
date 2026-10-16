# `feature/upgrades`: FreeSO after the snapshot (August 2017 – July 2019)

**Status:** not in the snapshot. The branch starts from the snapshot's last commit (August 10,
2017, "Client and Server compile for Any CPU") and adds 265 commits through July 18, 2019:
1,914 files changed, about 196,000 lines added and 23,000 removed. Despite its name, it holds
nearly two years of FreeSO's mainline development; the object upgrades system it's named for is
only its last two commits.

About 1,100 files are new. Most are content (patches, textures, UI graphics in `tso.content`), then
client UI, server, database, SimAntics, and Volcanic. New projects include `FSO.SimAntics.JIT`,
`FSO.Server.Api.Core`, `FSO.Server.Core`, `FSOFacadeWorker`, and `FSO.Windows`.

## Rendering and the client

- **3D mode** (September 2017): a `-3d` launch option that reconstructs objects as meshes, with
  mipmaps, anisotropic filtering, 3D wall shadows (also used in 2D), and mesh replacements that
  Volcanic can import or that live in the object's IFF. Later: depth masks and portal depth masks
  (for fireplaces and similar), asynchronous mesh generation, and a 3D city view (May 2018) with
  touch controls.
- **Lighting:** an "ultra" mode with 3D object shadows (October 2017), soft shadows with a
  separable blur, contact-hardened shadows, and new roof geometry.
- **Weather and particles:** snow that rotates with time, particles, and a December snow theme.
- **UI:** keyboard shortcuts (F1–F5 modes, panning, rotating, floors), resizable chat, a graphics
  options page with DPI scaling, a hints system, a new font renderer with fallback fonts, an
  in-game newspaper with payout graphs, job info dialogs, and Discord rich presence.
- **Animation speed:** all animations run at 1.2× (June 2018), because FreeSO had been playing
  them slower than TSO and The Sims 1.

## SimAntics and gameplay

- **Recording** (`.fsor`, September 2017): the server records lots so a stuck lot can be replayed
  in a developer's sandbox.
- **Object wear, breaking, and repair** (October 2017): wear accrues 1% per Sim day, objects over
  50% may break, sale price follows wear, and repair skill recovers wear (January 2018).
- **Dynamic tuning:** transaction logging, then database-sourced tuning (December 2017), then a
  supply-and-demand market for money objects with a daily bonus skill (January 2018), live tuning
  changes by admins (October 2018), and global tuning plus timed tuning presets (June 2019).
- **Motive overfill**, lot skill modes (owners can disable skill gain and payouts), and new lot
  types (Welcome, Romance, Offbeat changes).
- **EODs:** roulette, blackjack, Texas hold'em, slot machines, the nightclub job (four plugins), a
  two-person maze, and a bulletin board.
- **Interactions:** Run Immediately now queues like "allow push", a real "must run" flag (being
  trapped or kicked out can't be cancelled), and fixes for double scheduling, ghost objects, and
  desyncs.
- **Routing:** Bezier path segments (`VMPathBezierSegment`), a new obstacle set, avatars running
  over 10 tiles, and many collision fixes.
- **Performance:** a lockless routine cache (February 2018) and an experimental SimAntics-to-C#
  ahead-of-time compiler (`FSO.SimAntics.JIT`, February 2019).
- **New TSO calls** for content creators, such as `FSOAccurateDirectionInTemp0` and
  `FSOMarkDonated`, and an `FSOChar` entry with newlines.
- **Platform abstraction:** `Model/Platform` separates TSO and The Sims 1 rules
  (`VMAbstractLotState`, validators), which Simitone (FreeSO's Sims 1 engine) relies on. Many
  commits are Simitone fixes.

## Neighborhoods (November 2018 – 2019)

A full rework of neighborhoods: mayors, elections, nominations, ratings, bulletin boards,
donator and benefactor roles on community lots, moderation tools, and later Free Vote (May 2019),
which lets avatars in neighborhoods without elections vote in another one.

## Server, API, and operations

- **Admin API** on ASP.NET (September 2017), later ASP.NET Core 2.2 (February 2019): bans, kicks,
  in-game mail, registration and password reset over SMTP, lot data, events, and account lockout.
- **Events and inbox** (October 2017).
- **Reconnection** (March 2019): a disconnected client's session stays alive for 30 seconds so it
  can reconnect with its session key; lots wait 30 seconds before booting visitors without a
  roommate; one connection per client at a time.
- **Updates:** a new patcher with incremental updates and rollback, triggered from the admin
  utility, plus automatic patching when the wrong TSO version is installed.
- **Lot trading and moves:** secure trade fixes, move dates, and untradable objects.

## The upgrades system (July 2019)

The last two commits add **object upgrades**: an object can be bought or improved at a higher
level, whose tuning replaces the object's constants. The level is stored in the database so the
purchase is never lost. Buy mode remembers the chosen level, trade shows it, and donated objects
don't regain value through upgrades. Volcanic gained a PIFF viewer and editor (with comments and
summaries) and better tuning views in preparation. `feature/lotview-refactor` continues this work
(upgrade groups and a re-init flag).

## Relevance to NSOClient

- **Bug fixes as evidence.** Fixes such as "Fix double scheduling bug", "Fix Semiglobal
  TreeByName", "Fix portals not updating target room when moved", and the interaction queue
  changes point at places where the snapshot behaves oddly. NSOClient matches the snapshot by default;
  where it chooses to fix one of the snapshot's bugs, these show what FreeSO later did.
- **Extensions.** The AOT compiler, the new TSO calls, tuning presets, and upgrades are prior art
  for NSOClient's own extensions.
- **The patches.** Many new PIFF patches and "TSOPorts" target the 2003 production files, as the
  snapshot's do. They'd need the same "apply only if it fits" handling on the 2002 installs.
