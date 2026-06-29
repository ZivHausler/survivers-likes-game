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

## CREDITS

GODOT-VFX-LIBRARY by haowg (https://github.com/haowg/GODOT-VFX-LIBRARY) — MIT License.
Full license text: `addons/godot_vfx/LICENSE`
