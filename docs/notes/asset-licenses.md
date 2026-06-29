# Asset Licenses

| Asset Folder | Source URL | License | Attribution Required |
|---|---|---|---|
| `art/enemies/` | https://kenney.nl/assets/monster-builder-pack | CC0 1.0 Universal | No |
| `art/characters/` | https://kenney.nl/assets/tiny-dungeon | CC0 1.0 Universal | No |
| `art/tiles/` | https://kenney.nl/assets/tiny-town | CC0 1.0 Universal | No |
| `addons/godot_vfx/` | https://github.com/haowg/GODOT-VFX-LIBRARY | MIT | Yes |
| `art/characters_3d/kenney_blocky_characters/` | https://kenney.nl/assets/blocky-characters | CC0 1.0 Universal | No |
| `art/enemies_3d/` | MDA Hatchery CP1 (user's Downloads) | ⚠️ Commercial — prototype only | N/A |
| `art/textures/grass_*` | https://polyhaven.com/a/aerial_grass_rock (Poly Haven "aerial_grass_rock") | CC0 1.0 Universal | No |
| `art/hdri/sky_2k.hdr` | https://polyhaven.com/a/kloofendal_43d_clear_puresky (Poly Haven "kloofendal_43d_clear_puresky") | CC0 1.0 Universal | No |
| `art/models/nature/fir_tree_01/` | https://polyhaven.com/a/fir_tree_01 (Poly Haven "fir_tree_01", 1k gltf) | CC0 1.0 Universal | No |
| `art/models/nature/boulder_01/` | https://polyhaven.com/a/boulder_01 (Poly Haven "boulder_01", 1k gltf) | CC0 1.0 Universal | No |

## Character tile choices (Task B1)

Tiles from `art/characters/` (Kenney Tiny Dungeon, CC0):

| Character | Tile file | Visual description |
|---|---|---|
| Ziv | `art/characters/Tiles/tile_0084.png` | Purple-robed mage |
| Avihay | `art/characters/Tiles/tile_0108.png` | Green-armored character |

## Enemy body sprite choices (Task B2)

Tiles from `art/enemies/PNG/Default/` (Kenney Monster Builder Pack, CC0):

| Variant | File | Visual description |
|---|---|---|
| swarmer | `body_greenA.png` | Small bright-green blob body |
| tank | `body_darkB.png` | Large dark/charcoal body — reads as a heavy bruiser |
| spitter | `body_blueB.png` | Medium blue body — distinct from swarmer and tank |

## Background ground tile choice (Task B3)

From `art/tiles/Tiles/` (Kenney Tiny Town, CC0):

| Usage | File | Visual description |
|---|---|---|
| Arena background ground | `art/tiles/Tiles/tile_0000.png` | Flat grass/ground tile (first tile in pack) |

## 3D Player Characters (Task A.1)

| Asset Folder | Source URL | License | Attribution Required |
|---|---|---|---|
| `art/characters_3d/kenney_blocky_characters/` | https://kenney.nl/assets/blocky-characters | CC0 1.0 Universal | No |

**Pack:** Kenney Blocky Characters v2.0 (released 2025-06-10)
**Approach:** 10 distinct humanoid variants (character-a through character-j), each ~111KB GLB with 27 embedded animations including: `idle`, `walk`, `sprint`, `die`, `attack-melee-right`, `attack-melee-left`, `attack-kick-right`, `attack-kick-left`, `holding-right-shoot`, `holding-left-shoot`, `pick-up`, `interact-right`, `interact-left`, `emote-yes`, `emote-no`, `sit`, `drive`, `static`, and wheelchair variants. Each variant ships with its own texture atlas (`texture-a.png` … `texture-j.png`). Variants are visually distinct by costume/color; recoloring via material override will allow representing up to 10+ player "friends".

## 3D Enemy Monsters (Task A.2)

**Source:** MDA Hatchery CP1 — `battle_monsters.zip` + `battle_monsters.unitypackage` (from user's Downloads)

⚠️ **LICENSE CAVEAT:** MDA Hatchery (battle_monsters), 2016 commercial Unity asset store pack, no bundled license file — used for personal prototype only, rights UNCONFIRMED before any distribution.

**Conversion toolchain:** FBX2glTF v0.9.7 (Facebook/Meta Oculus VR, LLC, BSD-licensed tool) installed via `npm install -g fbx2gltf` into `~/npm-global`. Binary: `~/npm-global/lib/node_modules/fbx2gltf/bin/Darwin/FBX2glTF`. Each animation FBX was converted separately with `--binary` flag to produce GLB. Textures embedded in the original FBX files were preserved in the output GLBs.

| Monster | Role | Files | Animations |
|---|---|---|---|
| `art/enemies_3d/bug/` | Swarmer (small/fast) | `bug_mesh.glb`, `bug_idle.glb`, `bug_run.glb`, `bug_die.glb` | idle (48f), run (8f), die_forward (23f) |
| `art/enemies_3d/undead_serpent/` | Boss (imposing) | `serpent_mesh.glb`, `serpent_idle.glb`, `serpent_move.glb`, `serpent_die.glb`, `serpent_attack.glb` | idle (80f), swim/move (80f), die (48f), bite/attack (32f) |
| `art/enemies_3d/diatryma/` | Tank (large bird) | `diatryma_mesh.glb`, `diatryma_idle.glb`, `diatryma_run.glb`, `diatryma_die.glb`, `diatryma_attack.glb` | idle (40f), run (16f), die_forward (13f), bite/attack (20f) |
| `art/enemies_3d/plant_monster/` | Spitter (ranged) | `plant_mesh.glb`, `plant_idle.glb`, `plant_walk.glb`, `plant_die.glb`, `plant_attack.glb` | idle (40f), walk (16f), die_forward (20f), bite/attack (24f) |

Diatryma also has separate PNG textures extracted from the `.unitypackage` at `art/enemies_3d/diatryma/textures/` (diatryma_feathers_TXTR.png, diatryma_feathers_ALPHA.png). Bug, serpent and plant textures are embedded in their mesh GLBs.

## Dedicated CC0 Monster Models — Quaternius (replaces Kenney/MDA placeholders)

Replaced the Kenney Blocky-Character placeholders (archer/magician) and the
⚠️-commercial MDA meshes (dasher's bug mesh, both boss tiers' serpent) with dedicated
CC0 monsters from Quaternius's **Ultimate Monsters** pack. Downloaded as individual GLBs
via Poly Pizza (which redistributes the pack). All five are rigged with embedded
animations (Idle / Walk / Run / Fast_Flying / Death etc., named `CharacterArmature|<Clip>`).

| Role | Model folder | Quaternius creature | License | Attribution |
|---|---|---|---|---|
| `enemies/archer.tres` (ranged) | `art/enemies_3d/ghost/ghost_mesh.glb` | Ghost | CC0 1.0 Universal | No |
| `enemies/magician.tres` (ranged) | `art/enemies_3d/wizard/wizard_mesh.glb` | Wizard | CC0 1.0 Universal | No |
| `enemies/dasher.tres` (gap-close) | `art/enemies_3d/monkroose/monkroose_mesh.glb` | Monkroose | CC0 1.0 Universal | No |
| Mini-boss (Spawner3D) | `art/enemies_3d/demon/demon_mesh.glb` | Demon | CC0 1.0 Universal | No |
| Big-boss (Spawner3D) | `art/enemies_3d/dragon_evolved/dragon_evolved_mesh.glb` | Dragon Evolved | CC0 1.0 Universal | No |

**Source:** Quaternius Ultimate Monsters Pack — https://quaternius.com/packs/ultimatemonsters.html
(individual GLBs via https://poly.pizza/bundle/Ultimate-Monsters-Bundle-5oyGWAmOB6). CC0 1.0,
free for commercial use, no attribution required.

**Integration note:** These are self-contained GLBs (animations baked into the single mesh
file), unlike the MDA models' separate `{base}_run.glb` anim files. `Enemy3D._resolve_anim_clips()`
maps the logical "idle"/"move" states onto the Quaternius clip names (`CharacterArmature|Idle`,
`|Walk`/`|Run`, `|Flying_Idle`/`|Fast_Flying`) via `Enemy3D.resolve_clip()` — see
`test/test_enemy_anim_clip_resolve.gd`.

The Kenney Blocky Characters pack remains in `art/characters_3d/` for the **player** friends
(still CC0); only the enemy usages were swapped. The ⚠️-commercial MDA serpent/bug meshes are
no longer referenced by any boss/dasher but remain on disk (still used by swarmer/tank/spitter).

## CREDITS

GODOT-VFX-LIBRARY by haowg (https://github.com/haowg/GODOT-VFX-LIBRARY) — MIT License.
Full license text: `addons/godot_vfx/LICENSE`
