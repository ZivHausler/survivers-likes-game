# artkit — Image→3D Rigged Character Playbook (Stage C)

End-to-end, repeatable recipe for turning AI concept art into a **rigged, textured,
animated Godot character with separately-modelled props attached to bones**. Proven on
the UwU soldier (2026-06-30). Follow the **Quick Start** checklist; deeper notes and the
hard-won gotchas are below it.

> **The one rule that makes everything work:** generate the **character in a strict
> T-pose with EMPTY HANDS**, generate every **prop separately**, and attach props to
> hand bones *after* rigging. A character holding a fused two-handed prop CANNOT be
> auto-rigged (Mixamo fails with "Unknown error while generating motion").

## Two deliverables (decide what you need)

A posed reference image gives you two different end-products — they need different paths:

| Want | Make | Animatable? | How |
|---|---|---|---|
| **Exact-look hero / portrait** (matches the reference pose precisely) | the **fused mesh** generated straight from the *posed* image | ❌ no (one mesh, prop fused) | run `gen_character.py` on the **original posed image** → done. The hold is perfect because Hunyuan reconstructs the photo as-is |
| **Animatable game character** (walks/runs, prop in hand) | the **T-pose char + separate prop**, rigged | ✅ yes | the full Stage 0→5 below |

For the game character, the in-hand pose comes from animation + a hand-attached prop and is **approximate** by default; matching a *specific* two-handed grip needs a **custom pose** (Stage 4B). You can keep both assets — the fused one as the hero/marketing render, the rigged one for gameplay.

---

## Prerequisites (one-time, already done on this machine)

- **Hunyuan3D-2.1** in WSL: repo `~/projects/Hunyuan3D-2.1`, conda env `hunyuan`
  (python `/root/miniconda3/envs/hunyuan/bin/python`, torch cu124).
  - The texture (paint) stage needs the `custom_rasterizer` CUDA build + paint deps
    (realesrgan, basicsr, pytorch-lightning==1.9.5, torchmetrics, setuptools<81) +
    `RealESRGAN_x4plus.pth` in `hy3dpaint/ckpt/`. Already built. (See the
    `hunyuan-local-pipeline` memory for the build gotchas if it ever needs rebuilding.)
  - **No `bpy` wheel exists** for this py3.10 / glibc2.43 env. `gen_character.py`
    handles it by stubbing `sys.modules['bpy']` and swapping `convert_obj_to_glb` for a
    trimesh PBR exporter — no action needed, just don't "fix" the stub.
- **Blender 5.1** on PATH as `blender` (Git Bash shim `/c/Users/avino/bin/blender`).
- **Godot 4.3** as `godot` (shim). GUT addon installed in this game repo (`addons/gut/`).
- **Mixamo** account (free Adobe login) for rigging.
- pytest installed in the `hunyuan` env (for `artkit/test`).

---

## Quick Start (new character `<name>`)

```
0. Write 2 concept prompts (character T-pose + each prop) -> generate images
   -> swarm-art/characters/<name>/reference_tpose.png  and  <prop>_ref.png
1. GENERATE   gen_character.py on each image            -> *_textured.glb (30k, PBR)
2. RIG        export FBX, Mixamo auto-rig the T-pose char, grab Rifle clips
              -> save rigged + clip FBXs to swarm-art/characters/<name>/
3. FINALIZE   finalize_character.py merges clips + reattaches PBR -> <name>_rigged.glb
4. COMPOSE    attach prop to mixamorig:RightHand:
              4A game-approximate (BoneAttachment3D + Rifle anim), or
              4B exact two-handed hold (build_pose_blend.py -> pose in Blender)
5. GODOT      copy glbs into this repo (art/characters_3d/ + art/weapons_3d/),
              set the character .tres's model_scene to the rigged glb
```

Per-character work after the prompts is ~30 min (most of it GPU + a Mixamo upload).

---

## Stage 0 — Concept images (text→image)

Two **separate** images. Templates live in `swarm-art/characters/uwu_soldier/prompts/`
(`character_tpose.txt`, `blaster.txt`) — copy them and swap the identity/prop text.

**Character — must be:** strict **T-pose** (arms straight out horizontal, elbows
straight), **hands open and empty**, full body head-to-boots, front view, symmetric,
plain light-grey background, even lighting. Negative-prompt: *holding object, weapon,
crossed arms, arms down, bent elbows, action pose, props*.

**Prop — must be:** one **isolated** object, **side 3/4 profile**, plain white
background, **no hands**, whole object in frame, grip visible. Negative-prompt: *hands,
person, holding, scene, multiple objects*.

