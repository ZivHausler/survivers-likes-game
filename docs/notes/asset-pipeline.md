# Asset Pipeline (artkit) — pointer + consumer contract

The 3D character/prop/texture art consumed by this game is **produced by an external
tool**, not built in this repo. This note records where it lives, what it outputs, and
the exact contract the game relies on — so the game repo is self-documenting without
duplicating the pipeline (which would drift).

## Where it lives

- **Tool repo:** `C:\Users\avino\swarm\` — its own local git repo (currently **no remote**;
  the factory + source art are unbacked off-machine — push it somewhere).
  - `swarm/artkit/` — the asset factory: SDXL (`gen.py`, `gen_texture.py`), Hunyuan3D-2.1
    (`gen_character.py`), Mixamo (manual web rig), Blender 5.1 finalize/tools. Its
    **workflow guides are mirrored into this repo** at `docs/notes/artkit/` (Hunyuan3D 3D
    track only): `CHARACTER-GUIDE.md` (image→rigged char), `WORKFLOW.md`,
    `STYLE-GUIDE-CYBERANIME.md`, `PROMPTS-CYBERANIME.md` (neon prompt pack; see
    [[asset-licenses]]), plus the 3D-character pipeline design + plan. The guides are
    **adapted to this repo** (Godot-integration steps, `model_scene` swap seam, and doc
    cross-links point here); `docs/notes/artkit/README.md` records the binding contract.
    The toolkit **code/env/models** stay external and unvendored.
  - `swarm/swarm-art/` — generated source art (concepts, textured + rigged `.glb`s).
  - `swarm/swarm-template/` — an **old** Godot scaffold, superseded by this repo. Ignore.

It is intentionally **not vendored** here: it's environment-coupled (WSL conda env,
Blender, multi-GB SDXL/Hunyuan models, hardcoded `/mnt/c/Users/avino/swarm` paths) and has
nothing to do with the game runtime. Treat it like a build tool, not a dependency.

## Flow

```
SDXL concept (T-pose, empty hands) ─▶ Hunyuan3D mesh+PBR ─▶ Mixamo auto-rig
   ─▶ finalize_character.py (merge clips + reattach PBR) ─▶ <name>_rigged.glb
   ─▶ copy into this repo's art/  ─▶ point a *Data.model_scene at it
```
Props attach to `mixamorig:RightHand` via `BoneAttachment3D` (CHARACTER-GUIDE Stage 4A).
Ground textures: `gen_texture.py` (seamless) → `art/textures/`. ~30 min per character.

## Consumer contract (what the game requires of every generated glb)

The swap seam is data, not code — see [[character-data]] (`model_scene`, `model_scale`,
`model_tint`, `model_texture`) and [[player-3d]] / [[enemy-3d]].

1. **Animation clip names are exact.** The actor finds the glb's `AnimationPlayer` and
   plays clips **by name**:
   - **Players** ([[player-3d]]): `idle` and `walk`.
   - **Enemies** ([[enemy-3d]]): `idle` and `move`.
   A missing clip is a silent no-op — the model imports fine but stands frozen. Name them
   in `finalize_character.py` via `--base-name` / `--extra name=...`.
2. **`AnimationPlayer` node** must exist under the instanced scene (Godot's glTF importer
   creates one automatically).
3. **Scale & facing are playtest tunables.** `model_scale` (in the `.tres`) + the `$Model`
   Y offset set ground contact; Kenney native ≈1.8 m at scale `1.0`. The model is rotated
   by `atan2(velocity.x, velocity.z)`, so it should rest facing **+Z**.
4. **Textures vs tint.** A Hunyuan glb already carries PBR — leave `model_tint = WHITE`
   and `model_texture` empty; get the palette accent from the cel/rim shader (see the
   visual-remake plan), not `albedo_color` tinting.

## Related

- Remake plan: `docs/superpowers/plans/2026-06-30-lol-swarm-visual-remake.md` (every task
  tagged GAME vs ARTKIT).
- Visual target: `docs/superpowers/specs/2026-06-30-lol-swarm-visual-identity-design.md`.
- [[asset-licenses]] — record every generated/sourced asset here.
