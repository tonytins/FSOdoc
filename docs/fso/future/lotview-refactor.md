# `feature/lotview-refactor`: rewriting LotView (April – October 2019)

**Status:** not in the snapshot. The branch contains all of [`feature/upgrades`](upgrades.md) plus
72 commits of its own, the last on October 23, 2019 ("Add mode switch button"). Measured from the
snapshot it changes 2,070 files (about 218,000 lines added, 25,000 removed). Its own commits
mostly touch `tso.world` (LotView), Volcanic, the client UI, SimAntics, and content.

## The LotView rewrite

LotView is the renderer for a lot (see [rendering.md](../rendering.md)). In the snapshot, 2D and 3D
are separate paths, and 3D was added on top of a renderer designed for 2D sprites. This branch
rebuilds it so both share one world:

- **Optimizations first** (April 2019): the chat panel and scrolling had been signalling every
  object on the lot each frame (about 5% and 7.5% of CPU on a large lot); room lighting updates
  are spread across frames to avoid stutter.
- **Typed world effects** (April 2019): each shader effect gets its own class with typed
  parameters, replacing dictionary lookups for parameters and techniques.
- **Old world classes removed** (August 2019), replaced by a **hybrid 2D/3D** world: 2D can rotate
  and zoom smoothly, 3D returns behind a toggle (first Tab, later a settings option and a mode
  switch button), and lot thumbnails, facades, and surrounding lots work in both.
- **Cameras:** a first-person camera (September 2019), a rotation rework, and middle-mouse 2D
  rotation.
- Fixes for OpenGL, grass rotation, lighting adjustment, thumbnail bounds, and switching modes.

## Other work on the branch

- **Upgrades, continued:** upgrade groups (used by seating) and a "reinit" flag, which reruns an
  object's init entry point whenever it's upgraded, for objects that cache tuning at creation.
  Fixes to upgrade pricing and loading on the server.
- **Volcanic:** `TREE` resource support (labels, comments, and gotos in BHAV editing) and an
  Avatar Tool that imports animations, meshes (as accessories), and skeletons.
- **Text:** Cyrillic, Greek, and extended Latin fonts; data service strings (`VLC` strings) encoded
  as UTF-8, so instant messages and descriptions keep non-ASCII characters; AltGr no longer read
  as Ctrl.
- **Gameplay:** inventory "token" modes for token-like objects, purchasable vehicles, a cooldown
  EOD, band and slot improvements, birthday gifts, and an extra death type.
- **API:** avatar, lot, neighborhood, bulletin, and election endpoints, OAuth tokens with
  permissions, and batched lookups.

## Relevance to NSOClient

The rendering work is outside NSOClient's engine-free scope, but it shows what a renderer built on
top of NSOClient has to handle: 2D and 3D sharing one world, rotation, and multi-floor targeting.
The UTF-8 string change matters for any client that talks to a FreeSO server built after it, since
the snapshot's protocol encodes those strings differently.