A slightly-drooped (wide-A) pose still rigs fine; a clean T is best. The hands MUST be
open and empty.

---

## Stage 1 — Generate + texture (`gen_character.py`)

Self-contained Hunyuan3D-2.1 shape+paint. Run per image (character and each prop):

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && PYTHONPATH=/mnt/c/Users/avino/swarm \
  /root/miniconda3/envs/hunyuan/bin/python artkit/generation/gen_character.py \
  --image swarm-art/characters/<name>/reference_tpose.png --name <name> --target-faces 30000'
```

- Output: `swarm-art/characters/<name>/<name>_textured.glb` (UV + PBR albedo +
  metallic-roughness) plus sidecar `.obj/.mtl/.jpg` (git-ignored).
- `--target-faces` = budget via FaceReducer (character 30000; prop ~20000). 0 = no reduction.
- Other flags: `--steps 30 --octree 256 --views 6 --resolution 512 --render-size 1024
  --texture-size 2048 --cpu-offload`. Defaults fit the 4080's 16 GB with no OOM.
- ~6–9 min per asset (shape ~30 s + paint multiview). The **back is hallucinated** from a
  single front view (smeary upper back is normal); add a back-reference + re-run for a
  crisp back.

**Preview any glb** (4-angle turnaround):
```bash
blender -b -P artkit/tools/render_glb.py -- <mesh>.glb <out_dir>
```

---

## Stage 2 — Rig on Mixamo (manual, web, free)

1. Export an upload FBX (single mesh, embedded textures):
   ```bash
   blender -b -P artkit/tools/export_fbx.py -- \
     swarm-art/characters/<name>/<name>_textured.glb \
     swarm-art/characters/<name>/<name>_for_mixamo.fbx
   ```
2. **mixamo.com → Upload Character →** the FBX. Gray-on-Mixamo is fine — it ignores
   textures (we reattach them in Stage 3); it only needs geometry.
3. Place markers (chin, wrists, elbows, knees, groin). With a T-pose + open hands this is
   easy and **"Use Symmetry" can stay ON**. Press **Next** → auto-rig.
4. Grab the **"Rifle" animation set** (search Mixamo): **Rifle Idle, Walk With Rifle,
   Rifle Run** (+ optional Aim/Fire). The Rifle clips pose both hands into a weapon grip —
   this is what makes the attached prop look held.
   - On Walk/Run, **check "In Place"** (game code drives position; no root motion).
5. **Download** each as **FBX Binary, With Skin, 30 fps** into
   `swarm-art/characters/<name>/` (e.g. `Rifle Idle.fbx`, `Walk With Rifle.fbx`,
   `Rifle Run.fbx`). Each file carries the same skinned mesh + one clip.

**Inspect what Mixamo gave you** (meshes/skeleton/clips):
```bash
blender -b -P artkit/tools/inspect_fbx.py -- "<file1>.fbx" "<file2>.fbx" ...
```

---

## Stage 3 — Finalize (`finalize_character.py`)

Merges every clip onto one skeleton, reattaches the Stage-1 PBR material, exports a
Godot-ready glb with named animations:

> **⚠️ Clip-naming contract (the consumer plays clips by exact name).** The
> friends-swarm game finds the glb's `AnimationPlayer` and plays clips literally
> named **`idle`** and **`walk`** for player characters (`player/player_3d.gd`), and
> **`idle`** and **`move`** for enemies (`enemies/enemy_3d.gd`). A missing clip is a
> silent no-op — the model imports fine but just won't animate. So always include an
> `idle` clip and a `walk` (player) / `move` (enemy) clip. Set the names here with
> `--base-name` / `--extra name=...`. Extra clips (`rifle_idle`, `run`, …) are harmless
> but unused. The example below already emits `idle` + `walk` (plus unused extras).

```bash
blender -b -P artkit/generation/finalize_character.py -- \
  --base "swarm-art/characters/<name>/Rifle Idle.fbx" --base-name rifle_idle \
  --extra "walk=swarm-art/characters/<name>/Walk With Rifle.fbx" \
  --extra "run=swarm-art/characters/<name>/Rifle Run.fbx" \
  --extra "idle=swarm-art/characters/<name>/Idle.fbx" \
  --textured "swarm-art/characters/<name>/<name>_textured.glb" \
  --out "swarm-art/characters/<name>/<name>_rigged.glb"
