# Install differences

How two installed copies of *The Sims Online* differ, file by file. `TSO_GAME_DIR` and `TSO_BETA_DIR` name
the environment variables that pointed `tsofiles-check` at them: by the project's convention,
`TSO_GAME_DIR` is a production release and `TSO_BETA_DIR` a beta. `tsofiles-check` wrote this on
2026-10-16. It names files, archive entries, IFF chunks (the resources inside the game's object files),
and object IDs (GUIDs); it holds none of the game's own data.

When NSOClient, or FreeSO (which NSOClient is checked against), behaves differently on the two
copies, this shows what changed in the game's files, before anyone looks for a bug in the code.
It's written once: delete it and run `tsofiles-check` with both variables set to write it again.

## Summary

| | Files |
| --- | --- |
| Identical | 1541 |
| Only in `TSO_GAME_DIR` | 20 |
| Only in `TSO_BETA_DIR` | 77 |
| Different | 125 |

## Only in `TSO_GAME_DIR`

- `gamedata/uiscripts/fwebcommenteditdialog.uis`
- `gamedata/uitext.dir/_255_fwebcommenteditdlgstrings.cst`
- `housedata/default_house.xml`
- `objectdata/objects/objspf9.far`
- `uigraphics/customcontent/cc_bodiesbtn.bmp`
- `uigraphics/customcontent/cc_dropdown.bmp`
- `uigraphics/customcontent/cc_dropdownbtn.bmp`
- `uigraphics/customcontent/cc_dropdowntextline.bmp`
- `uigraphics/customcontent/cc_floorsbtn.bmp`
- `uigraphics/customcontent/cc_headsbtn.bmp`
- `uigraphics/customcontent/cc_objectsbtn.bmp`
- `uigraphics/customcontent/cc_textentry.bmp`
- `uigraphics/customcontent/cc_wallsbtn.bmp`
- `uigraphics/hints/hint_chasemaze.bmp`
- `uigraphics/hints/hint_mazepizza.bmp`
- `uigraphics/hints/hint_mechanicskill.bmp`
- `uigraphics/hints/hint_parental_bookmark.bmp`
- `uigraphics/hints/hint_pizza.bmp`
- `uigraphics/hints/hint_pizzachase.bmp`
- `video/tsointromovie.dat`

## Only in `TSO_BETA_DIR`

- `cities/city_0001/elevation.server`
- `cities/city_0001/terraintype.server`
- `cities/city_0002/elevation.server`
- `cities/city_0002/terraintype.server`
- `cities/city_0003/elevation.server`
- `cities/city_0003/terraintype.server`
- `cities/city_0004/elevation.server`
- `cities/city_0004/terraintype.server`
- `cities/city_0005/elevation.server`
- `cities/city_0005/terraintype.server`
- `cities/city_0006/elevation.server`
- `cities/city_0006/terraintype.server`
- `cities/city_0007/elevation.server`
- `cities/city_0007/terraintype.server`
- `cities/city_0008/elevation.server`
- `cities/city_0008/terraintype.server`
- `cities/city_0009/elevation.server`
- `cities/city_0009/terraintype.server`
- `cities/city_0010/elevation.server`
- `cities/city_0010/terraintype.server`
- `cities/city_0011/elevation.server`
- `cities/city_0011/terraintype.server`
- `cities/city_0012/elevation.server`
- `cities/city_0012/terraintype.server`
- `cities/city_0013/elevation.server`
- `cities/city_0013/terraintype.server`
- `cities/city_0014/elevation.server`
- `cities/city_0014/terraintype.server`
- `cities/city_0015/elevation.server`
- `cities/city_0015/terraintype.server`
- `cities/city_0016/elevation.server`
- `cities/city_0016/terraintype.server`
- `cities/city_0017/elevation.server`
- `cities/city_0017/terraintype.server`
- `cities/city_0018/elevation.server`
- `cities/city_0018/terraintype.server`
- `cities/city_0019/elevation.server`
- `cities/city_0019/terraintype.server`
- `cities/city_0020/elevation.server`
- `cities/city_0020/terraintype.server`
- `cities/city_0021/elevation.server`
- `cities/city_0021/terraintype.server`
- `cities/city_0022/elevation.server`
- `cities/city_0022/terraintype.server`
- `cities/city_0023/elevation.server`
- `cities/city_0023/terraintype.server`
- `cities/city_0024/elevation.server`
- `cities/city_0024/terraintype.server`
- `cities/city_0025/city_0001/elevation.bmp`
- `cities/city_0025/city_0001/elevation.server`
- `cities/city_0025/city_0001/forestdensity.bmp`
- `cities/city_0025/city_0001/foresttype.bmp`
- `cities/city_0025/city_0001/roadmap.bmp`
- `cities/city_0025/city_0001/terraintype.bmp`
- `cities/city_0025/city_0001/terraintype.server`
- `cities/city_0025/city_0001/thumbnail.bmp`
- `cities/city_0025/city_0001/vertexcolor.bmp`
- `cities/city_0025/elevation.server`
- `cities/city_0025/terraintype.server`
- `cities/city_0026/elevation.server`
- `cities/city_0026/terraintype.server`
- `cities/city_0027/elevation.server`
- `cities/city_0027/terraintype.server`
- `cities/city_0028/elevation.server`
- `cities/city_0028/terraintype.server`
- `cities/city_0029/elevation.server`
- `cities/city_0029/terraintype.server`
- `cities/city_0030/elevation.server`
- `cities/city_0030/terraintype.server`
- `music/modes/create/user/readme.txt`
- `music/modes/load/user/readme.txt`
- `music/modes/map/tsobuild4.mp3`
- `music/modes/map/tsobuild6.mp3`
- `music/modes/map/user/readme.txt`
- `music/modes/select/user/readme.txt`
- `sounddata/tsov2.hot`
- `sounddata/tsov2.hsm`

## Different files

### `.castanet/index.mrb`

84755 bytes in `TSO_GAME_DIR`, 87585 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `.castanet/properties.txt`

180 bytes in `TSO_GAME_DIR`, 180 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `.castanet/publish.mrb`

99366 bytes in `TSO_GAME_DIR`, 102651 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `AssetManagerD.dll`

503808 bytes in `TSO_GAME_DIR`, 503808 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `avatardata/accessories/appearances/appearances.dat`

FAR3, 47287 bytes in `TSO_GAME_DIR`, 47127 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 1, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/accessories/bindings/bindings.dat`

FAR3, 165413 bytes in `TSO_GAME_DIR`, 164997 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 4, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/accessories/meshes/meshes.dat`

FAR3, 2114381 bytes in `TSO_GAME_DIR`, 2044403 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 4, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/accessories/textures/textures.dat`

FAR3, 2400339 bytes in `TSO_GAME_DIR`, 2398861 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 1, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/animations/animations.dat`

FAR3, 161003506 bytes in `TSO_GAME_DIR`, 160775206 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 4668, only in `TSO_BETA_DIR`: 4659, changed: 17.

### `avatardata/bodies/appearances/appearances.dat`

FAR3, 202387 bytes in `TSO_GAME_DIR`, 182863 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 270, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/bodies/bindings/bindings.dat`

FAR3, 291344 bytes in `TSO_GAME_DIR`, 263708 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 270, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/bodies/collections/collections.dat`

FAR3, 7955 bytes in `TSO_GAME_DIR`, 7318 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 0, only in `TSO_BETA_DIR`: 0, changed: 5.

### `avatardata/bodies/meshes/meshes.dat`

FAR3, 7191963 bytes in `TSO_GAME_DIR`, 6966551 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 6, only in `TSO_BETA_DIR`: 0, changed: 1.

### `avatardata/bodies/outfits/outfits.dat`

FAR3, 81741 bytes in `TSO_GAME_DIR`, 73883 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 90, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/bodies/purchasables/purchasables.dat`

FAR3, 65059 bytes in `TSO_GAME_DIR`, 58731 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 90, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/bodies/textures/textures.dat`

FAR3, 70812152 bytes in `TSO_GAME_DIR`, 64992490 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 270, only in `TSO_BETA_DIR`: 0, changed: 28.

### `avatardata/bodies/thumbnails/thumbnails.dat`

FAR3, 4055494 bytes in `TSO_GAME_DIR`, 3680269 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 270, only in `TSO_BETA_DIR`: 0, changed: 30.

### `avatardata/hands/groups/groups.dat`

FAR3, 4603 bytes in `TSO_GAME_DIR`, 4599 in `TSO_BETA_DIR`.
Every entry is the same; the container's layout differs.

### `avatardata/hands/meshes/meshes.dat`

FAR3, 23434 bytes in `TSO_GAME_DIR`, 23191 in `TSO_BETA_DIR`.
Every entry is the same; the container's layout differs.

### `avatardata/heads/appearances/appearances.dat`

FAR3, 88101 bytes in `TSO_GAME_DIR`, 87498 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 9, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/heads/bindings/bindings.dat`

FAR3, 123171 bytes in `TSO_GAME_DIR`, 122328 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 9, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/heads/collections/collections.dat`

FAR3, 2700 bytes in `TSO_GAME_DIR`, 2670 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 0, only in `TSO_BETA_DIR`: 0, changed: 1.

### `avatardata/heads/meshes/meshes.dat`

FAR3, 2144911 bytes in `TSO_GAME_DIR`, 2091320 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 3, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/heads/outfits/outfits.dat`

FAR3, 35489 bytes in `TSO_GAME_DIR`, 35243 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 3, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/heads/purchasables/purchasables.dat`

FAR3, 27952 bytes in `TSO_GAME_DIR`, 27757 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 3, only in `TSO_BETA_DIR`: 0, changed: 0.

### `avatardata/heads/textures/textures.dat`

FAR3, 10616050 bytes in `TSO_GAME_DIR`, 10532147 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 9, only in `TSO_BETA_DIR`: 0, changed: 3.

### `avatardata/heads/thumbnails/thumbnails.dat`

FAR3, 1601850 bytes in `TSO_GAME_DIR`, 1588881 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 9, only in `TSO_BETA_DIR`: 0, changed: 3.

### `censor/censor.dat`

3481 bytes in `TSO_GAME_DIR`, 3434 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `cities/city_0022/vertexcolor.bmp`

786488 bytes in `TSO_GAME_DIR`, 786488 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `cities/city_0024/vertexcolor.bmp`

786488 bytes in `TSO_GAME_DIR`, 786488 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `DBAppServiceClientD.dll`

393216 bytes in `TSO_GAME_DIR`, 372736 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uiscripts/housepage.uis`

12364 bytes in `TSO_GAME_DIR`, 12085 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uiscripts/jobobjband.uis`

5290 bytes in `TSO_GAME_DIR`, 3181 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uiscripts/querypanel.uis`

12127 bytes in `TSO_GAME_DIR`, 11840 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_137_placementerrs.cst`

2841 bytes in `TSO_GAME_DIR`, 2776 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_159_objecttts.cst`

567 bytes in `TSO_GAME_DIR`, 495 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_172_buildpanelstrings.cst`

271 bytes in `TSO_GAME_DIR`, 253 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_206_querypanelstrings.cst`

1027 bytes in `TSO_GAME_DIR`, 1006 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_208_roommateprotocolstrings.cst`

13296 bytes in `TSO_GAME_DIR`, 13296 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_209_logindlgstrings.cst`

119 bytes in `TSO_GAME_DIR`, 115 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_210_cityselprotocolstrings.cst`

3172 bytes in `TSO_GAME_DIR`, 2799 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_211_housesimloginstrings.cst`

2915 bytes in `TSO_GAME_DIR`, 2912 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_222_loginprotocol.cst`

1676 bytes in `TSO_GAME_DIR`, 996 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_223_hostvisitorprotocol.cst`

1751 bytes in `TSO_GAME_DIR`, 1730 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_227_friendshipweb.cst`

91 bytes in `TSO_GAME_DIR`, 65 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_231_pppetitionformdlg.cst`

2030 bytes in `TSO_GAME_DIR`, 2038 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_238_citydescriptionstrings.cst`

14385 bytes in `TSO_GAME_DIR`, 12389 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_242_creditsstrings.cst`

31939 bytes in `TSO_GAME_DIR`, 26574 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_245_buybuildmodestrings.cst`

693 bytes in `TSO_GAME_DIR`, 266 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_246_lotpurchasedlgstrings.cst`

797 bytes in `TSO_GAME_DIR`, 787 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_247_lotnameeditdlgstrings.cst`

946 bytes in `TSO_GAME_DIR`, 941 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_248_hintsstrings.cst`

7701 bytes in `TSO_GAME_DIR`, 2791 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_252_lotcategoryselectiondlgstrings.cst`

495 bytes in `TSO_GAME_DIR`, 186 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `gamedata/uitext.dir/_253_jobobjband.cst`

466 bytes in `TSO_GAME_DIR`, 43 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `GZFont.dll`

282624 bytes in `TSO_GAME_DIR`, 282624 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `HitLabServiceD.dll`

339968 bytes in `TSO_GAME_DIR`, 339968 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `HitListsTemp.dat`

DBPF, 96165 bytes in `TSO_GAME_DIR`, 96380 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 16, only in `TSO_BETA_DIR`: 2, changed: 35.

### `HitMp3DecodeD.dll`

200704 bytes in `TSO_GAME_DIR`, 200704 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `InternetServiceD.dll`

102400 bytes in `TSO_GAME_DIR`, 102400 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `objectdata/globals/bathe.iff`

IFF, 7581 bytes in `TSO_GAME_DIR`, 10488 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | BCON 8192, 8193, 8194, 8195, 8196, 8197; TRCN 8192, 8193, 8194, 8195, 8196, 8197 | rsmp 0 |  |

### `objectdata/globals/behavior.iff`

IFF, 37988 bytes in `TSO_GAME_DIR`, 37984 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | STR# 128, 129, 130, 131, 132, 134, 135, 136, 137, 139, 141, 142, 150, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 167, 168, 169, 170, 171, 172, 173, 174, 176, 177, 178, 200, 201, 202, 203, 204, 205, 206, 207, 208, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510; rsmp 0 |  |

### `objectdata/globals/build.iff`

IFF, 23907 bytes in `TSO_GAME_DIR`, 23907 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | STR# 128, 129, 130, 131, 132, 133, 134, 135 |  |

### `objectdata/globals/carglobals.iff`

IFF, 6183 bytes in `TSO_GAME_DIR`, 6183 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | TTAs 129 |  |

### `objectdata/globals/catglobals.iff`

IFF, 68731 bytes in `TSO_GAME_DIR`, 75972 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | BCON 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8202; TRCN 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8202 | STR# 305, 8192; TTAs 129; rsmp 0 |  |

### `objectdata/globals/clothingrackssemiglobal.iff`

IFF, 7800 bytes in `TSO_GAME_DIR`, 8031 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | BCON 8193; TRCN 8193 | TTAs 129; rsmp 0 |  |

### `objectdata/globals/counterglobals.iff`

IFF, 19757 bytes in `TSO_GAME_DIR`, 19963 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | BCON 8196; TRCN 8196 | BHAV 8216, 8217, 8218, 8225, 8227; TPRP 8216, 8217, 8218, 8225, 8227; TTAs 129; rsmp 0 |  |

### `objectdata/globals/credits.iff`

IFF, 4716 bytes in `TSO_GAME_DIR`, 4716 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | STR# 163 |  |

### `objectdata/globals/decoration.iff`

IFF, 5238 bytes in `TSO_GAME_DIR`, 8145 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | BCON 8192, 8193, 8194, 8195, 8196, 8197; TRCN 8192, 8193, 8194, 8195, 8196, 8197 | rsmp 0 |  |

### `objectdata/globals/dogglobals.iff`

IFF, 67439 bytes in `TSO_GAME_DIR`, 75996 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | BCON 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8202; TRCN 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8201, 8202, 8203, 8204, 8205, 8206, 8207, 8208 | STR# 305, 8192; TTAs 129; rsmp 0 |  |

### `objectdata/globals/doorglobals.iff`

IFF, 22860 bytes in `TSO_GAME_DIR`, 23324 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | BCON 8194, 8198; TRCN 8194, 8198 | STR# 256, 8192; TTAs 129; rsmp 0 |  |

### `objectdata/globals/global.iff`

IFF, 123817 bytes in `TSO_GAME_DIR`, 122456 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` | BCON 271; FCNS 5 | TRCN 272 | BHAV 265, 430; FCNS 1; STR# 128, 130, 150, 152, 153, 154, 156, 158, 159, 170, 171, 257, 301, 303, 304, 305, 501, 502, 503, 504, 505; TPRP 265; TRCN 271; rsmp 0 |  |

### `objectdata/globals/lightglobals.iff`

IFF, 15386 bytes in `TSO_GAME_DIR`, 15811 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` | BHAV 8228; TPRP 8228 | BCON 8193; TRCN 8193 | BHAV 8206, 8221; TPRP 8206; TTAB 129; TTAs 129, 130; rsmp 0 |  |

### `objectdata/globals/live.iff`

IFF, 13212 bytes in `TSO_GAME_DIR`, 13212 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | STR# 130, 131, 132, 133, 134, 135, 136, 137, 138, 139 |  |

### `objectdata/globals/personglobals.iff`

IFF, 226313 bytes in `TSO_GAME_DIR`, 226706 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | BHAV 8197, 8202, 8310, 8408, 8409, 8570; STR# 301, 304, 305, 8192; TPRP 8408, 8570; TTAs 129, 130, 131; rsmp 0 |  |

### `objectdata/globals/petsitglobals.iff`

IFF, 8903 bytes in `TSO_GAME_DIR`, 9441 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | TRCN 8192, 8193, 8194 | rsmp 0 |  |

### `objectdata/globals/skillobjects.iff`

IFF, 19324 bytes in `TSO_GAME_DIR`, 19275 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | BHAV 8212; STR# 256, 301, 303; rsmp 0 |  |

### `objectdata/globals/skillobjects.otf`

5762 bytes in `TSO_GAME_DIR`, 5700 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `objectdata/globals/social2siminobjectsemiglobal.iff`

IFF, 10626 bytes in `TSO_GAME_DIR`, 12220 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | TRCN 8194, 8195, 8196, 8197, 8198 | rsmp 0 |  |

### `objectdata/globals/socialglobals.iff`

IFF, 38498 bytes in `TSO_GAME_DIR`, 39484 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | TRCN 8192 | rsmp 0 |  |

### `objectdata/globals/sofaglobals.iff`

IFF, 48082 bytes in `TSO_GAME_DIR`, 48046 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | BHAV 8216, 8254, 8296, 8297, 8298, 8299, 8301; TTAs 129, 130; rsmp 0 |  |

### `objectdata/globals/surfaceplacementsemiglobal.iff`

IFF, 1964 bytes in `TSO_GAME_DIR`, 2464 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  | TRCN 4096, 4097 | TTAs 129; rsmp 0 |  |

### `objectdata/globals/trunkglobals.iff`

IFF, 5859 bytes in `TSO_GAME_DIR`, 5859 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `(this file)` |  |  | TTAs 129 |  |

### `objectdata/objects/objiff.far`

FAR1, 17726000 bytes in `TSO_GAME_DIR`, 17921477 in `TSO_BETA_DIR`.

| Entry | Only in `TSO_GAME_DIR` | Only in `TSO_BETA_DIR` | Changed | Object GUIDs |
| --- | --- | --- | --- | --- |
| `2personportal.iff` |  | TRCN 4097 | STR# 129, 256, 257, 301; TTAs 129; rsmp 0 |  |
| `animtester.iff` |  |  | STR# 300; TTAs 129 |  |
| `aquarium1.iff` |  | BCON 4096; TRCN 4096, 4097 | BHAV 4103, 4113, 4125; OBJD 16807; STR# 129, 130, 256, 257, 301, 304; TPRP 4113, 4125; TTAs 129; rsmp 0 | 98e0f8bd |
| `ash.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `athleticsbench.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 302; TTAs 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142; rsmp 0 |  |
| `awnings.iff` |  | TRCN 4097, 4098 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `awnings2x2unleashed.iff` |  | BCON 4099; TRCN 4097, 4098, 4099 | rsmp 0 |  |
| `awnings3.iff` |  | BCON 4099; TRCN 4097, 4098, 4099 | BHAV 4128; STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `awnings4.iff` |  | BCON 4099; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104 | rsmp 0 |  |
| `awningthatch.iff` |  | BCON 4099; TRCN 4097, 4098, 4099 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `backdroptheater.iff` |  |  | STR# 129, 256, 257, 302; TTAs 129 |  |
| `bannerlamp.iff` |  | BCON 4097; TRCN 4097 | rsmp 0 |  |
| `bar.iff` |  |  | STR# 129, 130, 256, 257, 301, 302, 303; TTAs 129 |  |
| `barbeach.iff` |  | BCON 4096, 4101; TRCN 4096, 4101 | STR# 129, 130, 256, 257, 301, 303; rsmp 0 |  |
| `bars.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 300, 301, 303, 304; TTAs 128; rsmp 0 |  |
| `bars2.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 300, 301, 303, 304; TTAs 128; rsmp 0 |  |
| `bars3.iff` |  |  | STR# 129, 130, 256, 257, 301, 303, 304; TTAs 128 |  |
| `bball.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 131, 132, 256, 257, 302, 304; TTAs 129; rsmp 0 |  |
| `bbq.iff` |  |  | BHAV 4134, 4135; STR# 129, 256, 257, 301, 302, 303, 304; TTAs 129; rsmp 0 |  |
| `bedheart.iff` | BHAV 4191, 4194, 4195, 4196; OBJf 16811, 16813, 16814, 16815, 16817, 16818, 16819, 16821; TPRP 4191, 4194, 4195, 4196 | BCON 4096, 4098, 4101, 4102, 4103; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103 | BHAV 4096, 4099, 4109, 4110, 4111, 4119, 4130, 4147, 4148, 4149, 4150, 4157, 4165, 4189, 4215, 4216, 4219, 4220, 4221, 4223, 4225, 4229; OBJD 16807, 16811, 16813, 16814, 16815, 16817, 16818, 16819, 16821, 16822; OBJf 16808, 16810, 16816, 16820; STR# 129, 130, 131, 132, 256, 257, 258, 301, 302, 303; TPRP 4099, 4130, 4148, 4149, 4150, 4215, 4219, 4221, 4225; TTAB 129; TTAs 129, 130, 131, 132, 133; rsmp 0 | 2ad15359, 2a65180b, 2af942e3, 29b837ac, 2a21356e, b2df4c76, 8ad53356, 2bdd1e0b, 45c779d5, 2d8a27c2 |
| `bedinteractions.iff` | STR# 303 | TRCN 4096, 4097 | BHAV 4115, 4116; STR# 129, 256, 401; TTAs 129; rsmp 0 |  |
| `beds.iff` |  | BCON 4096, 4098; TRCN 4096, 4097, 4098, 4099 | BHAV 4113, 4153; OBJD 16824; STR# 129, 130, 256, 257, 258, 301; TPRP 4113; TTAs 129, 130, 131, 132, 133; rsmp 0 | 82e04c5b |
| `beds2.iff` |  | BCON 4096, 4098; TRCN 4096, 4098 | BHAV 4153; STR# 129, 130, 131, 132, 256, 257, 258, 301; TTAs 129, 130, 131, 132, 133; rsmp 0 |  |
| `beds3.iff` |  | BCON 4096, 4098; TRCN 4096, 4097, 4098, 4099 | TTAs 129; rsmp 0 |  |
| `bedsbunkbed.iff` |  |  | BHAV 4097, 4103, 4134; CTSS 2002; OBJD 16824; STR# 129, 130, 256, 257, 258, 301; TTAs 129, 130, 131, 132, 133; rsmp 0 | 33e463cd |
| `bedssingle2.iff` |  | BCON 4096, 4098; TRCN 4096, 4098 | STR# 129, 130, 256, 257, 258, 301; TTAs 129, 130, 131, 132, 133; rsmp 0 |  |
| `bedssingle22.iff` |  | TRCN 4097, 4099 | STR# 129, 130, 256, 257, 258, 301; TTAs 129, 130, 131, 132, 133; rsmp 0 |  |
| `birthdaycake.iff` |  | BCON 4099, 4101, 4102, 4103, 4104, 4105; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104, 4105 | STR# 129, 130, 256, 257, 258, 301, 302, 303, 304, 402; TTAs 128, 129, 130, 131, 132, 133, 134, 135, 136, 137; rsmp 0 |  |
| `bjdealer.iff` |  |  | STR# 129, 130, 200, 256, 257, 301, 303, 304 |  |
| `blackjack.iff` |  | BCON 4096; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 301, 302, 303, 304, 305, 4097, 4098; TTAs 129; rsmp 0 |  |
| `bookcases.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 256, 301, 304; TTAs 129, 130, 131; rsmp 0 |  |
| `bookcases2.iff` |  |  | STR# 129, 130, 256, 301, 304; TTAs 129, 130, 131 |  |
| `bookcases3.iff` |  |  | STR# 129, 130, 256, 301, 304; TTAs 129, 130, 131 |  |
| `bubblemaker.iff` |  | TRCN 4097, 4098, 4099 | STR# 129, 130, 256, 257, 302, 304; TTAs 129; rsmp 0 |  |
| `bubbles.iff` |  |  | STR# 129, 256, 257, 300; TTAs 129 |  |
| `buffettable.iff` |  |  | BHAV 4129; STR# 129, 256, 257, 301, 302, 303; TTAs 129; rsmp 0 |  |
| `buffettablevacation.iff` |  |  | BHAV 4100; STR# 129, 256, 257, 301, 302, 303; TTAs 129; rsmp 0 |  |
| `buildingsigns.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 301; TTAs 130; rsmp 0 |  |
| `bunnyrabbit.iff` |  | TRCN 4096 | rsmp 0 |  |
| `campfire.iff` |  | BCON 4098, 4099; TRCN 4098, 4099 | STR# 129, 130, 256, 257, 302, 304; TTAs 128, 129; rsmp 0 |  |
| `campfireghost.iff` |  |  | STR# 129, 200, 256, 257, 303, 304; TTAs 129 |  |
| `canningstation.iff` |  | TRCN 4096, 4098, 4099, 4100, 4101, 4102 | STR# 129, 256, 257, 300, 301, 303, 304, 305; TTAs 129, 130, 131, 132, 133; rsmp 0 |  |
| `cannon.iff` |  | TRCN 4097, 4098 | STR# 129, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `cannonball.iff` |  |  | STR# 129, 256, 257, 300; TTAs 129 |  |
| `carbentley.iff` | whole entry |  |  |  |
| `cardboardbox.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 257, 303; rsmp 0 |  |
| `carjunk.iff` | whole entry |  |  |  |
| `carlimo.iff` | whole entry |  |  |  |
| `carmjeep.iff` | whole entry |  |  |  |
| `carportal.iff` | whole entry |  |  |  |
| `carpublictransit.iff` |  | BCON 4097; TRCN 4096, 4097 | rsmp 0 |  |
| `carsquad.iff` | whole entry |  |  |  |
| `carstaff.iff` | whole entry |  |  |  |
| `carstd.iff` | whole entry |  |  |  |
| `carsuv.iff` | whole entry |  |  |  |
| `cartown.iff` | whole entry |  |  |  |
| `cartunleashed.iff` |  | BCON 4096, 4097, 4099, 4101; TRCN 4096, 4097, 4099, 4101 | rsmp 0 |  |
| `cashregisters.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 256, 257, 301, 302, 304; TTAs 128; rsmp 0 |  |
| `castlefence.iff` |  | BCON 4099; TRCN 4099, 4100 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `chairconnecting.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | STR# 129, 130, 256, 257; TTAs 128; rsmp 0 |  |
| `chairconnectingtheater.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257; TTAs 128; rsmp 0 |  |
| `chairdinmoroccan.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `chairsdiningunleashed.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `chairshd_hd.iff` |  | TRCN 4096 | STR# 129, 130, 256, 257; TTAs 129, 130, 131; rsmp 0 |  |
| `chairslr1tile.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `chairslr1tilehd.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257; TTAs 129, 130; rsmp 0 |  |
| `chairslr2.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `chairslr3.iff` |  | BCON 4097; TRCN 4097, 4098 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `chairslr4.iff` |  | BCON 4097; TRCN 4096, 4097, 4098 | STR# 129, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `chairslr5.iff` |  | BCON 4097; TRCN 4096, 4097, 4098 | CTSS 2000; OBJD 16812; STR# 129, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 | 35490203 |
| `chairslrunleashed.iff` |  | BCON 4097; TRCN 4096, 4097 | rsmp 0 |  |
| `chaiselounge.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 256, 257, 302; TTAs 129, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142; rsmp 0 |  |
| `chalkboard.iff` |  | TRCN 4098 | STR# 129, 256, 257, 301, 303, 304; TTAs 129; rsmp 0 |  |
| `charades.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 258, 301; TTAs 129, 130; rsmp 0 |  |
| `chemistryset.iff` |  |  | STR# 129, 130, 256, 300, 301, 303, 304, 305; TTAs 129, 130, 131, 132, 133 |  |
| `chesstable.iff` |  | TRCN 4097, 4098, 4099 | BHAV 4118, 4128; STR# 129, 130, 256, 257, 301, 302, 303; TTAs 129; rsmp 0 |  |
| `christmastree.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `clockoffice.iff` |  | BCON 4096; TRCN 4096 | BHAV 4101; STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `clockpost.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 256, 257; rsmp 0 |  |
| `clockpostswiss.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 256, 257; rsmp 0 |  |
| `clothingboothvac.iff` |  | BCON 4096, 4098; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | OBJD 16821; rsmp 0 | 1f0dc8f1 |
| `clothingrack2.iff` |  | BCON 4097, 4098, 4102; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103 | OBJD 16807, 16809; STR# 129, 256, 257, 300, 301, 303, 304; TTAs 131; rsmp 0 | 2e4bc8c6, 2e6980cc |
| `clothingracks.iff` |  | TRCN 4096, 4097 | OBJD 16815, 16816, 16819, 16820; STR# 129, 256, 257, 301, 302; rsmp 0 | 32a7f175, 81affe1d, 743498da, 4666b58a |
| `coffeeesp.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `coffeem.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 304; TTAs 130; rsmp 0 |  |
| `collar_cat_blue.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `collar_cat_blue_ribbon.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_cat_brown.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_cat_pink.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_cat_pink_ribbon.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `collar_cat_red.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_cat_red_ribbon.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `collar_cat_spike.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_dog_blue.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_dog_blue_ribbon.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_dog_brown.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_dog_pink.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_dog_pink_ribbon.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_dog_red.iff` |  | TRCN 4097 | rsmp 0 |  |
| `collar_dog_red_ribbon.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `collar_dog_spike.iff` |  | TRCN 4097 | rsmp 0 |  |
| `column3.iff` |  |  | CTSS 2000; rsmp 0 |  |
| `columnarch.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `columnarchaquaduct.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `columnarchbeach.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `columnarchcarnival.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | CTSS 2000; STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `columnarchmoroccan.iff` |  |  | CTSS 2000; STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `columnarchromantiled.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `columnarchscifi.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `columnarchstone.iff` |  |  | STR# 129, 130, 256, 257, 303 |  |
| `comeandsee.iff` |  |  | STR# 129, 130, 131, 132, 256, 257, 258, 303, 304, 500; TTAs 129 |  |
| `computers.iff` |  | TRCN 4096 | STR# 129, 256, 257, 301, 303, 4096, 4097; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `computers5.iff` |  | TRCN 4098, 4099 | BHAV 4105; STR# 129, 256, 257, 301, 303, 4096, 4097; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `cone.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `constructionhorse.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `control-garden.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `control-petshow.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `conveyorbelt.iff` |  | BCON 4099; TRCN 4099, 4100 | STR# 129, 256, 257, 300, 303, 304; TTAs 128; rsmp 0 |  |
| `conveyorcontrol.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `costumesports.iff` |  | TRCN 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `costumetrunk.iff` |  | TRCN 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `costumetrunktoga.iff` |  | TRCN 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `countercasino.iff` |  | BCON 4097, 4098, 4099; TRCN 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `counterdisplay.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 302, 303; TTAs 129, 130, 131; rsmp 0 |  |
| `counterdisplayvacation.iff` |  | TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `counters.iff` |  | BCON 4097, 4098, 4099; TRCN 4096, 4097, 4098, 4099, 4100 | BHAV 4097, 4103, 4104, 4110, 4112; STR# 129, 130, 256, 257, 300, 303, 304; TPRP 4097, 4103, 4104, 4110, 4112; rsmp 0 |  |
| `counters2.iff` |  | BCON 4097, 4098, 4099; TRCN 4097, 4098, 4099, 4100 | BHAV 4097, 4103, 4112; STR# 129, 130, 256, 257, 300, 303, 304; TPRP 4097, 4103, 4112; rsmp 0 |  |
| `counters3.iff` |  | BCON 4097, 4098, 4099; TRCN 4096, 4097, 4098, 4099, 4100 | BHAV 4097, 4103, 4112, 4113, 4139, 4141; STR# 129, 130, 256, 257, 300, 303, 304; TPRP 4097, 4103, 4112, 4113; TTAs 128; rsmp 0 |  |
| `counters4.iff` |  | BCON 4098; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `counters5.iff` |  | BCON 4096, 4098; TRCN 4096, 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `counters6.iff` |  | BCON 4098; TRCN 4096, 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `counterwall.iff` |  | BCON 4097, 4098, 4099; TRCN 4096, 4097, 4098, 4099, 4100 | BHAV 4097, 4103, 4112, 4117; STR# 129, 130, 256, 257, 300, 303, 304; TPRP 4097, 4103, 4112, 4117; rsmp 0 |  |
| `ctoldworld.iff` |  | TRCN 4096, 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `ctscifi.iff` |  | TRCN 4096, 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `ctuniform.iff` |  | TRCN 4096, 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `ctvaudeville.iff` |  | TRCN 4096, 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `ctvegas.iff` |  | TRCN 4096, 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `cuckooclock.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257; TTAs 129; rsmp 0 |  |
| `curtain.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257, 301, 304; TTAs 129; rsmp 0 |  |
| `curtainsunleashed.iff` |  | BCON 4099; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104 | rsmp 0 |  |
| `dancecage.iff` |  |  | STR# 129, 130, 131, 132, 256, 257, 301, 304; TTAs 129 |  |
| `dancefloor.iff` |  |  | OBJD 16807; STR# 129, 130, 131, 132, 256, 257, 301, 303, 304; TTAs 129 | 1e8b9ea7 |
| `deadmouse.iff` |  | BCON 4098, 4099; TRCN 4098, 4099 | rsmp 0 |  |
| `desks.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | BHAV 4098, 4100, 4104, 4105; STR# 129, 257, 303; TPRP 4098, 4100, 4104, 4105; rsmp 0 |  |
| `desks2.iff` |  |  | BHAV 4098, 4100, 4104; STR# 129, 257, 303; TPRP 4098, 4100, 4104; rsmp 0 |  |
| `desks3.iff` |  |  | BHAV 4098, 4100, 4104, 4105, 4107; CTSS 2001; OBJD 16810; STR# 129, 257, 303; TPRP 4098, 4100, 4104, 4105, 4107; rsmp 0 | 29db9b3a |
| `destination.iff` |  |  | STR# 129, 256, 257, 301, 302; TTAs 128 |  |
| `devcheats.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 301, 304, 4096; TTAs 129, 130, 131, 132, 133, 134; rsmp 0 |  |
| `dfcontroller.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `dice.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 256, 257, 301; TTAs 129; rsmp 0 |  |
| `diningbooth.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4117, 4118; STR# 129, 130, 257, 303; TPRP 4100, 4111, 4117; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `diningchairs.iff` |  | TRCN 4096 | STR# 129, 130, 256, 257; TTAs 128, 129, 130, 131, 132, 133; rsmp 0 |  |
| `diningchairs2.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | STR# 129, 130, 256, 257; TTAs 128, 129, 130, 131, 132, 133; rsmp 0 |  |
| `diningchairs3.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | STR# 129, 130, 256, 257; TTAs 128, 129, 130, 131, 132, 133; rsmp 0 |  |
| `diningchairs4.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | STR# 129, 130, 256, 257; TTAs 128, 129, 130, 131, 132, 133; rsmp 0 |  |
| `diningpodium.iff` |  |  | STR# 129, 130, 256, 257, 301, 302, 303; TTAs 129 |  |
| `diningtable2x1.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | BHAV 4098, 4100, 4104; STR# 129, 257, 303; TPRP 4098, 4100, 4104; rsmp 0 |  |
| `diningtablecircular.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4117, 4118; STR# 129, 130, 257, 303; TPRP 4111, 4117; rsmp 0 |  |
| `diningtabledeuce.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4117, 4118; STR# 129, 130, 257, 303; TPRP 4100, 4111, 4117, 4118; rsmp 0 |  |
| `diningtablelodge.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4113, 4117, 4118; TPRP 4100, 4111, 4113, 4117, 4118; rsmp 0 |  |
| `diningtables.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4113, 4114, 4117, 4118, 4121; STR# 129, 130, 257, 303; rsmp 0 |  |
| `diningtables2.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4113, 4117, 4118; STR# 129, 130, 257, 303; TPRP 4100, 4113, 4117, 4118; rsmp 0 |  |
| `diningtables3.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4113, 4118, 4121; STR# 129, 130, 257, 303; TPRP 4100, 4111, 4113, 4118, 4121; rsmp 0 |  |
| `diningtablesbeach.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4113, 4117, 4118, 4121; TPRP 4100, 4111, 4113, 4117, 4118, 4121; rsmp 0 |  |
| `dishwashers.iff` |  | BCON 4097, 4098, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | BHAV 4114, 4116, 4117, 4130; STR# 129, 130, 256, 257, 300, 303, 304; TPRP 4114, 4116, 4117, 4130; TTAs 128, 129; rsmp 0 |  |
| `displaycases.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | STR# 129, 130, 256, 257, 302, 303; TTAs 129, 130, 131; rsmp 0 |  |
| `displaycaseunleashed.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `displaycounterunleashed.iff` |  | TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `displayfloorpetpen.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `displayrack_collars.iff` |  | TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `djbooth.iff` |  | BCON 4097, 4100, 4103; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103 | OBJD 16808; STR# 129, 130, 131, 132, 256, 257, 258, 303, 304; TTAs 131; rsmp 0 | e8e88d38 |
| `dogfightcloud.iff` |  | BCON 4100, 4102, 4103, 4105; TRCN 4100, 4102, 4103, 4105 | rsmp 0 |  |
| `doghole.iff` |  | BCON 4098, 4099; TRCN 4098, 4099 | rsmp 0 |  |
| `doghouse.iff` |  | BCON 4096, 4098; TRCN 4096, 4098 | rsmp 0 |  |
| `dollhouse.iff` |  |  | STR# 129, 130, 256, 257; TTAs 129 |  |
| `dooroneway.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 129, 130; rsmp 0 |  |
| `doors.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 300, 301; TTAs 130; rsmp 0 |  |
| `doors2.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 300, 301, 303; TTAs 130; rsmp 0 |  |
| `doors3.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | CTSS 2001, 2002; STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 130, 131; rsmp 0 |  |
| `doors4.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 130; rsmp 0 |  |
| `doors5.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | CTSS 2000, 2001, 2002, 2003, 2004, 2005; STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 130; rsmp 0 |  |
| `doors6.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 130; rsmp 0 |  |
| `doorstar.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 130; rsmp 0 |  |
| `doorsunleashed.iff` |  | BCON 4098; TRCN 4098 | rsmp 0 |  |
| `dressers.iff` |  | TRCN 4096 | STR# 129, 130, 256, 257; TTAs 129; rsmp 0 |  |
| `dressers2.iff` |  |  | STR# 129, 130, 256, 257; TTAs 129 |  |
| `dropdest.iff` |  |  | STR# 256, 257; TTAs 128 |  |
| `duck.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 256, 257, 300; TTAs 129; rsmp 0 |  |
| `easel.iff` |  | TRCN 4097 | STR# 129, 130, 256, 257, 301, 304; TTAs 129; rsmp 0 |  |
| `elevatorfreight.iff` |  | TRCN 4098 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `elevatorhotel.iff` |  | TRCN 4098 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `elevatormodern.iff` |  | TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `elevatorteleporter.iff` |  | TRCN 4098 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `execchair.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `exercisemachine.iff` |  |  | STR# 129, 130, 256, 257, 301; TTAs 129 |  |
| `fencecarnival.iff` |  | BCON 4097, 4098, 4099; TRCN 4097, 4098, 4099 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `fenceflowersnow.iff` |  |  | STR# 129, 130, 256, 257, 303 |  |
| `fenceoffice.iff` |  | BCON 4099; TRCN 4096, 4097, 4099, 4100 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `fenceparty.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `fences.iff` |  | TRCN 4096, 4097, 4098, 4100 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `fenceshd.iff` |  |  | STR# 129, 130, 256, 257, 300, 303, 304 |  |
| `fencesstonevacation.iff` |  | BCON 4098; TRCN 4098 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `fencesunleashed.iff` |  | BCON 4097, 4098, 4099; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | rsmp 0 |  |
| `fetchtester.iff` |  | BCON 4098, 4099; TRCN 4096, 4097, 4098, 4099 | rsmp 0 |  |
| `filingcabinet.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `fire.iff` |  | BCON 4096, 4097, 4098, 4099; TRCN 4096, 4097, 4098, 4099 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `fireplaces.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `fireplaces2.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 256, 257; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `fishingpier.iff` |  | BCON 4096, 4097, 4100; TRCN 4096, 4097, 4100 | STR# 129, 130, 256, 301, 303, 304; TTAs 132; rsmp 0 |  |
| `fishtankbig.iff` |  | TRCN 4096 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `flamingo.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 130, 257, 3; TTAs 131; rsmp 0 |  |
| `flies.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `flood.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257, 301, 304; TTAs 129; rsmp 0 |  |
| `flowerscoped.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 301, 303, 304; TTAs 129, 130, 131, 132, 133; rsmp 0 |  |
| `flowersoutdoor.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | CTSS 2001, 2002; STR# 129, 130, 256, 257, 301, 303, 304; TTAs 129, 130, 131, 132, 133; rsmp 0 |  |
| `flowersunleashed.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `food.iff` | BHAV 4161; TPRP 4161 |  | BHAV 4097, 4109, 4116, 4124, 4132, 4133, 4136, 4170, 4183; OBJf 16807, 16808, 16809, 16810, 16811, 16814, 16815, 16816, 16817; STR# 129, 130, 256, 257, 258, 301, 302, 303, 304, 402; TPRP 4097, 4116, 4124, 4136, 4183; TTAs 128, 129, 130, 131, 132, 133, 134, 135, 136, 137; rsmp 0 |  |
| `foodcounter.iff` |  | TRCN 4097 | BHAV 4105, 4109, 4122, 4125, 4147; STR# 129, 130, 256, 257, 301, 302, 303, 304; TPRP 4122; TTAs 128, 129, 130, 131; rsmp 0 |  |
| `foodcounterunleashed.iff` |  | BCON 4096, 4097, 4099, 4101; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | BHAV 4109; TPRP 4109; rsmp 0 |  |
| `foodproc.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 300, 303; TTAs 128; rsmp 0 |  |
| `foodunleashed.iff` |  | BCON 4099, 4101, 4102, 4103, 4104; TRCN 4099, 4101, 4102, 4103, 4104 | rsmp 0 |  |
| `founders.iff` | whole entry |  |  |  |
| `fountain.iff` |  | TRCN 4096, 4097 | OBJD 16807; STR# 129, 130, 256; TTAs 129; rsmp 0 | a82ca08e |
| `fountainlargehd.iff` |  | BCON 4096, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256; TTAs 129; rsmp 0 |  |
| `fountainrock.iff` |  | TRCN 4097 | STR# 129, 130, 256; TTAs 129; rsmp 0 |  |
| `fountainsunleashed.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `fridges.iff` |  |  | CTSS 2000; OBJD 16807; STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 128, 129, 130; rsmp 0 | 675c18af |
| `fridges2.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 128, 129, 130; rsmp 0 |  |
| `frontdesks.iff` |  | BCON 4096, 4097; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `gameball.iff` |  |  | STR# 129, 256, 257, 301, 303, 304; TTAs 129 |  |
| `gamecompdrawacard.iff` | BHAV 4108; TPRP 4108 | BCON 4097; TRCN 4096, 4097 | BHAV 4104; STR# 129, 256, 257, 301, 302, 304; TTAB 129; TTAs 129, 130; rsmp 0 |  |
| `gamecomponentballcontainer.iff` |  | BCON 4096; TRCN 4096 | BHAV 4102; STR# 129, 257, 301, 302, 303; TTAs 129; rsmp 0 |  |
| `gamecomponentballtarget.iff` |  | BCON 4096; TRCN 4096, 4097 | BHAV 4101; STR# 256, 257, 302; TTAs 129; rsmp 0 |  |
| `gamecomponentpiece.iff` |  | BCON 4096; TRCN 4096 | STR# 256, 257, 301; TTAs 129; rsmp 0 |  |
| `gamecomponentpiececontainer.iff` |  | BCON 4097; TRCN 4097 | STR# 257, 301, 303; TTAs 129; rsmp 0 |  |
| `gamecomponentscoreboard.iff` |  |  | STR# 129, 256, 257, 304; TTAs 129 |  |
| `gamerugarrow.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `gamerugbackred.iff` |  | BCON 4096; TRCN 4096 | STR# 130, 256, 257; TTAs 129; rsmp 0 |  |
| `gamerugbackwhite.iff` |  | BCON 4096; TRCN 4096 | STR# 130, 256, 257; TTAs 129; rsmp 0 |  |
| `gamerugstar.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `gardencrops.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `gardener.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 200, 256, 257, 301, 303, 304; TTAs 129; rsmp 0 |  |
| `gardengnome.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `gardenpest.iff` |  | BCON 4096; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | rsmp 0 |  |
| `gardenplot.iff` |  | BCON 4096, 4100; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | rsmp 0 |  |
| `geniegoldpile.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 302, 304; TTAs 129; rsmp 0 |  |
| `ggworkbench.iff` |  | TRCN 4096, 4098 | BHAV 4110; CTSS 2000; OBJD 16811; STR# 129, 256, 257, 300, 301, 304, 305; TTAs 129; rsmp 0 | 4ddf498c |
| `giftflowers.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 131, 132, 256, 257, 258, 304; TTAs 129; rsmp 0 |  |
| `grandclock.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `grimreaperdbd.iff` |  |  | STR# 129, 130, 200, 256, 257, 304; TTAs 129 |  |
| `guitar.iff` | BHAV 4123; TPRP 4123 |  | BHAV 4096, 4111; OBJf 16807; STR# 129, 130, 131, 132, 256, 301, 304; TPRP 4096, 4111; TTAs 129; rsmp 0 |  |
| `hatrack.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 256, 257, 304; TTAs 129, 130; rsmp 0 |  |
| `helpsystem.iff` |  | BCON 4097; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103 | STR# 129, 130, 256, 258, 259, 300, 301, 303; TTAs 129; rsmp 0 |  |
| `hottub.iff` |  | TRCN 4096, 4097 | BHAV 4098; STR# 129, 130, 256, 257, 301, 302, 304; TTAs 129; rsmp 0 |  |
| `hottubvacation.iff` |  | BCON 4098, 4102, 4103, 4104, 4105, 4106, 4108, 4109, 4110; TRCN 4098, 4102, 4103, 4104, 4105, 4106, 4108, 4109, 4110 | STR# 129, 130, 256, 257, 301, 302, 304; TTAs 129; rsmp 0 |  |
| `icecream.iff` |  | BCON 4099, 4104; TRCN 4099, 4101, 4102, 4103, 4104 | STR# 129, 130, 256, 257, 258, 301, 302, 303, 304, 402; TTAs 128, 129, 130, 131, 132, 133, 134, 135, 136, 137; rsmp 0 |  |
| `jackolantern.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 131, 132, 256, 257, 301, 304; TTAs 128; rsmp 0 |  |
| `jobdegrade.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 130, 131, 132, 256, 257, 301, 303, 304, 305; rsmp 0 |  |
| `jobfinder.iff` |  |  | STR# 129, 256, 257 |  |
| `jobobjband.iff` | BCON 4102, 4103; BHAV 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122; STR# 304; TPRP 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122; TRCN 4102, 4103 | BHAV 4124, 4125; TPRP 4124, 4125 | BCON 4101; BHAV 4096, 4099, 4101, 4102, 4103, 4104, 4105, 4107; OBJD 16811, 16813, 16814, 16817, 16818, 16819, 16822, 16823; STR# 129, 130, 256, 257, 301, 302, 4096, 4097, 4098, 4099; TPRP 4102, 4103, 4105, 4107; TRCN 4101; TTAB 129; TTAs 129, 130, 131, 132; rsmp 0 | ba378b65, fd57c400, 5b1294f4, 7f958de5, 374c95d9, 9f01de7b, 7df2dd66, 7a6aa560 |
| `jobobject2person.iff` |  | BCON 4096; TRCN 4096, 4097, 4098 | BHAV 4102, 4121, 4128; OBJD 16807; STR# 129, 130, 256, 257, 301, 302, 303, 304; TTAs 129; rsmp 0 | 6a245660 |
| `jobpaperchase.iff` |  | TRCN 4096, 4098 | OBJD 16807; STR# 129, 256, 257, 301, 304, 4096, 4097, 4098; TTAs 129, 130, 131, 132; rsmp 0 | 52817ee1 |
| `jukebox.iff` |  | BCON 4097, 4100, 4101; TRCN 4097, 4100, 4101 | STR# 129, 130, 256, 257, 258, 303; TTAs 131; rsmp 0 |  |
| `koiboat.iff` |  |  | STR# 129, 256, 257, 300; TTAs 129 |  |
| `koipond.iff` |  |  | STR# 129, 130, 256, 304; TTAs 129 |  |
| `lampceiling2.iff` |  | BCON 4096; TRCN 4096 | STR# 256; rsmp 0 |  |
| `lampceiling3.iff` |  | BCON 4096; TRCN 4096 | STR# 256; rsmp 0 |  |
| `lampceilingunleashed.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `lampfloorstage.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `lampgarden.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256; TTAs 129; rsmp 0 |  |
| `lampgarden2.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256; TTAs 129; rsmp 0 |  |
| `lamphula.iff` |  | TRCN 4096 | STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `lamps.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 |  |
| `lamps2.iff` |  | BCON 4097; TRCN 4096, 4097 | CTSS 2001; OBJD 16809; STR# 129, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 | 94f5cda8 |
| `lamps3.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 |  |
| `lamps4.iff` |  | BCON 4097; TRCN 4097 | STR# 256, 257; rsmp 0 |  |
| `lampsflooranimated.iff` |  | BCON 4097; TRCN 4096, 4097 | CTSS 2001; OBJD 16808; STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 | da746262 |
| `lampsflooranimated2.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 |  |
| `lampsstreet.iff` |  |  | STR# 129, 256 |  |
| `lampsstreet22.iff` |  | BCON 4096; TRCN 4096 | STR# 256; rsmp 0 |  |
| `lampsunleashed.iff` |  | BCON 4097; TRCN 4096, 4097 | rsmp 0 |  |
| `lampswall2.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 |  |
| `lampswall3.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 |  |
| `lampswall4.iff` |  | BCON 4097; TRCN 4097 | STR# 256, 257; rsmp 0 |  |
| `lampswallgameshow.iff` |  | BCON 4097; TRCN 4096, 4097 | CTSS 2000; OBJD 16811; STR# 129, 256, 257; TTAs 129; rsmp 0 | 2a296a67 |
| `lampunleashedcandle.iff` |  | BCON 4097; TRCN 4097 | rsmp 0 |  |
| `lampwallapplausesign.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `lampwallmoroccan.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `lampwallonairsign.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `lampwallvictorian.iff` |  | BCON 4097; TRCN 4096, 4097 | rsmp 0 |  |
| `leavelot.iff` |  |  | STR# 129, 130, 256, 257, 301, 302, 303, 304; TTAs 129 |  |
| `lotexit.iff` |  |  | STR# 129, 130, 256, 257, 258, 301, 302, 303; TTAs 129, 130, 132 |  |
| `lovetubhd.iff` |  | BCON 4098, 4102, 4103, 4104, 4105, 4106, 4108, 4109, 4110; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110 | STR# 129, 130, 256, 257, 301, 302, 304; TTAs 129; rsmp 0 |  |
| `magazine_inv1.iff` |  | TRCN 4097 | STR# 129, 301, 302, 303, 304; TTAs 129; rsmp 0 |  |
| `magazine_inv2.iff` |  | TRCN 4097 | STR# 129, 301, 302, 303, 304; TTAs 129; rsmp 0 |  |
| `magazine_inv3.iff` |  | TRCN 4097 | STR# 129, 301, 302, 303, 304; TTAs 129; rsmp 0 |  |
| `magazine_inv4.iff` |  | TRCN 4097 | STR# 129, 301, 302, 303, 304; TTAs 129; rsmp 0 |  |
| `magazine_inv5.iff` |  | TRCN 4097 | STR# 129, 301, 302, 303, 304; TTAs 129; rsmp 0 |  |
| `magazinestack.iff` |  |  | STR# 129, 130, 256, 301, 302, 303, 304; TTAs 129 |  |
| `magazinestand.iff` |  | TRCN 4096, 4097, 4098, 4099 | STR# 129, 256, 257, 300, 302, 303; TTAs 128; rsmp 0 |  |
| `magicalendtableunleashed.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `maid.iff` |  | BCON 4096; TRCN 4096 | STR# 200, 256, 257, 301, 303; TTAs 129; rsmp 0 |  |
| `mailbox.iff` | OBJf 16808 | BCON 4096; TRCN 4096 | BHAV 4096, 4097, 4098, 4101, 4109, 4110; OBJD 16808; STR# 129, 130, 256, 257, 258, 301, 303, 304; TPRP 4096, 4098, 4109, 4110; TTAs 129; rsmp 0 | ef121974 |
| `mailboxvacation.iff` |  | BCON 4097, 4098, 4099; TRCN 4096, 4097, 4098, 4099 | rsmp 0 |  |
| `mask.iff` |  | BCON 4097; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | rsmp 0 |  |
| `mechanicalbull.iff` |  |  | BHAV 4105; STR# 129, 130, 131, 132, 256, 257, 301, 304; TPRP 4105; TTAs 129; rsmp 0 |  |
| `medicinecabinet.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 131, 132, 256, 257, 301, 303, 304; TTAs 129; rsmp 0 |  |
| `menorah.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 |  |
| `mice.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `microphone.iff` | BHAV 4100, 4102, 4103, 4104, 4105, 4107, 4108, 4109; TPRP 4100, 4102, 4103, 4104, 4105, 4107, 4108, 4109 | BCON 4097; TRCN 4096, 4097, 4098 | BHAV 4098, 4099; OBJD 16807; STR# 129, 130, 256, 257, 303; TPRP 4099; TTAB 129; TTAs 129; rsmp 0 | ff15db89 |
| `microphonepodiumgameshow.iff` | BHAV 4100, 4102, 4103, 4104, 4105, 4107, 4108, 4109; TPRP 4100, 4102, 4103, 4104, 4105, 4107, 4108, 4109 | BCON 4097; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 303; TTAB 129; TTAs 129; rsmp 0 |  |
| `microphonepulpit.iff` | BHAV 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109; TPRP 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109 | BCON 4097; TRCN 4096, 4097, 4098 | BHAV 4098; STR# 129, 130, 256, 257, 303; TTAB 129; TTAs 129; rsmp 0 |  |
| `mirrorfloorvacation.iff` |  | TRCN 4096 | STR# 129, 130, 131, 132, 256, 257, 301; TTAs 129, 130; rsmp 0 |  |
| `mirrors.iff` |  |  | STR# 129, 130, 131, 132, 256, 257, 301; TTAs 129, 130 |  |
| `mirrors2.iff` |  | TRCN 4096 | STR# 129, 130, 131, 132, 256, 257, 301; TTAs 129, 130; rsmp 0 |  |
| `mirrors3.iff` |  | TRCN 4096 | STR# 129, 130, 131, 132, 256, 257, 301; TTAs 129; rsmp 0 |  |
| `mirrorvacation.iff` |  | TRCN 4096 | STR# 129, 130, 131, 132, 256, 257, 301; TTAs 129, 130; rsmp 0 |  |
| `moosehead.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256; TTAs 130; rsmp 0 |  |
| `neighborhoodpedmarker.iff` |  | BCON 4096, 4098; TRCN 4096, 4098 | rsmp 0 |  |
| `neighborhoodphoneplugin.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103 | rsmp 0 |  |
| `newspaper.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 258, 301, 304; TTAs 129; rsmp 0 |  |
| `newyears.iff` | whole entry |  |  |  |
| `npc_cartvendorfl.iff` |  |  | STR# 129, 200, 256, 257, 300, 304 |  |
| `npc_cartvendorfl_drk.iff` |  |  | STR# 129, 200, 256, 257, 300, 304 |  |
| `npc_cartvendorfl_med.iff` |  |  | STR# 129, 200, 256, 257, 300, 304 |  |
| `npc_icecreamvendor.iff` |  |  | STR# 129, 200, 256, 257, 300, 304 |  |
| `npc_icv_dark.iff` |  |  | STR# 129, 200, 256, 257, 300, 304 |  |
| `npc_icv_med.iff` |  |  | STR# 129, 200, 256, 257, 300, 304 |  |
| `npc_unleashed_animalcontrolpp.iff` |  | BCON 4097; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103 | rsmp 0 |  |
| `npc_unleashed_controller.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `npc_unleashed_maintenance.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `npc_unleashed_organgrinder.iff` |  | BCON 4096, 4097, 4099; TRCN 4096, 4097, 4099 | rsmp 0 |  |
| `npc_unleashed_palmreader.iff` |  | BCON 4096, 4099; TRCN 4096, 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `npc_unleashed_raccoon.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `npc_unleashed_saxplayer.iff` |  | BCON 4096, 4097, 4099; TRCN 4096, 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `npc_unleashed_skunk.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `npccontroller.iff` |  |  | STR# 129, 130, 131, 132, 256, 257, 301, 303, 304, 305 |  |
| `npcdealer.iff` |  | TRCN 4096 | STR# 200, 256, 257, 258, 303; TTAs 129; rsmp 0 |  |
| `npcrobotsi.iff` |  | BCON 4101, 4102, 4112, 4113, 4116, 4117; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122 | STR# 129, 130, 131, 132, 256, 257, 258, 301, 303, 304, 305; TTAs 129; rsmp 0 |  |
| `npcsocials.iff` |  | BCON 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122; TRCN 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122 | rsmp 0 |  |
| `officechair.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257; TTAs 128, 129, 130, 131, 132, 133; rsmp 0 |  |
| `officecubicle.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | STR# 129, 257, 303; rsmp 0 |  |
| `officeplant.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 304, 4096; TTAs 129, 130, 131, 132, 133, 134; rsmp 0 |  |
| `officer.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 200, 256, 257, 301, 303, 304; TTAs 129; rsmp 0 |  |
| `paintings.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256; TTAs 130; rsmp 0 |  |
| `paintings2.iff` |  | BCON 4096; TRCN 4096 | CTSS 2002; OBJD 16811; STR# 129, 130, 256; TTAs 130; rsmp 0 | a13f39cf |
| `paintings3.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 301; TTAs 130; rsmp 0 |  |
| `paintings4.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 301; TTAs 130; rsmp 0 |  |
| `paintings5.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 301; TTAs 130; rsmp 0 |  |
| `paintings6.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 301; TTAs 130; rsmp 0 |  |
| `paintings7.iff` |  | BCON 4097; TRCN 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `pantryunleashed.iff` |  | BCON 4096, 4097, 4098, 4099; TRCN 4096, 4097, 4098, 4099 | rsmp 0 |  |
| `papercarrierf1.iff` |  |  | STR# 130, 200, 256, 257, 301, 303, 304 |  |
| `parkgrill.iff` |  | BCON 4100, 4101; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | STR# 129, 256, 257, 301, 303, 304; TTAs 129; rsmp 0 |  |
| `parkrockers.iff` |  | BCON 4100; TRCN 4096, 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `partyballoons.iff` |  | BCON 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `pedportal.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 256, 257, 258, 301, 303, 304, 305; TTAs 129; rsmp 0 |  |
| `pet_inventory_fish.iff` |  | TRCN 4097 | rsmp 0 |  |
| `pet_inventory_iguana.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `pet_inventory_lovebirds.iff` |  | TRCN 4097 | rsmp 0 |  |
| `pet_inventory_parakeet.iff` |  | TRCN 4097 | rsmp 0 |  |
| `pet_inventory_turtle.iff` |  | TRCN 4097 | rsmp 0 |  |
| `petbath.iff` |  | BCON 4096; TRCN 4096, 4097 | rsmp 0 |  |
| `petbed.iff` |  | BCON 4096, 4098; TRCN 4096, 4097, 4098, 4099 | rsmp 0 |  |
| `petbirdcage.iff` |  | BCON 4098, 4099; TRCN 4098, 4099 | rsmp 0 |  |
| `petcatlitterbox.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | rsmp 0 |  |
| `petcatsit.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `petdogsit.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `petfishbowl.iff` |  | BCON 4098, 4099; TRCN 4096, 4097, 4098, 4099 | rsmp 0 |  |
| `petfoodbowl.iff` |  | BCON 4096; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `petgym.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `pethouse.iff` |  | BCON 4096, 4098; TRCN 4096, 4098 | rsmp 0 |  |
| `petiguana.iff` |  | BCON 4098, 4099; TRCN 4096, 4097, 4098, 4099 | rsmp 0 |  |
| `petmaternitybox.iff` |  | BCON 4097; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `petparrot.iff` |  | BCON 4097, 4099; TRCN 4097, 4099 | rsmp 0 |  |
| `petpedestal.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `petplayfountain.iff` |  | BCON 4098; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | rsmp 0 |  |
| `petpost.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `petturtle.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | rsmp 0 |  |
| `phoneline.iff` |  |  | STR# 256, 257, 258, 303 |  |
| `piano.iff` | BHAV 4112; TPRP 4112 | TRCN 4097 | OBJf 16810; STR# 129, 130, 131, 132, 256, 257, 301; TTAs 129; rsmp 0 |  |
| `piano2.iff` | BHAV 4120; TPRP 4120 | TRCN 4097 | OBJf 16810; STR# 129, 130, 131, 132, 256, 257, 301; TTAs 129; rsmp 0 |  |
| `piano3.iff` | BHAV 4124; TPRP 4099, 4124 | TRCN 4097 | BHAV 4096, 4099, 4102, 4105, 4107, 4119; OBJf 16810; STR# 129, 130, 131, 132, 256, 257, 301, 303; TPRP 4096, 4102, 4105, 4107, 4119; TTAs 129; rsmp 0 |  |
| `pinata.iff` |  | TRCN 4096, 4098 | STR# 128, 129, 256, 257, 301, 304; TTAs 129; rsmp 0 |  |
| `pinballmachine.iff` |  | TRCN 4097 | STR# 129, 256, 257, 301, 302, 303, 304; TTAs 128; rsmp 0 |  |
| `pizzamaker.iff` |  | TRCN 4096, 4097, 4098, 4099, 4102, 4103, 4104, 4105, 4106, 4107, 4108 | OBJD 16807; STR# 129, 256, 257, 301, 304; TTAs 129; rsmp 0 | 1d8a0c11 |
| `placeholder.iff` |  |  | STR# 257 |  |
| `plantboxfence.iff` |  | BCON 4098; TRCN 4098 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `plantboxfenceunleashed.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102 | rsmp 0 |  |
| `plantflowersurn.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 304, 4096; TTAs 129; rsmp 0 |  |
| `plantmoroccan.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 304, 4096; TTAs 129; rsmp 0 |  |
| `plantpottedalien.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 304, 4096; TTAs 129; rsmp 0 |  |
| `plants.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 304, 4096; TTAs 129, 130, 131, 132, 133, 134; rsmp 0 |  |
| `plants2.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 304, 4096; TTAs 129, 130, 131, 132, 133, 134; rsmp 0 |  |
| `plants3.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 304, 4096; TTAs 129; rsmp 0 |  |
| `plantshanginghd.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256; TTAs 129; rsmp 0 |  |
| `podium.iff` | BHAV 4100, 4102, 4103, 4104, 4105, 4107, 4108, 4109; TPRP 4100, 4102, 4103, 4104, 4105, 4107, 4108, 4109 | BCON 4097; TRCN 4097, 4098 | BHAV 4098, 4099; OBJD 16807; STR# 129, 130, 256, 257, 303; TPRP 4099; TTAB 129; TTAs 129; rsmp 0 | 83d9387d |
| `pondduck.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 256, 257, 300; TTAs 129; rsmp 0 |  |
| `pool.iff` |  |  | STR# 129, 256, 301, 303, 304; TTAs 130 |  |
| `pooldivbrd.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257, 303; TTAs 129, 130; rsmp 0 |  |
| `poolfilter.iff` |  |  | STR# 129, 257; TTAs 129 |  |
| `poolladder.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257, 302, 303; TTAs 130, 131; rsmp 0 |  |
| `poolslide.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 303; TTAs 129, 130; rsmp 0 |  |
| `pooltable.iff` | BHAV 4139; TPRP 4139 | TRCN 4096, 4097, 4098 | BHAV 4130, 4132, 4149; STR# 129, 130, 256, 257, 258, 303, 304; TPRP 4149; TTAs 129; rsmp 0 |  |
| `poop.iff` |  | BCON 4098, 4099; TRCN 4098, 4099 | rsmp 0 |  |
| `porchswinghd.iff` |  |  | STR# 129, 130, 256, 257, 301, 302, 304; TTAs 129, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142 |  |
| `property_deeds.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130; rsmp 0 |  |
| `punchbowl.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 258, 301, 303, 304; TTAs 128, 129; rsmp 0 |  |
| `puppetangry.iff` |  | TRCN 4096, 4097 | STR# 129, 304; TTAs 129; rsmp 0 |  |
| `puppetattitude.iff` |  | TRCN 4097 | STR# 129, 256, 304; TTAs 129; rsmp 0 |  |
| `puppetbonus.iff` |  | TRCN 4096, 4097 | STR# 129, 304; TTAs 129; rsmp 0 |  |
| `puppetbored.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 304; TTAs 129; rsmp 0 |  |
| `puppetcool.iff` |  | TRCN 4096, 4097 | STR# 129, 304; TTAs 129; rsmp 0 |  |
| `puppetdance.iff` |  | TRCN 4096, 4097 | STR# 129, 130; TTAs 129; rsmp 0 |  |
| `puppetdisgusted.iff` |  | TRCN 4096, 4097 | STR# 129; TTAs 129; rsmp 0 |  |
| `puppethappy.iff` |  | TRCN 4096, 4097 | STR# 129, 130; TTAs 129; rsmp 0 |  |
| `puppetsad.iff` |  | TRCN 4096, 4097 | STR# 129; TTAs 129; rsmp 0 |  |
| `puppetsilly.iff` |  | TRCN 4096, 4097 | STR# 129; TTAB 129; TTAs 129; rsmp 0 |  |
| `queueropes.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `reclinerdoublevacation.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257; TTAs 128; rsmp 0 |  |
| `recliners.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257; TTAs 128, 129; rsmp 0 |  |
| `repairman.iff` |  | BCON 4096; TRCN 4096 | STR# 200, 256, 257, 258, 301, 303; TTAs 129; rsmp 0 |  |
| `repoman.iff` |  |  | STR# 200, 256, 257, 301, 304 |  |
| `repomanfx.iff` |  | TRCN 4096, 4097, 4098, 4099 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `reservetile.iff` |  |  | STR# 257 |  |
| `roaches.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `roulette.iff` |  | TRCN 4097, 4098 | STR# 129, 256, 257, 301, 302, 303, 4096; TTAs 129; rsmp 0 |  |
| `rugmoroccanrunner.iff` |  | BCON 4096; TRCN 4096 | STR# 130, 256, 257; TTAs 129; rsmp 0 |  |
| `rugmoroccansquare.iff` |  | BCON 4096; TRCN 4096 | STR# 130, 256, 257; TTAs 129; rsmp 0 |  |
| `rugs.iff` |  | BCON 4096; TRCN 4096 | STR# 130, 256, 257; TTAs 129; rsmp 0 |  |
| `rugs2.iff` |  | BCON 4096; TRCN 4096 | STR# 130, 256, 257; TTAs 129; rsmp 0 |  |
| `rugs3.iff` |  | BCON 4096; TRCN 4096 | TTAs 129; rsmp 0 |  |
| `scheduler.iff` |  |  | STR# 256, 303 |  |
| `sculpturedressingscreen.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `sculpturegopher.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `sculptures.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `sculptures2.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `sculptures3.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `sculptures4.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130; rsmp 0 |  |
| `sculptures5.iff` |  | TRCN 4096 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `sculptures6.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `sculptures7.iff` |  | BCON 4097; TRCN 4097 | rsmp 0 |  |
| `sculptureweddingtopiary.iff` |  | TRCN 4096 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `seeds.iff` |  | TRCN 4097 | rsmp 0 |  |
| `showeraluminum.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 131, 132, 256, 300, 301, 304; TTAs 129; rsmp 0 |  |
| `showerc.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 131, 132, 256, 300, 301, 304; TTAs 129; rsmp 0 |  |
| `showers2.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 131, 132, 256, 300, 301, 304; TTAs 129; rsmp 0 |  |
| `showertiki.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 131, 132, 256, 300, 301, 304; TTAs 129; rsmp 0 |  |
| `showertub.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `showertubunleashed.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 301; rsmp 0 |  |
| `shutters.iff` |  | TRCN 4096 | STR# 129, 301; TTAs 130; rsmp 0 |  |
| `signs.iff` |  |  | BHAV 4106, 4109; STR# 129, 256, 257, 301, 303, 304; TTAs 129; rsmp 0 |  |
| `sinkaluminum.iff` |  | BCON 4096, 4098, 4099; TRCN 4096, 4097, 4098, 4099 | STR# 129, 256, 257, 303, 304; TTAs 128, 129, 130; rsmp 0 |  |
| `sinks.iff` |  | BCON 4096, 4098, 4099; TRCN 4096, 4098, 4099 | STR# 129, 130, 256, 257, 303, 304; TTAs 128, 129, 130; rsmp 0 |  |
| `sinks2.iff` |  | BCON 4096, 4098, 4099; TRCN 4096, 4097, 4098, 4099 | STR# 129, 130, 256, 257, 303, 304; TTAs 128, 129, 130; rsmp 0 |  |
| `sinks3.iff` |  |  | STR# 129, 130, 256, 257, 303, 304; TTAs 128, 129, 130 |  |
| `sinkvacation.iff` |  | BCON 4096, 4098, 4099; TRCN 4096, 4097, 4098, 4099 | STR# 129, 130, 256, 257, 303, 304; TTAs 128; rsmp 0 |  |
| `skilltracker.iff` |  |  | STR# 256, 257, 304; TTAs 129 |  |
| `slotmachine.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 131, 132, 256, 257, 258, 302, 304; TTAs 129; rsmp 0 |  |
| `snackmachine.iff` |  | BCON 4096, 4097, 4099; TRCN 4096, 4097, 4098, 4099 | STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 128, 129, 130; rsmp 0 |  |
| `snowman.iff` |  | BCON 4097, 4099, 4103; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103 | STR# 257; rsmp 0 |  |
| `soccerball.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 256, 257, 300; TTAs 129; rsmp 0 |  |
| `soccernet.iff` |  | BCON 4097; TRCN 4097 | STR# 256; TTAs 129; rsmp 0 |  |
| `social2.iff` |  |  | STR# 129, 130, 256, 257, 258, 301, 303, 304, 305; TTAs 129, 130, 131 |  |
| `social2siminteractions.iff` | BHAV 4411, 4412, 4413, 4414; TPRP 4411, 4412, 4413, 4414 | TRCN 4096, 4097, 4098, 4099, 4100, 4104, 4105, 4107, 4111, 4118, 4123, 4155, 4156, 4157, 4158, 4160, 4161, 4162, 4163, 4164 | BHAV 4147, 4210, 4275, 4278, 4308, 4309, 4358, 4401, 4402; STR# 129, 130, 131, 132, 256, 257, 258, 301, 303, 304, 305, 401; TPRP 4147, 4275, 4278; TTAB 130; TTAs 129, 130; rsmp 0 |  |
| `socialapprove.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 130, 131, 132, 256; TTAs 129; rsmp 0 |  |
| `socialgreet.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 256; TTAs 129; rsmp 0 |  |
| `socialinteractions.iff` |  | BCON 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122, 4123; TRCN 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122, 4123 | STR# 129, 130, 131, 132, 256, 257, 258, 301, 303, 304, 305, 401; TTAs 129; rsmp 0 |  |
| `socialmean.iff` |  | TRCN 4097 | STR# 129, 256; TTAs 129; rsmp 0 |  |
| `socialnice.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 256, 301; TTAs 129; rsmp 0 |  |
| `socialplay.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 256, 304; TTAs 129; rsmp 0 |  |
| `socialreject.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 130, 131, 132, 256; TTAs 129; rsmp 0 |  |
| `socialromance.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 129, 256; TTAs 129; rsmp 0 |  |
| `sodamachine2.iff` |  | BCON 4096; TRCN 4096, 4097, 4098, 4099 | BHAV 4112; STR# 129, 130, 256, 257, 300, 301, 302, 303, 304; TTAs 128, 129, 130; rsmp 0 |  |
| `sofabenchvacation.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | STR# 129, 130, 256, 257, 301, 302; TTAs 129, 130, 131; rsmp 0 |  |
| `sofacuddleinteractions.iff` | BHAV 4115, 4116, 4117, 4118; TPRP 4115, 4116, 4117, 4118 | BCON 4096; TRCN 4096, 4097 | BHAV 4096, 4097, 4098, 4099, 4100, 4102, 4103, 4104, 4105, 4106, 4107; STR# 129, 256, 401; TTAs 129; rsmp 0 |  |
| `sofas.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 302; TTAs 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142; rsmp 0 |  |
| `sofas2.iff` |  |  | STR# 129, 130, 256, 257, 302; TTAs 129, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142 |  |
| `sofas3.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 302; TTAs 129, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142; rsmp 0 |  |
| `sofas4.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 302; TTAs 129, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142; rsmp 0 |  |
| `sofas5.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 256, 257, 302; TTAs 129, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142; rsmp 0 |  |
| `sofashd.iff` |  | TRCN 4101 | STR# 129, 130, 256, 257, 302; TTAs 129, 130, 131; rsmp 0 |  |
| `sofaslodge.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | STR# 129, 130, 256, 257, 301, 302; TTAs 129, 130, 131; rsmp 0 |  |
| `sofasunleashed.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `sofaweddingpew.iff` |  | BCON 4096, 4097, 4098, 4099, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 302; TTAs 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142; rsmp 0 |  |
| `souvenircabinets.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | STR# 257; rsmp 0 |  |
| `spinbottle.iff` |  |  | STR# 129, 256, 257, 401; TTAs 129 |  |
| `splitrailfence.iff` |  | BCON 4099; TRCN 4099, 4100 | STR# 129, 130, 256, 257, 300, 303, 304; rsmp 0 |  |
| `stair.iff` |  |  | STR# 129, 130, 256, 257, 302, 400; TTAs 129 |  |
| `stair2.iff` |  | TRCN 4096 | STR# 129, 130, 256, 257, 302, 400; TTAs 129; rsmp 0 |  |
| `stair3.iff` |  |  | STR# 129, 130, 256, 257, 302, 400; TTAs 129 |  |
| `stair4.iff` |  | TRCN 4096 | STR# 129, 130, 256, 257, 302, 400; rsmp 0 |  |
| `stairsspiral.iff` |  | TRCN 4096 | rsmp 0 |  |
| `stereos.iff` |  | BCON 4097, 4100, 4101; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | BHAV 4120; STR# 129, 130, 256, 257, 258, 303; TTAs 129, 130, 131; rsmp 0 |  |
| `stereos2.iff` |  | BCON 4097; TRCN 4097, 4098, 4099, 4100, 4101 | STR# 129, 256, 303, 304; TTAs 129; rsmp 0 |  |
| `stereospeakers.iff` |  | BCON 4100, 4102, 4103; TRCN 4100, 4102, 4103 | STR# 129, 130, 131, 132, 256, 257, 258, 303, 304; TTAs 131; rsmp 0 |  |
| `stereowallunleashed.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100 | rsmp 0 |  |
| `stopsign.iff` |  | BCON 4096; TRCN 4096, 4097 | STR# 303; TTAs 132; rsmp 0 |  |
| `stoves.iff` |  | BCON 4097, 4098, 4100, 4101; TRCN 4097, 4098, 4100, 4101 | BHAV 4114; STR# 129, 130, 256, 257, 300, 301, 303, 304; TPRP 4114; TTAs 129; rsmp 0 |  |
| `stoves2.iff` |  | BCON 4097, 4098, 4100; TRCN 4096, 4097, 4098, 4099, 4100 | BHAV 4109, 4114, 4131; STR# 129, 130, 256, 257, 300, 301, 303, 304; TPRP 4109, 4114, 4131; TTAs 129; rsmp 0 |  |
| `tablecoffee.iff` |  |  | STR# 129, 256, 257, 303 |  |
| `tablecoffee2.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | STR# 129, 256, 257, 303; rsmp 0 |  |
| `tablecoffeeunleashed.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | rsmp 0 |  |
| `tablediningunleashed.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `tableendwedding.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `tablegiftshop.iff` |  | BCON 4096; TRCN 4096 | OBJD 16836; rsmp 0 | 29b19fbc |
| `tablemoroccan1x1.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4111, 4113, 4117, 4118, 4121; STR# 129, 130, 257, 303; TPRP 4100, 4111, 4113, 4117, 4118, 4121; rsmp 0 |  |
| `tablepicnic.iff` |  |  | BHAV 4100, 4105, 4111, 4113, 4117, 4118; STR# 129, 130, 257, 303; TPRP 4100, 4105, 4111, 4113, 4117, 4118; TTAs 129; rsmp 0 |  |
| `tablepicnic2.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4102, 4111, 4117, 4121; STR# 129, 130, 257, 303; TPRP 4100, 4102, 4111, 4121; TTAs 129; rsmp 0 |  |
| `tablerave.iff` |  | BCON 4096; TRCN 4096 | BHAV 4100, 4102, 4111, 4113, 4117, 4118, 4121; STR# 129, 130, 257, 303; TPRP 4100, 4102, 4111, 4113, 4117, 4118, 4121; rsmp 0 |  |
| `tablesend.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | BHAV 4098, 4100, 4102, 4103, 4104; STR# 129, 130, 256, 257, 303; TPRP 4102, 4103; TTAs 129; rsmp 0 |  |
| `tablesend2.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | BHAV 4098, 4100, 4102, 4103; STR# 129, 130, 256, 257, 303; TPRP 4098, 4100, 4102, 4103; rsmp 0 |  |
| `tablesend4.iff` |  |  | BHAV 4098, 4100, 4103, 4109, 4110, 4112, 4114, 4115; STR# 129, 130, 256, 257, 303; TPRP 4098, 4100, 4103, 4109, 4110, 4112, 4114, 4115; rsmp 0 |  |
| `tablesend5.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | BHAV 4103, 4104, 4109, 4110, 4112, 4115; STR# 129, 130, 256, 257, 303; TPRP 4104, 4109, 4110, 4112, 4115; rsmp 0 |  |
| `tableshd.iff` |  | BCON 4096; TRCN 4096 | BHAV 4097, 4100, 4102, 4111, 4113, 4117, 4118, 4121; STR# 129, 130, 257, 303; TPRP 4097, 4100, 4102, 4111, 4113, 4117, 4118, 4121; rsmp 0 |  |
| `telemarketingstation.iff` |  |  | STR# 129, 130, 256, 257, 301, 303, 304; TTAs 129 |  |
| `teleporter.iff` |  |  | STR# 129, 256, 257, 301, 303, 304; TTAs 129 |  |
| `telescope.iff` |  |  | STR# 129, 130, 256, 301, 304; TTAs 129, 130 |  |
| `templatecat.iff` |  | TRCN 4096 | rsmp 0 |  |
| `templatedog.iff` |  | TRCN 4096 | rsmp 0 |  |
| `templatenpc.iff` |  | TRCN 4096 | STR# 200, 256, 257, 258, 303; TTAs 129; rsmp 0 |  |
| `templateperson.iff` |  |  | OBJD 128; STR# 200, 256, 257, 300, 304 | 7fd96b54 |
| `tent.iff` |  | BCON 4097, 4098, 4099, 4100, 4101, 4102; TRCN 4097, 4098, 4099, 4100, 4101, 4102 | STR# 129, 130, 131, 256, 257, 258, 301, 302, 303; TTAs 132; rsmp 0 |  |
| `timer.iff` |  | BCON 4098; TRCN 4098 | STR# 129, 256, 257, 301; TTAs 129; rsmp 0 |  |
| `tipjar.iff` |  | TRCN 4097 | SLOT 128; STR# 129, 256, 257, 301, 304; TTAs 128; rsmp 0 |  |
| `toiletaluminum.iff` |  | BCON 4097; TRCN 4096, 4097, 4098 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129, 130; rsmp 0 |  |
| `toiletportable.iff` |  | BCON 4097; TRCN 4096, 4097, 4098 | CTSS 2000; OBJD 16807; STR# 129, 130, 256, 257, 304; TTAs 129, 130; rsmp 0 | eac3d84f |
| `toilets.iff` |  | BCON 4097; TRCN 4097, 4098 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129, 130; rsmp 0 |  |
| `toilets2.iff` |  | BCON 4097; TRCN 4097, 4098 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129, 130; rsmp 0 |  |
| `toilets3.iff` |  | BCON 4097; TRCN 4097, 4098 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129, 130; rsmp 0 |  |
| `toiletstall.iff` |  | BCON 4097; TRCN 4096, 4097, 4098 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129, 130; rsmp 0 |  |
| `toiletsunleashed.iff` |  | BCON 4097; TRCN 4097, 4098 | rsmp 0 |  |
| `toileturinal.iff` |  | BCON 4097; TRCN 4096, 4097, 4098 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129, 130; rsmp 0 |  |
| `tokensunleashed.iff` |  | TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110, 4111, 4112 | rsmp 0 |  |
| `toyrocket.iff` |  | BCON 4096; TRCN 4096 | BHAV 4096, 4103, 4104; CTSS 2000; OBJD 16807; STR# 129, 130, 131, 132, 256, 257, 304; TPRP 4096, 4104; TTAs 129; rsmp 0 | 405046ff |
| `tragicclown.iff` |  |  | STR# 129, 130, 131, 132, 200, 256, 257, 301, 304, 305; TTAs 129 |  |
| `trainsets.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129, 130; rsmp 0 |  |
| `trash1.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | CTSS 2000; OBJD 16807; STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 | 83e0af58 |
| `trash2.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `trashcandt.iff` |  |  | STR# 129, 130, 256, 257, 303, 304; TTAs 129 |  |
| `trashcanvacation.iff` |  | BCON 4096, 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `trashcompactor.iff` |  | BCON 4096, 4097, 4098; TRCN 4096, 4097, 4098 | BHAV 4096, 4130; STR# 129, 130, 256, 300, 303, 304; TPRP 4096, 4130; TTAs 128; rsmp 0 |  |
| `trashflower.iff` |  | BCON 4096, 4098, 4099; TRCN 4096, 4098, 4099 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `trashoutside.iff` | BHAV 4097; TPRP 4097 |  | BHAV 4098; STR# 129, 130, 256, 257, 301, 304; rsmp 0 |  |
| `trashpile.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `trclownhole.iff` |  | BCON 4096; TRCN 4096 | STR# 129, 130, 256, 304; TTAs 129; rsmp 0 |  |
| `trclownsi.iff` |  | BCON 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109, 4110, 4111, 4112, 4113, 4114, 4115, 4116, 4117, 4118, 4119, 4120, 4121, 4122 | STR# 129, 130, 131, 132, 256, 257, 258, 301, 303, 304, 305; TTAs 129; rsmp 0 |  |
| `treasurehunt.iff` |  |  | STR# 129, 130, 256, 257, 301, 303, 304; TTAs 129 |  |
| `treecurb.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 256, 257; rsmp 0 |  |
| `trees.iff` |  | TRCN 4096, 4097 | STR# 129, 130, 256, 257; rsmp 0 |  |
| `trees3.iff` |  |  | CTSS 2006; STR# 129, 130, 256, 257; rsmp 0 |  |
| `trees4.iff` |  |  | STR# 129, 256, 257; TTAs 129, 130, 131 |  |
| `treeshd.iff` |  | TRCN 4096, 4097 | STR# 256, 257; rsmp 0 |  |
| `treesunleashed.iff` |  | TRCN 4096, 4097 | rsmp 0 |  |
| `tubc.iff` | BHAV 4133, 4134; OBJf 16808, 16809; TPRP 4133, 4134 | TRCN 4097 | BHAV 4103; OBJD 16807, 16808, 16809; STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129; rsmp 0 | 85e00942, 6145c66d, 93908eb9 |
| `tubcastle.iff` | BHAV 4137; TPRP 4137 | TRCN 4097 | BHAV 4099, 4101, 4103, 4120, 4134; OBJf 16808; STR# 129, 130, 131, 132, 256, 257, 304; TPRP 4099, 4101, 4103, 4120, 4134; TTAs 129; rsmp 0 |  |
| `tubm.iff` | BHAV 4134, 4137; OBJf 16808; TPRP 4134, 4137 | TRCN 4097 | BHAV 4103, 4107; OBJD 16807, 16808; STR# 129, 130, 131, 132, 256, 257, 304; TPRP 4103, 4107; TTAs 129; rsmp 0 | dbeb6614, dbea7e83 |
| `tubx.iff` |  | TRCN 4097 | STR# 129, 130, 131, 132, 256, 257, 304; TTAs 129; rsmp 0 |  |
| `turkey.iff` |  | BCON 4099, 4101, 4102, 4103, 4104, 4105; TRCN 4099, 4101, 4102, 4103, 4104, 4105 | STR# 129, 130, 256, 257, 258, 301, 302, 303, 304, 402; TTAs 128, 129, 130, 131, 132, 133, 134, 135, 136, 137; rsmp 0 |  |
| `turnstiledoor.iff` |  | BCON 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257, 300, 301, 302, 303; TTAs 131; rsmp 0 |  |
| `tutorial.iff` |  |  | STR# 129, 256, 257, 301 |  |
| `tvs.iff` |  |  | STR# 129, 130, 256, 257, 258, 302, 304; TTAs 129, 130, 132 |  |
| `typewriter.iff` |  | TRCN 4097, 4098 | STR# 129, 130, 256, 257, 301, 303; TTAs 129; rsmp 0 |  |
| `unleashedcontroller.iff` |  | BCON 4096, 4101, 4102, 4103, 4104, 4105, 4107, 4108; TRCN 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104, 4105, 4106, 4107, 4108, 4109 | rsmp 0 |  |
| `urnstone.iff` |  | BCON 4097; TRCN 4097 | STR# 129, 130, 131, 132, 256, 257, 301; TTAs 129; rsmp 0 |  |
| `urnstonepet.iff` |  | BCON 4097; TRCN 4096, 4097 | rsmp 0 |  |
| `vacationgrill.iff` |  | BCON 4100, 4101; TRCN 4096, 4097, 4098, 4099, 4100, 4101 | rsmp 0 |  |
| `villagecontrol.iff` |  | BCON 4096, 4098; TRCN 4096, 4097, 4098 | rsmp 0 |  |
| `vrhelmet.iff` |  | BCON 4096; TRCN 4096 | BHAV 4097; STR# 129, 130, 256, 304; TTAB 129; TTAs 129; rsmp 0 |  |
| `walllite.iff` |  | TRCN 4096 | STR# 129, 130, 256, 257; TTAs 129, 130, 131, 132, 133, 134, 135; rsmp 0 |  |
| `wargame.iff` |  |  | STR# 129, 256, 257, 301, 302, 303, 304, 4096, 4097, 4098, 4099; TTAs 129 |  |
| `watercooler.iff` |  | BCON 4097, 4098; TRCN 4097, 4098 | STR# 129, 130, 256, 257, 303; rsmp 0 |  |
| `wedcandelabra.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `weddingarch.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `weddingballoons.iff` |  | BCON 4100; TRCN 4096, 4097, 4098, 4099, 4100 | STR# 129, 130, 256, 257, 303, 304; TTAs 129; rsmp 0 |  |
| `weddingcake.iff` |  |  | STR# 129, 130, 256, 257, 258, 301, 302, 303, 304, 402; TTAs 128, 129, 130, 131, 132, 133, 134, 135, 136, 137 |  |
| `weddingchairfolding.iff` |  | BCON 4097, 4098; TRCN 4096, 4097, 4098 | STR# 129, 130, 256, 257; TTAs 128, 129, 130, 131, 132, 133; rsmp 0 |  |
| `weddingflowers.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 130, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `weddingqueueropes.iff` |  | TRCN 4100 | STR# 129, 300, 303; rsmp 0 |  |
| `weddingrugrunner.iff` |  | TRCN 4096 | STR# 130, 256, 257; TTAs 129; rsmp 0 |  |
| `weddingsign.iff` |  | BCON 4097; TRCN 4096, 4097 | STR# 129, 256, 257; TTAs 129; rsmp 0 |  |
| `weddingtrunk.iff` |  | TRCN 4096, 4097 | STR# 129, 256, 257, 301; TTAs 129, 130, 131, 132; rsmp 0 |  |
| `windows.iff` |  |  | CTSS 2013; rsmp 0 |  |
| `windows2.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `windows3.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `windows4.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `windows5.iff` |  | BCON 4096; TRCN 4096 | CTSS 2001; rsmp 0 |  |
| `windows6.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `windowsbeach.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |
| `windowslodge.iff` |  | BCON 4096; TRCN 4096 | rsmp 0 |  |

### `objectdata/objects/objotf.far`

FAR1, 421249 bytes in `TSO_GAME_DIR`, 419643 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 2, only in `TSO_BETA_DIR`: 0, changed: 24.

### `objectdata/objects/objspf4.far`

FAR1, 52434953 bytes in `TSO_GAME_DIR`, 52513576 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 1, only in `TSO_BETA_DIR`: 1, changed: 0.

### `objectdata/objects/objspf5.far`

FAR1, 52632705 bytes in `TSO_GAME_DIR`, 54257647 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 1, only in `TSO_BETA_DIR`: 1, changed: 0.

### `packingslips/accessorytable.xml`

57915 bytes in `TSO_GAME_DIR`, 57826 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `packingslips/animtable.xml`

536506 bytes in `TSO_GAME_DIR`, 535615 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `packingslips/catalog.xml`

107697 bytes in `TSO_GAME_DIR`, 101011 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `packingslips/objecttable.xml`

183844 bytes in `TSO_GAME_DIR`, 172515 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `packingslips/packingslip.log`

2838001 bytes in `TSO_GAME_DIR`, 2720853 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `packingslips/packingslips.dat`

FAR3, 4984795 bytes in `TSO_GAME_DIR`, 4781652 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 1365, only in `TSO_BETA_DIR`: 0, changed: 4768.

### `packingslips/textable.xml`

482261 bytes in `TSO_GAME_DIR`, 453173 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `properties.txt`

85 bytes in `TSO_GAME_DIR`, 85 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `sounddata/eventlist.txt`

49091 bytes in `TSO_GAME_DIR`, 49355 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `sounddata/tsov2.evt`

32552 bytes in `TSO_GAME_DIR`, 32112 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `sounddata/tsov2.hit`

27803 bytes in `TSO_GAME_DIR`, 27400 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `sys/cityselector.ini`

581 bytes in `TSO_GAME_DIR`, 537 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `sys/hintmanager.ini`

2099 bytes in `TSO_GAME_DIR`, 325 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `sys/nametohostmap.ini`

4534 bytes in `TSO_GAME_DIR`, 4303 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOAnimD.dll`

344064 bytes in `TSO_GAME_DIR`, 344064 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOAudio.dat`

DBPF, 74598227 bytes in `TSO_GAME_DIR`, 74350010 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 31, only in `TSO_BETA_DIR`: 6, changed: 2.

### `TSOAudioViewD.dll`

380928 bytes in `TSO_GAME_DIR`, 380928 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOClient.exe`

307200 bytes in `TSO_GAME_DIR`, 307200 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOData_datadefinition.dat`

6789 bytes in `TSO_GAME_DIR`, 6474 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSODataServiceClientD.dll`

638976 bytes in `TSO_GAME_DIR`, 671744 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOEdithPluginClientD.dll`

393216 bytes in `TSO_GAME_DIR`, 389120 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOGimexD.dll`

368640 bytes in `TSO_GAME_DIR`, 368640 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOGraphicD.dll`

765952 bytes in `TSO_GAME_DIR`, 765952 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSONetServiceSimClientD.dll`

704512 bytes in `TSO_GAME_DIR`, 704512 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOServiceClientD.dll`

569344 bytes in `TSO_GAME_DIR`, 569344 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOSimulatorClientD.dll`

966656 bytes in `TSO_GAME_DIR`, 942080 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `tsov2.dat`

DBPF, 117349763 bytes in `TSO_GAME_DIR`, 118185153 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 0, only in `TSO_BETA_DIR`: 0, changed: 10.

### `TSOViewerClientD.dll`

483328 bytes in `TSO_GAME_DIR`, 479232 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOWinAppD.dll`

2138112 bytes in `TSO_GAME_DIR`, 2093056 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `TSOWorldClientD.dll`

274432 bytes in `TSO_GAME_DIR`, 270336 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `tuning.dat`

2361 bytes in `TSO_GAME_DIR`, 1751 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `uigraphics/eods/eods.dat`

FAR3, 2996200 bytes in `TSO_GAME_DIR`, 2472656 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 12, only in `TSO_BETA_DIR`: 0, changed: 9.

### `uigraphics/hints/hint_solojob1.bmp`

8572 bytes in `TSO_GAME_DIR`, 8508 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.

### `uigraphics/housepage/housepage.dat`

FAR3, 504620 bytes in `TSO_GAME_DIR`, 505272 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 1, only in `TSO_BETA_DIR`: 0, changed: 2.

### `uigraphics/matchmaker/matchmaker.dat`

FAR3, 44146 bytes in `TSO_GAME_DIR`, 43230 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 2, only in `TSO_BETA_DIR`: 0, changed: 0.

### `uigraphics/other/other.dat`

FAR3, 1005614 bytes in `TSO_GAME_DIR`, 1005555 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 0, only in `TSO_BETA_DIR`: 0, changed: 1.

### `uigraphics/personselection/personselection.dat`

FAR3, 1535651 bytes in `TSO_GAME_DIR`, 892314 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 1, only in `TSO_BETA_DIR`: 0, changed: 0.

### `uigraphics/ucp/ucp.dat`

FAR3, 3981791 bytes in `TSO_GAME_DIR`, 3838897 in `TSO_BETA_DIR`.

Entries only in `TSO_GAME_DIR`: 4, only in `TSO_BETA_DIR`: 0, changed: 4.

### `version`

9 bytes in `TSO_GAME_DIR`, 38 in `TSO_BETA_DIR`.
Not compared entry by entry: it isn't a container in both, or doesn't open.
