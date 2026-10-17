# FreeSO's releases

FreeSO's updates, newest first, by the names FreeSO gave them. SimsCraft's snapshot in
[`TSOClient/`](../../TSOClient/) is FreeSO's `master` on August 10, 2017: **beta/update-46**, plus
two days of server networking fixes (FreeSO's modified Mina library) and its "Any CPU" build. It's
marked below, between update-46 and update-50. Everything above that line is newer than the
snapshot, and NSOClient doesn't follow it.

FreeSO named its builds in four eras:

- **Early tags** (2014 to 2015): `0.1`, `0.2`, and `0.25xna3`, from before the public game.
- **The open beta, announced** (February 2017 to May 2019): `content/update-N`, then
  `beta/update-N`, with letters for hotfixes (`beta/update-55a`). These weren't published on
  GitHub; their changes here are from the announcements, as
  [TSOMania](https://www.tsomania.net/)'s monthly news archives recorded them. Numbers missing
  from the list were never announced there.
- **The open beta, on GitHub** (May 2019 to December 2024): from `beta/update-74b`, each build is
  a GitHub release, later named `beta-update-N`. The releases carry no notes of their own, so
  their changes here are FreeSO's commit messages since the previous release; a build with none
  was a rebuild (releases also carry add-ons such as the catalog and splash screen). FreeSO's
  server shut down on December 9, 2024, after `beta-update-91a`.
- **The FreeSO Archive Beta** (2026): `v0.1.0-beta` onward, the self-hosting Archive client and
  server, with notes from each release. FreeSO says the full server and client released with it
  will need modifications to be refactored
  ([freeso.org/download](https://freeso.org/download/)).

Sources: [FreeSO's releases](https://github.com/riperiperi/FreeSO/releases) and commits,
TSOMania's news archives, and [FreeSO's news](https://freeso.org/news/).

## v0.8.5-beta

*September 20, 2026*

- Fix: archive flags too small (odd choice for an enum size...).

## v0.8.4-beta

*September 20, 2026*

- Fix: defer AA mode changes when loading, don't clobber DisableTransitions.
- Fix: 2d smooth city transition (from farthest view).
- Fix: first frame of various transitions having invisible ground.
- Fix: mouse wheel shouldn't affect zoom in direct control.

## v0.8.3-beta

*September 18, 2026*

- Fix: add some useful workarounds when clipboard is not supported.
- Fix: properly set dedicated server flag.
- Fix: PPX engine being a bit wasteful with render targets (and crashing with SSAA).
- Fix: log version when server starts, change api server project type.

## v0.8.2-beta

*September 17, 2026*

- Fix: update dedicated server icon.
- Fix: ctrl-c safe close on dedicated server, client force close with double click.
- Fix: add xinput dll to windows build.
- Fix: avoid crash when a texture has multiple geoms somehow.

## v0.8.1-beta

*September 12, 2026*

- Fix: add tuning to force the object limit.
- Fix: bias important debug items to the front of the catalog.
- Fix: improve mesh generation on object fences etc.
- Fix: reintroduce mod starting money on non-archive servers.
- Fix: minor issues.
- Fix: use inputfusion xinput to avoid some controller issues.
- Fix: some more cases where transitioning lots too quickly would boot to city.
- Fix: fixup some old event code.
- Fix: prevent build/buy from appearing on surround lots.
- Fix: greatly improve surrounding lot sync, optimize hollow lot reload.
- Fix: ensure sandbox folder exists when opening it.

## v0.8.0-beta

*August 31, 2026*

- Fix: typo.
- Fix: hide surround lots for properties that are out of bounds.
- Fix: improve dpi selection on linux, automatic refresh rate selection.
- Feat: experimental automatic DPI switching.
- Feat: new sandbox mode UI, some job lot fixes.
- Fix: sandbox mode UI improvements.
- Fix: add isometric toggle button.

## v0.7.1-beta

*August 29, 2026*

- Fix: install script.
- Fix: wip linux ci.
- Fix: 2d surround roofs not writing to depth buffer.
- Fix: thumbnail disappearing when opening the same lot page twice.
- Fix: issue where lot thumbnail could be cleared accidentally.
- Fix: improve city view window behaviour.
- Fix: wall cuts in 2d mode (apparently this took 11 years).
- Fix: fix various issues with 2d mode.
- Fix: optimize tga image stream behaviour.
- Fix: optimize tga loading a little.
- Fix: optimize volcanic BHAV editor and BGR swap.
- Fix: some issues with lot linker transition.
- Fix: use seamless transition for lot linker.
- Fix: out of world failsafe should only trigger on idle avatars.

## v0.7.0-beta

*August 19, 2026*

- Fix: properly clear surround data when a lot becomes orphaned.
- Fix: keep chat history between transitions.
- Feat: add chat bubbles for surround messages.
- Fix: swap tts gender when no voices are available.
- Fix: include gender with surrounding messages.
- Fix: send avatar name with message.
- Feat: initial support for surround messages.
- Feat: add job cheats to The MOMIStation.
- Fix: some obvious issues with the job cheats.
- Feat: add speedy job progression cheat toggle (needs testing).
- Fix: cleanup archive dialogs, move strings to uitext.
- Fix: add hints for archive host and city editor.
- Fix: some more things involving custom GUID avatars.
- Fix: pet thumbnails getting disposed.
- Fix: add FreeSO object credits.
- Fix: some fixes to direct control on pets.
- Fix: weather lighting flash during lot transitions and reload.
- Fix: auto focus to simantics dialogs, remove invalid focus.
- Fix: add hollow.fsoh regeneration task, optimize hot paths, fix some visual bugs.
- Fix: thread safety on ReceiveOnlyServiceProvider.
- Fix: add missing tuning to empty archive save.

## v0.6.0-beta

*August 9, 2026*

- Fix: object crash when GetSuit called by nightclub npcs.
- Fix: use localized job lot titles.
- Fix: improve size info/add low space warning for downloading archive saves.
- Fix: surrounding lot object placements now match the free roam version.
- Fix: maintain chat history visibility throughout session.
- Feat: add auto-join behaviour for the final town hall.
- Fix: issue where rejoining the city without a lotid would use the previous one.
- Feat: add catalog flags for regional catalog items, mystic bomb debug object.
- Fix: allow admin sims to Add Ticket at restaurant.
- Feat: automatic remesh download when configured on update json.

## v0.5.3-beta

*August 2, 2026*

- No changes listed.

## v0.5.2-beta

*August 2, 2026*

- Fix: single file update, use CLI updater on windows.
- Fix: rewrite archive save local dir if data is detected in data/ folder.
- Fix: update monogame to 3.8.5 non-preview (shouldn't change much).
- Fix: avoid lot facade generator leaving disposed indices bound.

## v0.5.1-beta

*August 1, 2026*

- Fix: ask archive server for city thumbnail.
- Fix: use custom thumbnail for archive save when available.
- Fix: attack interaction (thanks wyatt for helping investigation).

## v0.5.0-beta

*July 31, 2026*

- Fix: drivable sleigh door animation.
- Fix: (dj station) expected anim event count behaviour, affected fso objects.
- Fix: connecting to any lot after being booted due to a crash.
- Fix: don't terrain prep hollow lots - they should be up to date with move flags 0.
- Fix: specular discontinuity between lots.
- Feat: improved terrain rendering.
- Fix: restaurant job doubled up music, fix jukebox animation on job lot.
- Fix: moderation\_level not being respected when joining lot.
- Fix: cast to integer to calculate lightmap base.
- Fix: workaround amd bug where the lighting above floor 0 is incorrect.
- Simitone changes from Archive -\> Archive Experiment (#304).

## v0.4.2-beta

*July 26, 2026*

- Fix: prevent avatar icons from getting disposed by the queue.

## v0.4.1-beta

*July 25, 2026*

- Fix: move updater cleanup to happen even in archive mode.
- Fix: roof not clearing when floor is empty (ty Seger).
- Fix(installer): create target directory before disk space check.

## v0.4.0-beta

*July 25, 2026*

- Fix: increase default settings.
- Fix: mmo server lots getting stuck on spectator mode when rejoining as roomie.
- Fix: mmo server version tracking, remove dead code.
- Fix: issue where some computers would break using ts1 trees.
- Feat: add builtin TSO installer that appears when TSO can't be found.
- Fix: dpi / null ref exception with trade panel (ty Seger).

## v0.3.2-beta

*July 19, 2026*

- Fix: some macos issues.

## v0.3.1-beta

*July 19, 2026*

- No changes listed.

## v0.3.0-beta

*July 19, 2026*

- Fix: macos publish.
- Feat: show display name in lot chat history unless disabled.
- Feat: implement debug mode flags.
- Fix: sandbox mode multiplayer client.
- Fix: sandbox mode multiplayer server.
- Fix: don't show forests on water in 3d mode.
- Fix: terrain controller not respecting lot creation flag.
- Feat: implement allow lot creation flag.
- Feat: implement avatar control flags, cache shared avatars for archive.
- Fix: generate missing catalog thumbnails, reduce memory leaked.

## v0.2.1-beta

*July 15, 2026*

- Fix: use abandon counter for lot timeout (so debugger/suspend doesn't crash every lot).
- Fix: avoid city map visually overlapping the active lot in many cases.
- Fix: Mina.NET stack overflow.
- Fix: don't show free roam interactions when disabled.
- Fix: respect user mod level change when on unowned lot.
- Fix: lingering snow when loading a lot saved in winter.
- Fix: FSO.IDE debug mode.
- Fix: hide unused environment subpanels in house mode.
- Fix: crossroads surround for all XML lots.
- Fix: rain cross-fade.
- Fix: join history deletion, rpc join without lot ID.

## v0.2.0-beta

*July 5, 2026*

- Fix: add some obfuscation to RPC secret.
- Fix: join list deletion, discord join behaviour.
- Feat: update discord rpc for new join dialog.
- Fix: mail avatar search.
- Fix: some issues with list box UI.
- Feat: add super admin permissions for localhost.
- Feat: use moderation level to show/hide city admin ui.
- Fix: UpdateBuilder includes.
- Fix: ui element rounding issues at 1x dpi.
- Fix: properly dispose lot when leaving sandbox mode.

## v0.1.0-beta

*June 27, 2026*

- The first Archive Beta, 327 commits after `beta-update-91a`, with no changelog. FreeSO describes the Archive client as hosting a stripped-down game server without user accounts, with a dedicated server option, UPnP port forwarding, and 64-bit support; it's "not appropriate to run as an MMO server".

## beta-update-91a

*December 8, 2024*

- Fix 3d thumbnails some more.
- Relax some fire restrictions.
- Finale graphical effects.

## beta-update-91

*December 7, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-90e

*December 6, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-90d

*December 4, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-90c

*December 3, 2024*

- Fix 3d object thumbnails.

## beta-update-90b

*December 3, 2024*

- He's Back.
- Improve 3d camera.
- Fix lighting error.
- Add enable tuning, fix integration with direct control, regen health.

## beta-update-90a

*December 2, 2024*

- Fix rendering issues caused by ceilings change.

## beta-update-90

*December 2, 2024*

- Improve direct control considerably, DPI fixes.
- Fix ceiling rendering.
- Improve world reload.
- Make direct control smoother by deferring duplicate commands.
- Patch up the city painter a little, add the final town hall island.
- Alter vertex color a little.

## beta-update-89d

*November 29, 2024*

- Fix some more issues with Custom GUID avatars.

## beta-update-89c

*November 28, 2024*

- Fix crash when saving avatars without heads.

## beta-update-89b

*November 26, 2024*

- Add additional arguments to restore lot tool.
- Fix default value types.
- Improve logging for restore tool.
- Fix version saving for FSOV.
- Fix avatars without the leave lot action crashing when leaving lots.
- Fix change suit primitive editor.

## beta-update-89a

*November 14, 2024*

- Add Property Select EOD.
- Add a full stop.

## beta-update-89

*November 11, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-88i

*October 30, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-88h

*October 29, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-88g

*October 29, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-88f

*October 28, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-88e

*October 21, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-88d

*June 1, 2024*

- Exclude escape room GUID from object resets.

## beta-update-88c

*May 29, 2024*

- A rebuild: no code changes since the previous release.

## beta-update-88b

*March 31, 2024*

- Improve extreme color calculation for DXT compress (#276).
- Fix parallax floors.

## beta-update-88a

*December 13, 2023*

- A rebuild: no code changes since the previous release.

## beta-update-88

*November 30, 2023*

- Cleanup: Remove most unused usings and MPL per-file licenses.
- Remove unused usings from FSO.LotView.
- Remove unused classes from FSO.LotView.
- Remove more unused usings, per-file MPL.
- Remove unused usings and MPL per-file from FSO.SimAntics.
- Misc cleanup in FSO.SimAntics.
- Considerably reduce runtime allocations.
- Reduce more allocations.
- Remove some more unnecessary allocations.
- Spread cost of room lighting updates across multiple frames.
- Greatly improve lightmap performance.
- Remove another allocation.
- Faster MSDF kerning, sky dome allocations.
- Redraw 2D when unimportant lighting updates happen.

## beta-update-87h

*November 5, 2023*

- A rebuild: no code changes since the previous release.

## beta-update-87g

*October 30, 2023*

- A rebuild: no code changes since the previous release.

## beta-update-87f

*October 29, 2023*

- A rebuild: no code changes since the previous release.

## beta-update-87e

*October 29, 2023*

- Cleanup lot save a little.

## beta-update-87d

*October 26, 2023*

- Ignore global actions for disabling interactions due to repair.

## beta-update-87c

*October 26, 2023*

- Fix Lead Tile Scopes.
- Fix YesNoCancel dialogs.
- Update FSOMonogame.

## beta-update-87b

*April 1, 2023*

- Improve smoothness.

## beta-update-87a

*April 1, 2023*

- Add fun surprise.

## beta-update-87

*March 26, 2023*

- Fixes for DJ/Dancer Job Outfits and Fixes for All Outfits for all jobs. (#266).
- Enable nightclub03\_00 lot file based on jobType. (#268).
- Use lot thumbnails for Discord RPC.
- Break avatars out of their container if it is out of world.
- Add motive display tooltip for pets, fix pet icons on spawn.

## beta-update-86m

*January 11, 2023*

- Update emojis, repoint to new twemoji cdn.
- Add new custom emojis.

## beta-update-86l

*December 12, 2022*

- "Never Clamp" relationship primitive flag (#261).
- Fix Azure build.
- Attempt to use workaround elsewhere.

## beta-update-86k

*November 23, 2022*

- Use CTSS from master definition for $Object.

## beta-update-86j

*November 16, 2022*

- Disabled flags TSO Generic calls. (#258).

## beta-update-86i

*November 12, 2022*

- Disallow untradable objects from transferring during lot trade.

## beta-update-86h

*November 11, 2022*

- A rebuild: no code changes since the previous release.

## beta-update-86g

*November 7, 2022*

- Add hide and search controller to controller IDs.

## beta-update-86f

*November 5, 2022*

- A rebuild: no code changes since the previous release.

## beta-update-86e

*November 2, 2022*

- Add missing controller.

## beta-update-86d

*October 31, 2022*

- A rebuild: no code changes since the previous release.

## beta-update-86c

*October 30, 2022*

- A rebuild: no code changes since the previous release.

## beta-update-86b

*October 29, 2022*

- A rebuild: no code changes since the previous release.

## beta-update-86a

*October 4, 2022*

- Correct inventory index when using search.

## beta-update-86

*October 4, 2022*

- \[VM\] 3D audio panning (#243).
- 3D Audio - Fix crashing on Avatar Tool (#244).
- Volcanic - Fixes and QoL changes. (#246).
- Initial Catalog Search Implementation.

## beta-update-85o

*April 17, 2022*

- Gitignore.

## beta-update-85n

*April 16, 2022*

- A rebuild: no code changes since the previous release.

## beta-update-85m

*April 16, 2022*

- Make others visible even when controller is not plugged in.
- Fix lighting.

## beta-update-85l

*April 16, 2022*

- Deploying surprise in 3... 2... 1.
- Gitignore.
- Fix build ?.

## beta-update-85k

*March 31, 2022*

- Change skill locks to use 16-bit data type.
- Fix skill degrade when dead.
- Fix build, probably.

## beta-update-85j

*March 5, 2022*

- A rebuild: no code changes since the previous release.

## beta-update-85i

*December 25, 2021*

- A rebuild: no code changes since the previous release.

## beta-update-85h

*December 24, 2021*

- Add support for normal aligned avatars.
- Add person type 254.

## beta-update-85g

*December 17, 2021*

- Add Never Persist flag, remove local rels when restoring from db.
- Add new TSOPorts, fixes to casino objects.

## beta-update-85f

*November 2, 2021*

- A rebuild: no code changes since the previous release.

## beta-update-85e

*October 31, 2021*

- A rebuild: no code changes since the previous release.

## beta-update-85d

*October 30, 2021*

- A rebuild: no code changes since the previous release.

## beta-update-85c

*October 27, 2021*

- A rebuild: no code changes since the previous release.

## beta-update-85b

*October 26, 2021*

- Add Transient Disabled State.

## beta-update-85a

*September 20, 2021*

- A rebuild: no code changes since the previous release.

## beta-update-85

*September 11, 2021*

- Replace face mask controller.

## beta-update-84f

*September 11, 2021*

- Handle DirectoryNotFoundException if the SplashScreens directory does not exist. (#198).
- Fix: person grid navigation buttons now disable/enable at the start/end (#207).
- Fix: pie menu no longer displays 1 frame of the background at full size before resizing. The Image component considers Width/Height==0 to mean don't scale the image at all (has no value to represent null). Instead of changing the component and risking breaking other usages this just starts the background at 2x2. (#206).
- Fix crashing map view for OOB lots, add swappable sky dome.
- Fix a few issues, special off-world property behaviour.

## beta-update-84e

*June 14, 2021*

- Update patches.

## beta-update-84d

*June 13, 2021*

- Set to Next primitive operator "object with same semiglobal as" (#188).
- Chat color changes (#194).
- Staff chat distinction (#195).
- Random splash screen (#196).
- Staff badge in Founder's place (#197).
- Read random splashes from list file, remove autumn grass from sandbox.

## beta-update-84c

*April 1, 2021*

- A rebuild: no code changes since the previous release.

## beta-update-84b

*April 1, 2021*

- Add chat disable flag, invisible outfit type.
- Add new game controller.

## beta-update-84a

*March 24, 2021*

- A rebuild: no code changes since the previous release.

## beta-update-84

*March 21, 2021*

- Add new terrain cursors from S1ndle.
- Add another valid OOW GUID.

## beta-update-83g

*February 14, 2021*

- Include the gameshow eod strings.

## beta-update-83f

*February 13, 2021*

- GameshowBuzzerEOD (#189).
- Fix content, update highmax, fix autumn grass trigger.

## beta-update-83e

*December 24, 2020*

- A rebuild: no code changes since the previous release.

## beta-update-83d

*December 22, 2020*

- Add controllers to allowed OOW, place inventory calls UserPlacement.

## beta-update-83c

*December 18, 2020*

- Hotfix for occupied flag reset.

## beta-update-83b

*December 18, 2020*

- Square SLOTs, automatic 3d multitile hit-splitting, placement and shadow fix.
- Fix multifloor object thumbs, 3d tile hit test.
- Some object patches from raeven.
- Add explicit reference to server common.
- Add FSO.Content explicit ref.

## beta-update-83a

*October 27, 2020*

- It's not meant to be snowing.

## beta-update-83

*October 27, 2020*

- Add support for autumn grass.

## beta-update-82b

*August 11, 2020*

- Fix a few things.

## beta-update-82a

*August 11, 2020*

- A rebuild: no code changes since the previous release.

## beta-update-82

*July 27, 2020*

- Avoid creating tasks which are destined to die.
- \[Updater\] Handle zips that contain the root folder.
- Revert "Don't include root folder in build.".
- Allow disabling job lot logs, and force disable smooth routing on job lots.
- Add time dilation.
- Use invariant culture for more float parsing.
- Style changes, fixing some weird expressions.
- Random skintone in Body Strings (#181).
- Various font changes (#182).
- Update font xnb, some solution cleanup.
- Fix curtains/blinds (#183).
- Fun changes.

## beta-update-81a

*March 31, 2020*

- A rebuild: no code changes since the previous release.

## beta-update-81

*March 31, 2020*

- Don't include root folder in build.
- Important Video Game Updates.

## beta-update-80d

*March 30, 2020*

- Set up CI with Azure Pipelines.
- Fix a few things, add a server build.
- The rare double-restore.
- Pass /restore to IDE build.
- Server and Client builds separate.
- Looks like we needed this!.

## beta-update-80c

*February 17, 2020*

- Add bounds check for Get2DFromTile.

## beta-update-80b

*February 17, 2020*

- You Are Here Waypoints and UILotButton Arrow Improvements (#178).
- Remove default keyword to satisfy TeamCity.
- :weary:.
- Fix head seek on hills, misc changes to avery.

## beta-update-80a

*February 9, 2020*

- A rebuild: no code changes since the previous release.

## beta-update-80

*February 9, 2020*

- Admin Red Chat Balloon (#173).
- Non-fallback support for Thai script, minor font changes (#175).
- Compile new Thai font.
- \[UI\] Fix connecting to city after creating a Sim.
- Refresh results everytime bookmarks panel shows (#176).
- RackEOD: Bug fixes (#177).
- \[Various\] Minor fixes.
- \[LotView, SimAntics\] Head Seek when players talk.
- \[Misc\] Cleanup.
- \[Patch\] Update Limo Patch.

## beta-update-79d

*December 29, 2019*

- A rebuild: no code changes since the previous release.

## beta-update-79c

*December 19, 2019*

- \[Client\] Fix city sometimes showing behind Hybrid 2D.

## beta-update-79b

*December 19, 2019*

- Fix dir cases 3 (#169).
- Bump npm from 3.10.10 to 6.13.4 in /TSOClient/FSO.Server/Admin (#171).
- Primitives Snap To Edges of other Primitives (#172).
- \[VM, LotView\] Various changes.
- \[Fixes\] Some fixes to the new inventory handler.
- \[LotView\] Fix graphics during overdriven weather.

## beta-update-79a

*December 8, 2019*

- Fix dir cases 2 (#167).
- \[VM\] Fix parent/child interactions.

## beta-update-79

*December 7, 2019*

- \[VM\] Fix loading objects that need additional locals.
- \[VM\] Entirely reworked autonomy.
- \[Client\] Update SetKilled behaviour.
- \[IDE, VM\] Optimisations and TTAB Editor Fixes.
- \[VM, LotView\] Various fixes.
- Implement Cheat Commands into VM (#164).
- Copy-Paste Primitives in Volcanic (#165).
- \[VM\] Fix TS1 issues, simantics rooms are now 0 based.
- Various fixed of directory and file names (lower/upper case issue) (#166).
- \[Client, SimAntics\] Fix some client and TS1 things.

## beta-update-78j

*November 19, 2019*

- \[VM\] Fix TS1 issue with animations, loading improvements.
- \[Debug\] Add tracing for pet deletes.
- \[Debug\] Print some more info.

## beta-update-78i

*November 17, 2019*

- \[LotView\] Fix surrounding lot pools, mesh gen.
- Bump bootstrap from 3.0.0 to 3.4.1 in /TSOClient/FSO.Server.Api (#163).
- \[VM, LotView\] Lots of bugfixes.
- Update FSO.Client.csproj.
- \[LotView, TS1\] Fix various prop/anim bugs in TS1, correctly update position with plate stacking in 2d.

## beta-update-78h

*November 5, 2019*

- \[LotView\] 3D Pools, Fixed depth mask, more.
- \[LotView\] Count 3D pools for shadow casting.

## beta-update-78g

*November 2, 2019*

- \[VM, LotView\] Fix a few bugs.

## beta-update-78f

*October 31, 2019*

- \[Server, World\] Fix a few things.

## beta-update-78e

*October 30, 2019*

- \[LotView, VM\] Fixes and minor changes.

## beta-update-78d

*October 25, 2019*

- A rebuild: no code changes since the previous release.

## beta-update-78c

*October 24, 2019*

- \[VM\] Remove dependance on world for blueprint restore.
- \[Various\] A few minor fixes.
- \[VM\] Fix FSOBreakObject.

## beta-update-78b

*October 23, 2019*

- \[Bugfix\] Fix bugs and improve performance.

## beta-update-78a

*October 23, 2019*

- A rebuild: no code changes since the previous release.

## beta-update-78

*October 23, 2019*

- \[Server\] Add birthday gift task, fix host pool.
- \[City\] Add handler for sending mail to city server.
- Create LICENSE.md (#158).
- Reintroduce CT - FSO pickup param 0 for carry (#160).
- CooldownEOD (#161).
- \[PR\] Fix some merge issues.
- Feature/lotview refactor (#162).
- \[UI\] Fix default state of full 2d mode.

## beta-update-77e

*October 5, 2019*

- \[Avatar Tool\] Fix timeprop import.

## beta-update-77d

*September 28, 2019*

- \[Content\] Fix RuntimeProvider getting some outfits.

## beta-update-77c

*September 28, 2019*

- \[Client\] Fix Typo (????).

## beta-update-77b

*September 27, 2019*

- \[VM\] Fix upgrade pricing, dialogs disappearing.
- :crab: assimp is gone :crab:.
- :crab: assimp is actually gone :crab:.
- \[Project\] Consolidate Newtonsoft.json Versions.
- \[Volcanic\] Animation Import, Avatar Tool.
- \[Avatar Tool\] Experimental Mesh Import.
- Support of Cyrillic, Greek and extended latin (#154).
- \[Fonts\] Improved font by @Cosmatevs , fix UTF-8 font import.
- Makeshift fix for AltGr treated as Ctrl (#156).
- \[Avatar Tool\] Fix skeleton importing.
- \[Avatar Tool\] Fix some animations, summary for appearances.
- \[Protocol\] Encode VLC strings as UTF-8.
- No out-of-window keys capturing, AltGr ≠ Ctrl (continued) (#157).

## beta-update-77a

*August 29, 2019*

- \[VM\] Fix various issues.
- \[VM\] Remove Debug Log.

## beta-update-77

*August 28, 2019*

- \[Various\] A ton of changes.
- \[Git\] Include assimp-net locally.

## beta-update-76c

*August 19, 2019*

- Added new API functionalities (#152).
- \[Upgrades\] Add support for upgrade groups.
- Make Band (& Slots) Suck Less + UI Additions (#150).
- \[UI\] Fix some issues with archis PR.
- \[API\] Added funtionality and efficiency (#153).

## beta-update-76b

*July 28, 2019*

- \[Server\] Fix upgrade loading on server.
- \[Upgrades\] Add "reinit" flag to upgrades.

## beta-update-76a

*July 18, 2019*

- \[IDE\] WIP PIFF viewer.
- \[IDE\] PIFF editor, with summary+comments, deleting existing patches.
- \[IDE\] Editor UI. Not hooked up yet.
- \[Upgrades\] Initial Functionality.
- \[Upgrades\] Fix various issues.
- Not sure how git is this stupid.

## beta-update-76

*July 16, 2019*

- \[Object\] Fix casino bar object.
- \[UI\] Fix nightclub job IDs.
- \[UI\] Wallpaper cursor now faces the correct direction in 3D.
- Initial Implementation of Upgrades (#151).

## beta-update-75a

*June 24, 2019*

- \[UI, World\] Improvements to placement, category limits.

## beta-update-75

*June 23, 2019*

- \[World\] Fix interpolation for multitile objects.

## beta-update-74d

*June 22, 2019*

- \[VM\] Fix portals not updating target room when moved.
- \[SimAntics, World\] Various improvements.
- \[SimAntics\] Fix dialog parsing for strings that end in a command.
- \[Simantics, Server\] Substantial Backend Improvements.
- Fix escaping bbcode from sanitized contexts.

## beta-update-74c

*May 23, 2019*

- \[IDE\] Improve viewing for tuning.
- \[Client\] One connection at a time.
- \[VM\] Testing Something for next build.
- \[API\] Fix Github update target.

## beta/update-74b

*May 20, 2019*

- The first build published as a GitHub release.
- A Free Vote option for Sims in neighborhoods without an election; the election move limit drops from 30 days to 14.
- Objects go back to the inventory with the I key.
- Fixed a wrong result from the Set To Next primitive.
- A Restore Lot tool that rebuilds properties from `.fsov` saves.
- Update builds are published as GitHub releases instead of on AWS.
- Failed reconnections no longer leak TCP connections; growing lockouts after repeated failed logins.
- Fixes for clothing purchases, the timeout dialog, and city view blending.

## beta/update-74a

*April 7, 2019*

- Fixed a crash from bad lot commands, the job info dialog, reconnecting, and city water and shadows.
- Ownerless community lots are no longer deleted.
- Trade fixes: lot-for-lot trades, move dates, and untradable objects.

## beta/update-74

*March 30, 2019*

- A smoother 3D build and buy grid, new crafting objects, and unbreakable donated objects.
- 30 seconds to reconnect after a disconnect, with retries and switching connections without leaving the lot.
- A new update system: generated automatically, incremental downloads, and an updater that works on Mac.
- Tombstones record who died, how, and when.
- A new job info dialog, and no accidental sales from the Delete key.

## beta/update-73b

*February 24, 2019*

- Fixed update-73's known issues.
- Gingerbread houses spoil more slowly; MaxSize settable in the SLOT editor; shadowed surrounding lots.

## beta/update-73

*February 22, 2019*

- Neighborhoods: 34 of them, with mayors elected monthly, Town Hall community lots, and bulletin boards.
- MSDF fonts, new roofs, gamma-correct lighting, contact-hardened shadows, and experimental 4x MSAA.
- A new collision system and primitive changes: over 2x simulation speed on some lots.
- An experimental SimAntics-to-C# compiler (for Simitone) and smoother bezier routing.
- A new Manage Roommates dialog and reworked action validation.
- City view: buttons in 3D space and neighborhood overlays.
- Server: .NET Core support and an ASP.NET Core API server.
- Volcanic: SLOT editor, SimAntics export to C#, data service editor, and an animation exporter (unfinished).

## beta/update-72h

*February 10, 2019*

- Weather off for now (grass and sand no longer turn to snow).
- Fridge, pie menu, and gingerbread station fixes.
- Backend changes so new objects don't break lot loading.
- Volcanic: catalog XML generation, GUID copying, and hex editing of unknown primitives.
- New remesh objects and a decorative limousine.

## beta/update-72 and beta/update-72b

*November 13, 2018*

- Must-run interactions (being trapped or kicked out, starving, drowning) can't be cancelled.
- Fixed a resource disposal loop that slowed wall cutaways and build tools.
- Traps reset with the lot; a new object.
- Login API forced to HTTPS; MSAA support tracking, and MSAA for Sims in 2D.
- Animations at full speed everywhere; faster image loading.
- Relationships to dead objects no longer carry to new objects with the same ID.

## beta/update-71x

*October 26, 2018*

- Fixed the DisableAvatarCollision tuning, statues changing value, and a maze crash.
- An Extra Tall EOD height; the skeleton outfit in the costume trunk for now.
- Discord Rich Presence respects privacy and shows more (your Sim, the nightclub, the current screen).
- Chat opacity, timestamps, and remembered layout.
- TSO can run from a local folder, for portable installs.

## beta/update-71f

*October 8, 2018*

- Fixed converting radian directions to object directions.

## beta/update-71e

*October 8, 2018*

- Fixed Do Not Duplicate when placing objects in avatars' hands.

## beta/update-71d

*October 8, 2018*

- Awnings work and join against walls; Halloween balloons.
- Create Object Instance gains a Do Not Duplicate mode.
- Return Immediately makes a subroutine call instead of an interaction.
- Piñata, roulette, and blackjack fixes.

## beta/update-71c

*October 8, 2018*

- 32 concurrent connections for city thumbnails and facades (about 2 before).
- Admins can change lot tuning live; more data and engine functions exposed to SimAntics.
- Remesh and object script fixes; disconnections from message errors are logged.

## beta/update-71b

*October 8, 2018*

- 15 new catalog objects, and fixes to earlier ones.
- Hold'em fixes; a Halloween splash screen.
- Fixed crashes from in-game music, the newspaper graph on old GPUs, modified cultures, and multiple launches.
- Backported: better 3D draw order, new terrain hit detection, and depth-mask render types for remeshes.

## beta/update-71

*August 10, 2018*

- Texas Hold'em, and casino objects.
- Group skilling: Maze (logic and charisma) and War Game (creativity).
- The last TS1 objects ported to TSO.
- Fixes for bad lot thumbnails, Run Immediately interactions, social reactions, 3D shortcuts, and Volcanic on OpenGL.

## beta/update-70f

*June 9, 2018*

- Fixed flat-colored floors in OpenGL, a TTS crash, cursor flicker in 3D, others' skill locks, and buying a lot in DirectX.
- The login dialog remembers the last username.
- Missing hints don't crash other languages; a dialog when TSO is missing.

## beta/update-70

*June 9, 2018*

- Animations play at 1.2x, as in TS1 and TSO, with sounds in sync.
- A MonoGame update (OpenGL audio and DirectX cursor fixes).
- Touch controls for the 3D city view (`-touch`).
- Sims run to far destinations, and climb stairs and leave chairs faster.
- A large program restructure (the executable changed).
- Welcome lot rules enforced by account age; clearer purchase, outfit, and secure trade messages.
- Fixes for smoke on upper floors, the 3D city transition, and new loading crashes.

## beta/update-69

*May 19, 2018*

- A 3D city view with a perspective camera, 3D lot facades, smooth zoom to your lot, and a water shader.
- A refreshed 2D city view, lot tooltips with prices, and less memory use.
- The Welcome lot type for new players, and bonuses for Romance and Offbeat lots.
- A particle system; broken objects smoke.
- Most unreleased debug catalog objects restored and patched for TSO.
- Faster, asynchronous game and lot loading, with a progress bar.
- Terrain tools cost half, explain failures, and flatten around buildings.
- Bookmarks by online status, rarer rain, sandbox `/time`, memory leak fixes, and 3D mode improvements.

## beta/update-68

*April 1, 2018*

- April Fools' update; its notes were published only as an image.

## beta/update-67d

*March 29, 2018*

- Server self-resync against desync loops, automatic or by an admin.
- Object lists can't hold duplicates.
- Fixed chat channels sometimes missing, room score on islands and balconies, and floor tile strings.
- Better roof rendering; final blackjack and roulette fixes.

## beta/update-67

*March 18, 2018*

- A redesigned chat: channels with their own permissions and options, emoji, resizing, colors, and visible history.
- Text-to-speech through new chat settings, with pitch, played through MonoGame.
- Experimental: new joiners reuse recent lot state, and lot thumbnails load over HTTP.
- The data service loads relationships, jobs, and bookmarks on request; API speed-ups.
- Engine refactoring for Simitone; lighting and 3D cutaway improvements.
- Translation-ready EOD strings, new casino sounds, a new croupier, and blackjack and roulette fixes.
- A commemorative picture frame and a floor drain.
- Many smaller fixes (thumbnails, carpools, floods, async lot saves, text selection, Volcanic).

## beta/update-64b and beta/update-64c

*February 17, 2018*

- Leapfrog behaves like a push-tail continuation, fixing interaction order.
- Fixed 2D roof culling, a missing sound crash, roulette, the restaurant, double job lot registration, and unowned objects failing transactions.
- Nightclub: base pay and skill bonuses fixed, dance hints rebalanced, and a plugin race fixed.
- The TS1 visit generator works.
- Blackjack fixes, input-blocking EOD backgrounds, and a decorative MOMI logo.

## beta/update-64

*February 11, 2018*

- The nightclub job, and the Blackjack object.
- Volcanic: a sound browser, and BMP thumbnail export and import.
- A late anniversary object, and an NPC caretaker for community lots.
- An admin API for lot data and uploading `.fsof` files.
- Job lot NPCs have no collision; Sims avoid standing where another Sim is or is going.
- Job matchmaking respects ignore lists, frees players who leave, groups levels, and enforces the player limit.
- HIT sound fixes, meals keep queued interactions, and other bug fixes.
- Lot facades; untradable and unsellable objects; sandbox speed on the number keys.

## beta/update-64

*January 21, 2018*

- Repairs recover wear by mechanical and logic skill; the repairman is automatic but recovers only 10%.
- Repair costs back to their original share of value, at 100 an hour.
- Fixed a server and client freeze, and an animation caching bug that desynced lots.
- The gardener waters plants below 85% (was 75%).
- (TSOMania lists this and the February 11 build both as update-64.)

## beta/update-63

*January 13, 2018*

- Fixed bugs from the previous update.
- Casino objects, including a slot machine, and a decorative taxi set.
- Texture compression fixes for Build Mode and OpenGL 3D; directional lighting ignored at minimum lighting.
- Live mode shortcuts no longer fire while typing.
- Skill gameplay can't be disabled for NPCs.
- Fixed crashes with paused audio, non-English dates in the newspaper, and launching the updater.

## beta/update-61

*January 12, 2018*

- Dynamic money object tuning: payouts follow supply and demand, with a daily bonus skill.
- Read City News on the newspaper: news, events, the bonus object, payout percentages, and a weekly trend graph.
- Lot owners can turn off skill decay, skill gain, and money object payouts.
- Secure trading of objects, money, and lots together.
- Directional lighting, and DXT5 texture compression for low-VRAM machines.
- Objects for sale no longer simulate every tick: about 5x faster on extreme store lots, 2.5x on typical ones.
- A data service serializer cache; the lot server logs SimAntics state when aborting an infinite loop.
- Fixes for restaurant round ends, lot thumbnails, pets' cages, and light permissions; 3D catalog thumbnails rotate.

## beta/update-60

*December 17, 2017*

- A new graphics options page, with a weather toggle and a DPI scale for the UI.
- Visitors can't change lights; lights for sale don't light rooms.
- Solo job objects rebalanced: the bonus caps at 10 players (was 16) and 2.2x (was 2.5x).
- Fixed motive overfill, ghost objects left behind, and stuck smoke clouds; repair costs halved.
- Volcanic fixes.

## beta/update-59

*December 17, 2017*

- Motive overfill.
- A custom content slot machine.
- Holiday features: snow, Christmas trees, and daily gifts under the tree.

## beta/update-56

*November 24, 2017*

- A new $25 slot machine (custom content).
- Slot machine and roulette fixes.
- Basic Discord Rich Presence, with invites to lots and job lots.
- Fixed claims destroyed after a disconnect, and a crash with mismatched light rooms.
- Lighting standardization (in progress), a less washed-out skybox, and asynchronous 3D reconstruction.
- Volcanic no longer draws 3D tab frames when inactive.

## beta/update-55c

*November 2, 2017*

- Fixed floating Sims.

## beta/update-55b

*November 2, 2017*

- Fixed headless, nameless, and mismatched NPCs, NPCs and Sims placed underground, and NPCs not facing what they tend.
- The expensive dog house no longer drains its dog's needs; disabled objects don't wear or break; multi-tile objects don't half-break.
- Reconnecting Sims wear their default daywear; visitors can't change light colors; a new light color dialog.
- Sounds for instant messages.
- Roulette: longer balance entries, a $999,999 stocking limit, minimum-balance and minimum-bet checks, sounds, and many table fixes.
- Volcanic: the TPRP editor saves locals; PIFF saving changed.

## beta/update-55a

*November 2, 2017*

- A ServerRelease build without IDE hooks.
- Sanity checks so avatars don't go offline after relogging.
- Fixed the bookmarks layout, object shadows under wall shadows, fire's harmless effect never ending, `VMNetSetTimeCmd` deserialization, colored light blending, and the skeleton dance.

## beta/update-55

*October 30, 2017*

- The Roulette EOD, for casino lots.
- Objects depreciate and wear, and can break below 50%; a repair state.
- An inbox for system, event, and player messages, and an event system for object and money giveaways.
- Light colors, and lights that can stay on.
- Ultra lighting: 3D shadows for outdoor objects and point lights; reworked base lighting for colored light.
- Job lots recorded in a new format (`.fsor`); the CAS clothing rack through crafting.
- Run Tree By Name and Push Interaction have primitive descriptors; Object Type editable in the OBJD editor.
- The server disconnects clients stuck online; many connection closes run their database queries in turn.
- Objects can read the server's UTC time.
- Lot servers retry the city server for 30 seconds before dropping lots.
- Fixes for AMD's black fourth floor, water outlines, floor texture VRAM, text box line breaks, long list items, moving shadows, and roof lighting.

## beta/update-54

*September 26, 2017*

- Sandbox mode online again: it hosts a single-lot server on port 37564 for LAN or internet players (everyone who joins is an admin for now), and can design Sims with CAS.
- Any lot can be saved locally with Ctrl+S for sandbox mode (without signs, door passwords, or card decks).
- The chat box resizes with Ctrl + and Ctrl -; login screen fixes after a wrong password.
- Volcanic imports empty `.obj` files.
- The admin API moved from Nancy to ASP.NET.
- An experimental fix for async tasks slowing the server on Linux.

## beta/update-52

*September 7, 2017*

- Mipmaps in 3D mode, so walls, floors, and objects look better with or without anti-aliasing; fixed for OpenGL and extreme levels.
- Grass no longer shimmers like noise.
- Fixed a lighting bug with avatars, odd transparency with anti-aliasing, and Center Sim in 3D.

## beta/update-50

*August 31, 2017*

- 3D mode: the game renders and plays in 3D in real time (in the launcher's settings, or `-3d`).
- Bug fixes for interactions, disappearing purchased objects, lot saves, and common SimAntics exceptions.
- 2D mode: mouse wheel zoom, and optional 3D wall shadows.

> **The snapshot.** SimsCraft's `TSOClient/` is FreeSO's `master` on August 10, 2017
> (commit `47150446`, "Client and Server compile for Any CPU"): beta/update-46, plus FreeSO's
> server networking fixes of August 9. Updates 47 to 49 were never announced; update-50 is the
> next announced build.

## beta/update-46

*August 8, 2017*

- Fixed the city data service, chat bubble text height, and the relationship dialog in roommates mode.
- Cursors are back on.
- Faster city view.
- The server closes faulty connections instead of crashing.

## beta/update-45

*August 8, 2017*

- Fixed disconnects while a lot's state changes, and lots stuck during slow disk access.
- Shutting down frees stuck lots at once.
- A VM abort mode that ends runaway loops faster.

## beta/update-44

*July 23, 2017*

- Fixed severe lag from loose or dirty objects (mostly on store lots).
- Fixed expected animation events for backward animations, and the out-of-world controller list being ignored.

## beta/update-43

*July 20, 2017*

- Sims can be retired, and lots are deleted when their last avatar leaves.
- You can't buy a lot you already own.
- Fixed moving out; Center Sim accounts for terrain height.

## beta/update-42

*July 19, 2017*

- Fixed a DirectX crash with water tiles.
- Fixed CAS and Buy/Move Lot error messages, category change errors, and ownership of ducks given to players.

## beta/update-41

*July 17, 2017*

- Quick fixes to the terrain tools, the grass tool's icon and rendering, the paper girl, slope checks on every floor, and NPCs on slopes.

## beta/update-40

*July 17, 2017*

- The terrain tools: raise and lower ground, flatten it, and shape mountains, cliffs, and water-filled craters.
- A reworked grass tool that paints like a brush.
- Floor tiles and foliage sit on slopes, with a new 3D floor renderer.
- Work toward running The Sims 1 in FreeSO's engine.
- Known issues: water and pool rendering artifacts, and clicking on high terrain.

## beta/update-36

*June 16, 2017*

- A Salvage global interaction on every object, for crafting components.
- One ActiveQueueBlock system for Allow Push and Run Immediately interactions (fixes the "running man" bug).
- Very old `.fsov` saves load again.
- Undeletable objects (such as dead plants) can be taken off sale; the VM knows when an object is for sale.
- Fixed Expanded Double Tall EODs, a crash with no lights or rooms, and two-Sim object socials on some lots.
- Fixed TSO sandbox mode, with a dialog to choose a sandbox.
- Fixed a restaurant chef looping forever when an order screen wasn't ready.
- More fixes for the new UI invalidation.

## beta/update-34

*May 14, 2017*

- Advanced lighting and shadows: lights glow, nearby objects cast shadows, and shadows follow the sun.
- Graphics options to turn off FreeSO lighting, city shadows, or surrounding lots.
- The relationship web is now a sortable, searchable list (friends, enemies, almost-friends, almost-enemies, roommates).
- New plugins: the Rock 'N' Roadie bandstand, War Game, Carducopia card game, and Definitron game timer.
- Money earned or spent on objects appears above your head.
- Owners can name clothing racks; room score works outdoors; administrators get a MOMI badge.
- Roommates can join full lots.
- Slightly better pizza payouts.
- Inactive Sims disconnect after 15 minutes, after a 5-minute warning.
- Various lag and object fixes.

## beta/update-31

*April 14, 2017*

- The Costume Trunk EOD, with over 200 outfits.

## beta/update-30

*April 13, 2017*

- Non-English clients can play the $5 and $10 slot machines.
- Higher maximum balances for every slot machine.
- Fixed a CAS exception; the head and body pages refresh when switching gender.
- Customers can no longer edit store clothing racks' names or prices.

## beta/update-29

*April 11, 2017*

- The Slots EOD: all three slot machines are available (with tight money bounds for now).
- Slot machine balances can't go into debt, so owners stock machines to cover winnings.
- A quick fix for VM crashes on EOD servers.

## beta/update-28b

*April 2, 2017*

- Text-to-speech can be turned back on with `EnableTTS=True` in `config.ini`.
- Fires can still start, but no longer spread.

## beta/update-28

*April 1, 2017*

- April Fools' build: the game became "MyLand", Sims became "MyLanders", and it enabled fire and voice chat (along with joke notes such as toddlers and a 4D renderer).

## beta/update-27a

*March 29, 2017*

- Minor server and API changes.

## beta/update-26

*March 21, 2017*

- Crafting table objects go to the inventory instead of getting stuck on the source lot.
- Job lots no longer affect the top 100 lot rankings.

## beta/update-22 and beta/update-25

*March 19, 2017*

- Skill degradation applies to locked skills, except for the locked points.
- Solo job objects give less bonus with many workers: the full bonus needs 16 players (was 12), up to 2.5x.
- The canning station bonus dropped from 10 to 0.
- Skill decay matches the original TSO rate: gentler once two skills are maxed (up to 50 points), harsher beyond.

## beta/update-20 and beta/update-21

*March 17, 2017*

- The picking task works with several lot servers.
- The server closes the application fully on shutdown.
- Cleanup is disabled for everything but pets, to try to fix lots freezing.

## beta/update-19

*March 16, 2017*

- Back-end logging to help diagnose lot crashes.
- The pizza group money object resets ingredient contributions at the start of a round.

## beta/update-18

*March 15, 2017*

- Lots should no longer crash and trap Sims.
- Custom content in player inventories displays properly.

## beta/update-17

*March 9, 2017*

- The restaurant no longer deletes objects in use.
- A new FSOEngineQuery data variable for fast lot state queries.
- The server runs without SSL certificates when `certificate` is removed from `config.json`.
- Improved maintenance mode, and clearer CAS and login error messages.
- Lot error display (work in progress).

## content/beta-13 and content/beta-14

*February 27, 2017*

- Reset code runs when an object is deleted from an avatar's hands (restaurant).
- A liveness check closes and logs lots that stop responding for 90 seconds.
- Lot state is compressed, so several players joining no longer freeze a lot for 5 seconds or more.
- The updater actually updates.
- A working fullscreen toggle from windowed mode.
- Objects can no longer reset within a reset, or delete themselves while being deleted.

## content/update-12

*February 26, 2017*

- Alt+Enter enters fullscreen.
- Laptops no longer disappear.

## content/update-11

*February 26, 2017*

- Volume controls in the options menu.
- Door permissions are back: locks, fees, and number codes.
- Optimized smooth zoom; old Lot Visits entries are purged; monetary transactions slightly optimized.
- Right Control and Shift work everywhere in the game.
- The window can be resized by dragging, maximized, and snapped; backend work for dynamic resizing.
- A server URL option in the debug options.
- Fixed a Binding crash on logout.
- Stackable objects (such as restaurant plates) can no longer make infinite stacks.

## content/update-10

*February 24, 2017*

- Out-of-world objects are deleted during cleanup (fixes plates stuck in big lots).
- Fixed a memory leak, so servers stay up longer than 12 hours.
- EODs close properly when leaving a lot or cancelling an interaction.
- Sims whose routing fails three times on a job lot lose collision for that route.
- Deleting an object a Sim holds resets the Sim and the object they're using.
- Maids ignore out-of-world objects.

## content/update-9

*February 15, 2017*

- Robot Factory pays about 2.5x more per robot; restaurant base pay per meal tripled.
- Pizzamaker base payouts lowered and rescaled, and bonus payouts about halved.
- The skill bonus factor dropped from 20 to 15 (the maximum skill bonus is now 300).

## content/update-8

*February 14, 2017*

- SimAntics exception dialogs show at most 16 stack frames.
- Fixed lots not being buildable on first join or after a move.
- Objects moved out of bounds are handled correctly.
- Data service bindings are released when relogging Sims.
- A lot that fails to load boots the player instead of emptying the lot.
- Cleaned up lot clear mode.

## content/update-7

*February 13, 2017*

- Restored property filters on the gizmo.
- The lot page points to the target lot.
- Fixed pizza ingredients not returning to the deck after players leave.
- Volcanic: an incomplete BCON viewer and editor, and TRCN (BCON debug label) support.
- Removed the friends tuning cheat.

## content/update-6

*February 11, 2017*

- Store lots give discounts on repeat object purchases.
- Services lots have a 1.5x motive gain boost.
- The client shows avatars' ages.
- Fixed the client UI for admit mode 4.
- Fixed the Wake Up interaction; Sims are forced awake when they leave a lot.
- Joining a lot waits until the previous avatar has left.
- Fixed a far-zoom crash on DirectX.
- Lot categories can be changed only once a week.
- Logged lot load failure exceptions.
- Fixed carpools not driving away or calling workers.
- Fixed missing or wrong phone pie menu items.

## Before the open beta

FreeSO's tags from before the public game, each with its commit's message:

- **0.25xna3** (January 27, 2015): "Locking on writing"
- **0.2** (February 9, 2014): "Camera now sort of works when minimizing"
- **0.1** (January 8, 2014): "Last minute addition to client and servers."