```

- `--base` = the skinned FBX used for mesh+rig (its clip → `--base-name`).
- Each `--extra name=path` adds another clip under `name` (action datablocks are merged
  onto the base skeleton; same `mixamorig:` bone names).
- Reattaches the PBR material from `--textured` (Mixamo flattens materials; UVs are
  preserved so the maps land correctly).
- Verify the result (animations / skin / textures) by reading the glb JSON, or just run
  the Godot GUT test (Stage 5).

**Preview rigged + posed** (any clip):
```bash
blender -b -P artkit/tools/compose_render.py -- \
  <char>_rigged.glb <prop>_textured.glb <out_dir> <frame> \
  <scale> <barrel_flip> <up_flip> 0 <fwd_m> <up_m> <side_m> <clip_name> <tag>
```

---

## Stage 4 — Compose the prop onto the hand

Props attach to **`mixamorig:RightHand`** (the trigger hand). **Key truth:** a prop
rigidly bolted to one hand + a *stock* animation gives a believable-but-approximate
hold — the animation decides where both hands go, with no knowledge of where the prop
actually is. So pick the path that fits:

### 4A — Game-approximate (fastest, in-engine)
Good enough for gameplay. The prop follows the right hand; the Rifle animation brings the
hands together so it reads as "held".

- **Prop orientation (don't guess Euler angles):** normalize with `transform_apply`,
  identify **barrel = longest bbox axis**, **up = 2nd-longest**, build a rotation mapping
  barrel→world **-Y (forward)**, up→world **+Z**. Two ±1 flips fix which end is the
  muzzle / which way is up. (See `compose_render.py` / `build_pose_blend.py`.)
- **Working UwU-blaster values:** `scale 0.6` (≈1.2 m), `barrel_flip -1`, `up_flip +1`.
  These give muzzle-forward, UwU visible, full rifle length.
- **In Godot:** add a `BoneAttachment3D` under the `Skeleton3D`, **Bone Name =
  `mixamorig:RightHand`**, add the prop glb as its child, set the transform (nudge by eye).
- **Preview before Godot:** `compose_render.py` (see Tools) renders the prop attached in
  any clip.

### 4B — Exact two-handed hold (custom pose, for hero shots / a precise grip)
When you need the right hand **on the grip** and the left hand **under the fore-end**
(a real two-handed hold), you must author a pose — a stock clip can't do it. Use the
pose-builder, then finalize live in Blender:

```bash
blender -b -P artkit/tools/build_pose_blend.py -- \
  swarm-art/characters/<name>/<name>_rigged.glb \
  swarm-art/characters/<prop>/<prop>_textured.glb \
  swarm-art/characters/<name>/<name>_pose.blend  0.6  rifle_idle
```
This writes a `.blend` with: the prop **parented to RightHand** (grip-aligned, oriented),
a **left-hand IK target** stuck to the prop's fore-end (so the left hand auto-follows),
and a **baked starting pose** (no animation fighting you).

**Finalize in Blender (GUI):**
1. Open the `.blend`. Click `<name>` mesh in the outliner → hover viewport → **Numpad `.`**
   to frame it. (Delete the stray `Icosphere` if an old build left one.)
2. Select the **Armature** → **Pose Mode**.
3. Rotate the **right arm** bones (`RightShoulder/RightArm/RightForeArm`) to carry the gun;
   **roll `RightHand`** so the grip seats in the palm. The gun follows the hand.
4. The **left hand auto-follows** via IK; if needed, move the `L_hand_target` empty under
   the fore-end.
5. **Export** the mesh + armature + prop as `<name>_posed.glb` (glTF 2.0, "Selected
   Objects").

Then render to check (`render_glb.py`) and, for the game, read off the final
prop-relative-to-hand transform for the Godot `BoneAttachment3D`.

---

## Stage 5 — Godot integration

Copy the finished glbs out of the external artkit working dir into **this game repo**,
then import and test from the repo root:

```bash
# characters → art/characters_3d/<name>/ ; props → art/weapons_3d/<prop>/
cp /c/Users/avino/swarm/swarm-art/characters/<name>/<name>_rigged.glb   art/characters_3d/<name>/
cp /c/Users/avino/swarm/swarm-art/characters/<prop>/<prop>_textured.glb art/weapons_3d/<prop>/<prop>.glb
godot --headless --import                                            # import the new glbs
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit  # run the suite
```

The rigged glb imports as a `Skeleton3D` + `AnimationPlayer` (clips: idle/rifle_idle/
walk/run). It is **not** loaded through a scaffold node — instead point a character at it
by setting **`model_scene`** on that character's `CharacterData` `.tres`
(`res://characters/<name>_3d.tres`; field defined in `core/character_data.gd`). Enemies
use the same `model_scene` field on their `enemies/*.tres`. The consumers instance and
animate it with **no consumer code changes** — `player/player_3d.gd` plays the `idle` /
`walk` clips, `enemies/enemy_3d.gd` plays `idle` / `move`. See the full swap-seam contract
in `docs/notes/asset-pipeline.md`, and a live example in `characters/avihay_3d.tres`
(`model_scene` → `art/characters_3d/uwu_soldier/uwu_soldier_rifle.glb`).

