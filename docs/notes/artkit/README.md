# artkit workflow docs (mirrored)

These are the **asset-creation workflow guides**, mirrored from the external artkit
toolkit (`C:\Users\avino\swarm\artkit`) so this repo is self-documenting without needing
the toolkit checked out. Only the **docs** live here — the toolkit code, WSL/conda env,
Blender, and the multi-GB Hunyuan3D/SDXL models stay external (see
[`../asset-pipeline.md`](../asset-pipeline.md) for why).

Generated `.glb`/texture assets are **not** vendored via these docs; the ones actually
used get copied into this repo's `art/` on use.

## Files

- **CHARACTER-GUIDE.md** — ⭐ the Hunyuan3D-2.1 playbook: concept image → mesh + PBR →
  Mixamo rig → Godot. The core end-to-end recipe.
- **WORKFLOW.md** — master index (older 2D-sprite track + seamless ground-texture gen +
  pointer to the 3D track).
- **PROMPTS-CYBERANIME.md** — active neon cyber-anime prompt pack (Stage 0 concept images).
- **STYLE-GUIDE-CYBERANIME.md** — active style-consistency guide.
- **2026-06-29-3d-character-pipeline-design.md** — the pipeline design spec.
- **2026-06-29-3d-character-pipeline.md** — the pipeline implementation plan.

## Adapted for this repo

Originally written against the external artkit repo + the retired `swarm-template/`
scaffold. The **game-side references have been fixed to this repo** — the Godot-integration
steps, the `model_scene` swap seam, and internal doc cross-links. (The historical
implementation plan `2026-06-29-3d-character-pipeline.md` is the one exception: it keeps its
original paths as a truthful build-log, under a banner pointing here.)

What still (correctly) points **outside** this repo is the **asset factory** itself — it
runs in the external toolkit and is not vendored here:

- Generation/rig commands run in WSL against `C:\Users\avino\swarm\` (conda env `hunyuan`,
  Blender, Hunyuan3D/SDXL models, `artkit/generation/` + `artkit/tools/`).
- Intermediates land in the toolkit's `swarm-art/characters/<name>/`; only the finished
  `.glb`s get copied into this repo's `art/` (CHARACTER-GUIDE Stage 5).

Binding contract when following the guides:

- **Copy target:** finished characters → `art/characters_3d/<name>/`, props →
  `art/weapons_3d/<prop>/`.
- **Swap seam:** wire them by setting `model_scene` on a `CharacterData` / enemy `.tres`
  (see [`../asset-pipeline.md`](../asset-pipeline.md)), not the old `Creature.set_visual()`.
- **Clip names are binding:** players need `idle` + `walk`; enemies need `idle` + `move`
  (CHARACTER-GUIDE Stage 3 / asset-pipeline.md).
