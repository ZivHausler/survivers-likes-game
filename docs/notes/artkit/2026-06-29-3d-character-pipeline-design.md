# Design: Image→3D Character Pipeline (artkit "Stage C")

**Date:** 2026-06-29 · **Revised:** 2026-06-30 (T-pose + separate-props architecture)
**Scope:** Graphics workstream only (gameplay owned by another contributor).
**Engine:** Godot 4.3 (Forward+). **GPU:** RTX 4080 SUPER (16 GB). **Generation host:** WSL2.

## Goal

A **repeatable, self-contained pipeline** that turns AI concept art into a **rigged,
textured, game-ready Godot character** with **props modelled separately and attached to
skeleton bones** — dropped in by setting `model_scene` on the character's `CharacterData`
`.tres` (the game's swap seam). No gameplay code touched. The pipeline is the deliverable;
the UwU soldier is the first
real character through it.

## Key architecture principle (the hard-won lesson)

**Characters are generated in a strict T-pose with EMPTY HANDS. Every prop (weapon,
backpack item, etc.) is generated as its own mesh and attached to a bone AFTER rigging.**

A character clutching a *fused* two-handed prop cannot be auto-rigged — proven on
2026-06-30: the fused soldier-with-gun mesh (30k, fully textured) failed Mixamo with
"Unknown error while generating motion" because the solid gun bridges both hands and
the bent arms never reach a riggable pose. T-pose + separate props is the standard
game-art pipeline and the fix.

## Locked Decisions

| Decision | Choice |
|---|---|
| Concept art | **Text→image** (SDXL / external LLM). **Characters: strict T-pose, empty hands**, full-body front, symmetric, plain grey bg. **Props: generated separately** (single isolated object, side 3/4 profile, plain white bg). Prompts in "Concept Prompts" below |
| Generator | **Hunyuan3D-2.1**, **self-contained in swarm** via `gen_character.py` — `hy3dshape` (geometry) + `hy3dpaint` (PBR), ported from the proven MyProjects tools |
| bpy workaround | No `bpy` wheel exists for this Python 3.10 / glibc 2.43 env. `gen_character.py` stubs `sys.modules['bpy']` and monkeypatches `convert_obj_to_glb` with a **trimesh PBR exporter**. One-time `custom_rasterizer` CUDA build + paint deps + RealESRGAN ckpt live in the **shared** `~/projects/Hunyuan3D-2.1` repo + `hunyuan` conda env |
| Face budget | **~30k tris default** via `FaceReducer` (`--target-faces`, raise to 40k if wanted) — applied at generation, not a separate retopo |
| Retopo | **OPTIONAL, skipped by default.** FaceReducer already hits the budget and Mixamo rigs triangle meshes fine. Blender QuadriFlow retopo (`retopo_bake.py`) is held in reserve only if joint deformation looks bad |
| Props | **Separate meshes**, attached to skeleton bones via Godot **`BoneAttachment3D`**. Not fused. The held/aim pose comes from animation |
| Rig | **Mixamo** auto-rig on the **T-pose** character (free, humanoid) → `rigged.fbx`. Mixamo preserves geometry + UVs, so textures reattach cleanly afterward |
| Compose | Prop parented to one hand bone (e.g. right hand). Both-hand grip via an aim/hold animation; off-hand grip approximate without IK (game-standard) |
| Integration | Rigged character (+ attached props) dropped in via the `model_scene` field on the character's `CharacterData` `.tres` (`core/character_data.gd`); `player/player_3d.gd` + `enemies/enemy_3d.gd` instance and animate it with no consumer code change |

## Pipeline stages

```
prompt (per character)                         prompt (per prop)
   │ text→image (SDXL/LLM)                          │ text→image
   ▼                                                ▼
0  char_tpose.png (T-pose, empty hands)        prop.png (isolated, side 3/4)
   │ gen_character.py (Hunyuan2.1 self-contained)   │ gen_character.py (same step)
   ▼                                                ▼
1  <name>_textured.glb (T-pose, UV+PBR, ~30k)  <prop>_textured.glb (UV+PBR)
   │ [optional retopo_bake.py — QuadriFlow]
   │ Mixamo (manual web): auto-rig T-pose
   ▼
2  <name>_rigged.fbx (skeleton + skin)
   │ finalize_character.py (Blender: reattach PBR)
   ▼
3  <name>_rigged.glb (Godot-ready: Skeleton3D + AnimationPlayer + PBR)
   │ Godot: import char + prop
   ▼
4  Godot: BoneAttachment3D(hand) → prop; set model_scene on the character .tres
```

## Concept Prompts

**Character (T-pose, empty hands, NO weapon):**
```
POSITIVE: Stylized 3D game character reference, full body head to boots, front view,
strict symmetric T-POSE — both arms straight out horizontally at shoulder height forming
a "T", elbows straight, palms down, fingers slightly spread, HANDS EMPTY holding nothing,
legs straight shoulder-width apart, feet forward, upright, symmetric, facing camera.
[<<identity block: face, gear, clothing — copy from the character's description>>]
Plain seamless light-grey studio background, soft even lighting, no harsh shadows, sharp
focus, high detail, clean stylized proportions, rigging reference sheet style.
NEGATIVE: holding object, weapon, gun, rifle, blaster, anything in hands, hands on hips,
crossed arms, arms down, bent elbows, action pose, dynamic pose, walking, busy background,
environment, props, cropped, half body, close-up, multiple people, extra limbs, extra
fingers, fused objects, foreshortening, deep shadows, watermark, blurry, low quality.
```

**Prop (isolated, side 3/4, no hands):**
```
POSITIVE: Stylized 3D game weapon reference, a single <<prop description>> shown in full,
SIDE 3/4 PROFILE with barrel horizontal, whole object in frame, grip pointing down,
isolated centered single object, nothing holding it, no hands, neutral orientation. Plain
seamless white studio background, soft even lighting, no harsh shadows, sharp focus, high
detail, product hero shot.
NEGATIVE: hands, fingers, arm, person, character, holding, gripping, scene, environment,
background clutter, multiple objects, cropped, partial object, close-up of a detail,
motion blur, dynamic angle, deep shadows, watermark, logo, blurry, low quality.
```
The full UwU-soldier and UwU-blaster prompt instances live in
`swarm-art/characters/uwu_soldier/prompts/`.

## Self-contained generation (proven 2026-06-30)

`gen_character.py` (`artkit/generation/`), run in WSL conda env `hunyuan`:
shape (`Hunyuan3DDiTFlowMatchingPipeline`, `num_inference_steps`, `octree_resolution`) →
`FaceReducer(max_facenum=target)` → bpy stub → paint (`Hunyuan3DPaintPipeline`,
`render_size`/`texture_size`, RealESRGAN, `hunyuan-paint-pbr`) with `convert_obj_to_glb`
monkeypatched to a trimesh PBR exporter → `<name>_textured.glb` (UV + albedo +
metallic-roughness). **Verified:** the soldier ran end-to-end → 30,000 faces, real UVs,
`PBRMaterial`. Same step generates props.

## artkit modules

| File | Stage | Status |
|---|---|---|
| `generation/mesh_utils.py` | pure helpers (`verify_tris`, `character_paths`) | done |
| `generation/gen_character.py` | 1 — self-contained shape+paint (bpy-stub, FaceReducer) | done |
| `generation/finalize_character.py` | 3 — reattach PBR, export Godot `.glb` | to build |
| `generation/retopo_bake.py` | optional — QuadriFlow retopo + PBR resample | reserve |
| `CHARACTER-GUIDE.md` | manual Mixamo walkthrough + commands | done |

## Status

- **Stage 1 works** (self-contained; bpy solved in-repo). The fused soldier-with-gun
  proved generation+texture but **failed rigging** (Mixamo) → motivates this revision.
- **Next:** regenerate a **T-pose, empty-hands** soldier + a **separate** blaster, rig the
  T-pose body (Mixamo succeeds), reattach textures, and compose the blaster onto the hand
  bone in Godot.

## Risks / caveats

1. **Two-handed prop on a T-pose rig:** the prop parents to one hand bone; both-hand grip
   needs an aim/hold animation, off-hand grip approximate without IK (standard).
2. **Identity drift:** a regenerated T-pose character is a **close variant**, not
   pixel-identical to a prior posed image. Preserving an exact identity would need a
   ControlNet pose-transfer step (extra tooling) — out of scope unless requested.
3. **Single-view back hallucination:** upper-back can be smeary; add a back-reference
   image and re-run if a crisp back is needed.
4. **bpy / native build:** solved via the stub + the shared one-time `custom_rasterizer`
   build; documented in `CHARACTER-GUIDE.md`.

## Out of scope

- ControlNet identity-preserving repose (unless requested).
- Gameplay / combat / spawn logic (owned by another contributor).
- Per-frame IK for the off-hand grip (animation handles the hold).