---

## Tools (`artkit/tools/`, run under Blender)

| Script | Purpose |
|---|---|
| `render_glb.py <glb> <outdir>` | 4-angle turnaround render of any glb |
| `export_fbx.py <glb> <out.fbx>` | join to one mesh + embedded textures for Mixamo |
| `inspect_fbx.py <fbx>...` | report meshes / skin / armature bones / clips per FBX |
| `compose_render.py <char> <prop> <outdir> <frame> <scale> <barrel_flip> <up_flip> 0 <fwd> <up> <side> <clip> <tag>` | preview a prop attached to RightHand in a posed clip |
| `build_pose_blend.py <char_rigged.glb> <prop.glb> <out.blend> [scale] [start_action]` | build a pose-ready `.blend` (prop parented to RightHand + left-hand IK + baked pose) for Stage 4B |

---

## Gotchas & Lessons (do NOT relearn)

1. **Fused props are un-riggable.** T-pose + empty hands + separate props is mandatory,
   not optional. This was the single biggest lesson.
2. **Background removal must actually run.** `Image.open(...).convert("RGBA")` makes the
   `mode == "RGB"` check always false → rembg never runs → the grey backdrop is baked
   into the mesh. Use the "no real alpha → remove background" logic in `gen_character.py`.
3. **`bpy` has no wheel here.** Don't try to `pip install bpy`. The stub +
   trimesh-`convert_obj_to_glb` swap in `gen_character.py` is the solution.
4. **Hunyuan shape doesn't reduce faces** — `FaceReducer` (`--target-faces`) is the
   authoritative budget control. Retopo is optional (skip it; Mixamo rigs triangles).
5. **Mixamo rig carries a 0.01 cm→m scale** in its bone matrices. When attaching a prop
   via a bone's world matrix, **drop the scale** (decompose, use position+rotation only)
   or the prop shrinks ~100×.
6. **`object.dimensions` ignores rotation** — it's the local bbox × scale. Useless for
   checking world orientation; render and look instead.
7. **Camera/handedness:** for a camera looking +X with up +Z, screen-right = world **-Y**.
   Forward (the way the character faces) is **-Y**; the muzzle must point -Y.
8. **Mixamo strips/flattens textures.** Always reattach PBR from the Stage-1
   `_textured.glb` in finalize. UVs survive, so the maps map correctly.
9. **Two-handed grip is approximate by default.** The prop parents to ONE hand; the
   off-hand sits near the fore-end via the Rifle animation, not perfectly. A *stock
   animation cannot place each hand on a specific part of the prop* — for an exact grip
   you must author a custom pose (Stage 4B) with an IK target on the support hand.
10. **The fused mesh IS the exact reference pose.** If you want a portrait that matches
    a *posed* reference photo precisely, just run `gen_character.py` on that photo — the
    result is un-riggable but nails the pose/hold for free. Keep it as the hero asset.
11. **Stray `Icosphere` in the pose `.blend`.** Older `build_pose_blend.py` runs left a
    42-vert default sphere at the origin (inside the hips). Harmless — delete it, or
    re-run the current script (it drops unparented meshes automatically).
12. **Headless render noise** ("Parameter m is null", RID-leak lines) is benign — ignore.
13. **Consumer plays clips by exact name.** friends-swarm plays `idle`+`walk` (players)
    or `idle`+`move` (enemies). If you name the base clip `rifle_idle` and forget a plain
    `idle`, the character imports but stands frozen. Always emit `idle` + `walk`/`move`
    in `finalize_character.py` (see the Stage 3 contract note).

---

## Reference

- Spec: `docs/notes/artkit/2026-06-29-3d-character-pipeline-design.md`
- Plan: `docs/notes/artkit/2026-06-29-3d-character-pipeline.md`
- Generation internals + native-build gotchas: `hunyuan-local-pipeline` memory.
