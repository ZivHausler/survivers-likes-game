# Image→3D Character Pipeline Implementation Plan

> **⚠️ HISTORICAL BUILD-LOG — reference only.** This plan records how the **external
> artkit toolkit** was *built* (against the artkit repo at `C:\Users\avino\swarm\` and the
> now-retired `swarm-template/` Godot scaffold). Its file paths, `swarm-template/…` copy
> targets, and `Creature.visual` / `set_visual()` integration refer to that original
> environment, **not** to this game repo — they are preserved as-is so the build history
> stays truthful. To *use* the pipeline from this repo, follow `CHARACTER-GUIDE.md`
> (Stage 5 = the current Godot integration) and `docs/notes/asset-pipeline.md` (the swap
> seam: set `model_scene` on a character `.tres`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a repeatable, self-contained artkit pipeline that turns AI concept art into a game-ready, rigged, textured `.glb` character with **props modelled separately and attached to skeleton bones**, dropped into the game via the `model_scene` swap seam (originally the `swarm-template` scaffold's `Creature.visual` slot; now a character `.tres` — see the banner above).

> **REVISED 2026-06-30 — see "Revised Flow" below.** The original plan generated a single *posed* mesh with the gun **fused** and reposed to A-pose. That proved un-riggable (Mixamo "unknown error while generating motion" on the fused soldier). The architecture changed to: **generate the character in a strict T-pose with empty hands**, generate each **prop separately**, rig the clean T-pose body on Mixamo, and **compose props onto hand bones in Godot**. Tasks 1–2 (helpers, self-contained `gen_character.py`) are done and still valid; the retopo task is now optional; the repose/rig/finalize/integrate tasks are superseded by the Revised Flow.

**Architecture:** A self-contained "character" track in `artkit/`. Hunyuan3D-2.1 (conda env `hunyuan`) generates a textured mesh per concept image via `gen_character.py` (ports the proven bpy-stub + trimesh PBR exporter; `FaceReducer` sets the face budget). The T-pose character auto-rigs on Mixamo; Blender (5.1.2) finalizes to a Godot-ready `.glb`; props are separate `.glb`s attached via `BoneAttachment3D`. Pure logic is unit-tested with pytest; GPU/Blender/web/editor steps are gated by headless verification + user-reviewed visual checkpoints. Graphics only.

**Tech Stack:** Python 3.10 (conda env `hunyuan`: torch 2.5.1+cu124, trimesh 4.4.7, pymeshlab, Pillow), Hunyuan3D-2.1 (`hy3dshape` + `hy3dpaint`), Blender 5.1.2 (bpy, QuadriFlow remesh, Cycles bake), Mixamo (web auto-rig), Godot 4.3 + GUT, pytest.

## Global Constraints

- **Generation host:** WSL2. Hunyuan runs in conda env `hunyuan` at python `/root/miniconda3/envs/hunyuan/bin/python`, from cwd `/root/projects/Hunyuan3D-2.1` (its ckpt/config paths are relative). Verified: torch CUDA available.
- **Blender:** invoke as `blender` (the Git Bash wrapper at `/c/Users/avino/bin/blender` → Blender 5.1.2). Blender scripts run under Blender's bundled Python (bpy); pure helpers must stay bpy-free so pytest can import them in the conda env.
- **Repo:** single git repo at `C:\Users\avino\swarm\`, branch **main**. All commits land on `main`.
- **artkit root:** `C:\Users\avino\swarm\artkit\` (WSL: `/mnt/c/Users/avino/swarm/artkit`). Outputs: `swarm-art/characters/<name>/`.
- **Godot project root:** `swarm-template/` (paths in Godot are `res://`-relative to it). Engine **Godot 4.3 Forward+** — do not change.
- **Graphics only:** do NOT add/modify game/combat/spawn logic. The existing 2D scaffold is owned by another contributor.
- **Face budget:** default **30000 tris** (`--target-faces`, raise to 40k by flag). **`FaceReducer` at generation is the authoritative face-count control** (retopo is optional).
- **Props:** generated as **separate** meshes and attached to skeleton bones via Godot `BoneAttachment3D` — NOT fused into the character.
- **Character pose:** characters are generated in a **strict T-pose with empty hands** (riggable by Mixamo).
- **Test runner:** `cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest <path> -v` (run via `wsl bash -lc '...'`).
- **Pure-helper home:** `artkit/generation/mesh_utils.py` — bpy-free, importable by both pytest and Blender scripts.

---

## Revised Flow (2026-06-30) — supersedes the stage framing in Tasks 3–6

Sequence and status under the T-pose + separate-props architecture:

| Step | What | Status |
|---|---|---|
| **R0. Concept art** | Text→image (SDXL/LLM). Character **T-pose, empty hands**; gun **separate** (isolated, side 3/4). Prompts: `swarm-art/characters/uwu_soldier/prompts/{character_tpose,blaster}.txt` | prompts written; image-gen is user/external |
| **R1. Generate (char)** | `gen_character.py --image <char_tpose.png> --name uwu_soldier --target-faces 30000` → `uwu_soldier_textured.glb` | **gen_character.py done** (Tasks 1–2); rerun on the T-pose image |
| **R1b. Generate (prop)** | Same `gen_character.py` on the blaster image → `uwu_blaster_textured.glb` (or reuse `MyProjects\generated\uwu_blaster_final.glb`) | tool ready |
| **R2. Rig (Mixamo)** | Manual web: upload the **T-pose** char FBX (export via Blender), auto-rig, download `uwu_soldier_rigged.fbx`. Per `CHARACTER-GUIDE.md` | succeeds on T-pose (failed on fused pose) |
| **R3. Finalize** | `finalize_character.py` (Task 5) — reattach PBR, export `uwu_soldier_rigged.glb` | build `finalize_character.py` |
| **R4. Compose + integrate** | Godot: import char + prop; `BoneAttachment3D` on the right-hand bone holds the blaster; swap rigged char into `Creature.visual`. Held/aim pose via animation | replaces Task 6's single-mesh swap; add a prop-attach + GUT test |

**Original Tasks 1–2** (scaffold + `gen_character.py`) are DONE and valid (note: `gen_character.py` is the self-contained bpy-stub/FaceReducer version, not the `demo.py` wrapper the old task text shows). **Task 3 (retopo+bake)** is now OPTIONAL/reserve — skipped by default. **Task 4 (A-pose repose)** is DROPPED — T-pose comes from generation, no repose. **Tasks 5–6** are reframed by R3–R4 above (finalize unchanged; integrate now includes prop bone-attachment).

---

### Task 1: Pipeline scaffold + pure mesh helpers (TDD)

**Files:**
- Create: `artkit/__init__.py`, `artkit/generation/__init__.py`, `artkit/test/__init__.py` (if missing)
- Create: `artkit/generation/mesh_utils.py`
- Test: `artkit/test/test_mesh_utils.py`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - `within_tolerance(actual: int, target: int, tol: float) -> bool` — True iff `abs(actual-target) <= target*tol`.
  - `verify_tris(actual: int, target: int, tol: float = 0.10) -> bool` — alias used by later verification steps (delegates to `within_tolerance`).
  - `character_paths(out_root: str, name: str) -> dict` — returns the canonical artifact paths for a character: keys `dir, reference, textured, retopo_baked, rigged_fbx, rigged_glb` as POSIX strings under `<out_root>/<name>/`.

- [ ] **Step 1: Install pytest into the conda env (one-time setup)**

```bash
wsl bash -lc '/root/miniconda3/envs/hunyuan/bin/python -m pip install -q pytest && /root/miniconda3/envs/hunyuan/bin/python -c "import pytest; print(\"pytest\", pytest.__version__)"'
```
Expected: prints a pytest version (e.g. `pytest 8.x`).

- [ ] **Step 2: Write the failing test**

Create `artkit/test/test_mesh_utils.py`:
```python
from artkit.generation.mesh_utils import within_tolerance, verify_tris, character_paths


def test_within_tolerance_true_inside_band():
    assert within_tolerance(31000, 30000, 0.10) is True   # 3.3% off
    assert within_tolerance(27000, 30000, 0.10) is True    # 10% off (boundary)


def test_within_tolerance_false_outside_band():
    assert within_tolerance(34000, 30000, 0.10) is False   # 13% off
    assert within_tolerance(0, 30000, 0.10) is False


def test_verify_tris_default_tolerance():
    assert verify_tris(29500, 30000) is True
    assert verify_tris(50000, 30000) is False


def test_character_paths_layout():
    p = character_paths("swarm-art/characters", "uwu_soldier")
    assert p["dir"] == "swarm-art/characters/uwu_soldier"
    assert p["reference"] == "swarm-art/characters/uwu_soldier/reference.png"
    assert p["textured"] == "swarm-art/characters/uwu_soldier/uwu_soldier_textured.glb"
    assert p["retopo_baked"] == "swarm-art/characters/uwu_soldier/uwu_soldier_baked.glb"
    assert p["rigged_fbx"] == "swarm-art/characters/uwu_soldier/uwu_soldier_rigged.fbx"
    assert p["rigged_glb"] == "swarm-art/characters/uwu_soldier/uwu_soldier_rigged.glb"
```

- [ ] **Step 3: Run the test, verify it fails**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest artkit/test/test_mesh_utils.py -v'
```
Expected: FAIL — `mesh_utils` not importable / names undefined.

- [ ] **Step 4: Implement mesh_utils.py**

Create empty `artkit/__init__.py`, `artkit/generation/__init__.py`, `artkit/test/__init__.py` if they do not exist. Create `artkit/generation/mesh_utils.py`:
```python
"""Pure, bpy-free mesh helpers shared by the character pipeline.

Kept dependency-light so both pytest (conda env) and Blender's bundled
Python can import it.
"""


def within_tolerance(actual: int, target: int, tol: float) -> bool:
    """True iff actual is within +/- (target*tol) of target."""
    return abs(actual - target) <= target * tol


def verify_tris(actual: int, target: int, tol: float = 0.10) -> bool:
    """Face-count acceptance check used by post-build verification."""
    return within_tolerance(actual, target, tol)


def character_paths(out_root: str, name: str) -> dict:
    """Canonical artifact paths for one character under out_root/name/."""
    d = f"{out_root}/{name}"
    return {
        "dir": d,
        "reference": f"{d}/reference.png",
        "textured": f"{d}/{name}_textured.glb",
        "retopo_baked": f"{d}/{name}_baked.glb",
        "rigged_fbx": f"{d}/{name}_rigged.fbx",
        "rigged_glb": f"{d}/{name}_rigged.glb",
    }
```

- [ ] **Step 5: Run the test, verify it passes**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest artkit/test/test_mesh_utils.py -v'
```
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
cd /c/Users/avino/swarm
git add artkit/__init__.py artkit/generation/__init__.py artkit/test/__init__.py artkit/generation/mesh_utils.py artkit/test/test_mesh_utils.py
git commit -m "feat(artkit): character pipeline scaffold + pure mesh helpers"
```

---

### Task 2: Stage 1 — `gen_character.py` (Hunyuan3D-2.1 shape + paint) + first real generation

**Files:**
- Create: `artkit/generation/gen_character.py`
- Modify: `.gitignore` (ignore heavy intermediate meshes; keep final + reference)
- Create (output, run): `swarm-art/characters/uwu_soldier/reference.png`, `.../uwu_soldier_textured.glb`

**Interfaces:**
- Consumes: `character_paths` from Task 1 (for the output path).
- Produces: CLI `python gen_character.py --image <png> --name <slug> [--out-root swarm-art/characters] [--hunyuan-dir /root/projects/Hunyuan3D-2.1] [--seed 1234] [--max-num-view 6] [--resolution 512]`. Writes `<out-root>/<slug>/<slug>_textured.glb` (UV + PBR incl. normal). Exposes pure helper `build_out_path(out_root, name) -> str` (delegates to `character_paths(...)["textured"]`).

- [ ] **Step 1: Write the failing test (pure path helper only — generation itself is GPU-gated)**

Create `artkit/test/test_gen_character.py`:
```python
from artkit.generation.gen_character import build_out_path


def test_build_out_path_points_at_textured_glb():
    assert build_out_path("swarm-art/characters", "uwu_soldier") == \
        "swarm-art/characters/uwu_soldier/uwu_soldier_textured.glb"
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest artkit/test/test_gen_character.py -v'
```
Expected: FAIL — `gen_character` not importable.

- [ ] **Step 3: Implement gen_character.py**

Create `artkit/generation/gen_character.py`. Mirrors the repo's `demo.py` flow (shape → export glb → paint → textured glb), parameterized and run with cwd inside the Hunyuan repo so its relative ckpt/config paths resolve:
```python
"""Stage 1 of the character pipeline: single image -> textured GLB via
Hunyuan3D-2.1 (hy3dshape geometry + hy3dpaint PBR). Wraps the repo's demo.py
flow. Heavy ML imports happen only inside generate(), so the pure
build_out_path helper stays importable without a GPU.
"""
import argparse
import os
import sys

from artkit.generation.mesh_utils import character_paths


def build_out_path(out_root: str, name: str) -> str:
    return character_paths(out_root, name)["textured"]


def generate(image_path: str, name: str, out_root: str, hunyuan_dir: str,
             seed: int = 1234, max_num_view: int = 6, resolution: int = 512) -> str:
    # Run from the Hunyuan repo dir so its relative ckpt/config paths resolve.
    os.chdir(hunyuan_dir)
    sys.path.insert(0, os.path.join(hunyuan_dir, "hy3dshape"))
    sys.path.insert(0, os.path.join(hunyuan_dir, "hy3dpaint"))

    from PIL import Image
    from hy3dshape.rembg import BackgroundRemover
    from hy3dshape.pipelines import Hunyuan3DDiTFlowMatchingPipeline
    from textureGenPipeline import Hunyuan3DPaintPipeline, Hunyuan3DPaintConfig
    try:
        from torchvision_fix import apply_fix
        apply_fix()
    except Exception as e:
        print(f"torchvision_fix skipped: {e}")

    out_textured = build_out_path(out_root, name)
    os.makedirs(os.path.dirname(out_textured), exist_ok=True)
    shape_tmp = os.path.join(os.path.dirname(out_textured), f"{name}_shape.glb")

    # --- shape ---
    image = Image.open(image_path).convert("RGBA")
    if image.mode == "RGB":
        image = BackgroundRemover()(image)
    shapegen = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained("tencent/Hunyuan3D-2.1")
    mesh = shapegen(image=image)[0]
    mesh.export(shape_tmp)

    # --- paint (PBR) ---
    conf = Hunyuan3DPaintConfig(max_num_view, resolution)
    conf.realesrgan_ckpt_path = "hy3dpaint/ckpt/RealESRGAN_x4plus.pth"
    conf.multiview_cfg_path = "hy3dpaint/cfgs/hunyuan-paint-pbr.yaml"
    conf.custom_pipeline = "hy3dpaint/hunyuanpaintpbr"
    paint = Hunyuan3DPaintPipeline(conf)
    paint(mesh_path=shape_tmp, image_path=image_path, output_mesh_path=out_textured)

    print(f"WROTE {out_textured}")
    return out_textured


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--image", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--out-root", default="/mnt/c/Users/avino/swarm/swarm-art/characters")
    p.add_argument("--hunyuan-dir", default="/root/projects/Hunyuan3D-2.1")
    p.add_argument("--seed", type=int, default=1234)
    p.add_argument("--max-num-view", type=int, default=6)
    p.add_argument("--resolution", type=int, default=512)
    a = p.parse_args()
    generate(a.image, a.name, a.out_root, a.hunyuan_dir,
             a.seed, a.max_num_view, a.resolution)
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest artkit/test/test_gen_character.py -v'
```
Expected: PASS (1 test). (No GPU touched — only `build_out_path`.)

- [ ] **Step 5: Stage the reference image**

Copy the soldier reference into the repo (PYTHONPATH-independent; uses the cached source image):
```bash
mkdir -p /c/Users/avino/swarm/swarm-art/characters/uwu_soldier
cp "/c/Users/avino/.claude/image-cache/c91ccb6f-9dbb-4512-8de2-9d1ccd6bb45f/1.png" \
   /c/Users/avino/swarm/swarm-art/characters/uwu_soldier/reference.png
ls -la /c/Users/avino/swarm/swarm-art/characters/uwu_soldier/reference.png
```
Expected: `reference.png` exists (~1–2 MB).

- [ ] **Step 6: Run the real generation (GPU; reproduces `uwu_soldier_hero_textured`)**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && PYTHONPATH=/mnt/c/Users/avino/swarm \
 /root/miniconda3/envs/hunyuan/bin/python artkit/generation/gen_character.py \
 --image /mnt/c/Users/avino/swarm/swarm-art/characters/uwu_soldier/reference.png \
 --name uwu_soldier'
```
Expected: prints `WROTE .../uwu_soldier_textured.glb`. Runs several minutes (shape ~seconds, paint multiview ~minutes on the 4080). If it OOMs, lower `--resolution 512`→ already minimal, or `--max-num-view 6` (already min); log the deviation.

- [ ] **Step 7: Verify the generated mesh (headless)**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python - <<PY
import trimesh
s = trimesh.load("swarm-art/characters/uwu_soldier/uwu_soldier_textured.glb", force="scene")
g = list(s.geometry.values())[0]
print("faces", len(g.faces), "has_uv", getattr(g.visual, "uv", None) is not None)
assert len(g.faces) > 1000, "mesh too small"
assert getattr(g.visual, "uv", None) is not None, "no UVs (texture missing)"
print("OK")
PY'
```
Expected: `faces <N> has_uv True` then `OK`.

- [ ] **Step 8: Visual checkpoint (user-reviewed)**

Open `uwu_soldier_textured.glb` (drag into the Godot editor, https://gltf-viewer.donmccurdy.com, or `blender uwu_soldier_textured.glb`). Confirm it reads as the plaid-shirt soldier holding the UwU bunny gun, textured. Capture a screenshot for the verification record.

- [ ] **Step 9: Ignore heavy intermediates, commit code + reference**

Append to `.gitignore`:
```
# Heavy character pipeline intermediates (keep only final rigged glb + reference)
swarm-art/characters/**/*_shape.glb
swarm-art/characters/**/*_textured.glb
swarm-art/characters/**/*_baked.glb
swarm-art/characters/**/*_rigged.fbx
```
Then:
```bash
cd /c/Users/avino/swarm
git add artkit/generation/gen_character.py artkit/test/test_gen_character.py .gitignore swarm-art/characters/uwu_soldier/reference.png
git commit -m "feat(artkit): Stage 1 gen_character.py (Hunyuan3D-2.1 shape+paint) + soldier reference"
```

---

### Task 3: Stage 2+3 — `retopo_bake.py` (Blender QuadriFlow retopo + UV + PBR resample)

**Files:**
- Create: `artkit/generation/retopo_bake.py`
- Test: `artkit/test/test_retopo_bake.py`
- Create (output, run): `swarm-art/characters/uwu_soldier/uwu_soldier_baked.glb`

**Interfaces:**
- Consumes: `uwu_soldier_textured.glb` from Task 2; `verify_tris` from Task 1.
- Produces: Blender entrypoint `blender -b -P retopo_bake.py -- --in <textured.glb> --out <baked.glb> --target-tris 30000 [--tex-size 2048]`. Inside Blender it: imports the glb, QuadriFlow-remeshes to the target, Smart-UV unwraps, bakes Diffuse/Normal/Roughness/Metallic from the source onto the retopo, packs them, exports `baked.glb`. Pure helper `quad_target(target_tris: int) -> int` returns the QuadriFlow face target (`target_tris // 2`, since QuadriFlow counts quads ≈ tris/2).

- [ ] **Step 1: Write the failing test (pure helper)**

Create `artkit/test/test_retopo_bake.py`:
```python
from artkit.generation.retopo_bake import quad_target


def test_quad_target_halves_tri_budget():
    assert quad_target(30000) == 15000
    assert quad_target(40000) == 20000
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest artkit/test/test_retopo_bake.py -v'
```
Expected: FAIL — `retopo_bake` / `quad_target` undefined.

- [ ] **Step 3: Implement retopo_bake.py**

Create `artkit/generation/retopo_bake.py`. The `quad_target` helper is bpy-free at module top; all `bpy` use is inside `_run`, invoked only under Blender:
```python
"""Stage 2+3: QuadriFlow retopo + UV unwrap + PBR resample, in one headless
Blender pass. Source and retopo share near-identical geometry, so baking is a
short-ray-distance Selected-to-Active resample (no high->low cage).

Run: blender -b -P retopo_bake.py -- --in <glb> --out <glb> --target-tris N
"""
import sys


def quad_target(target_tris: int) -> int:
    """QuadriFlow target is in faces (quads); ~tris/2."""
    return target_tris // 2


def _argv():
    a = sys.argv[sys.argv.index("--") + 1:]
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="inp", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--target-tris", type=int, default=30000)
    p.add_argument("--tex-size", type=int, default=2048)
    return p.parse_args(a)


def _bake(bpy, src, dst, image_name, bake_type, size, **kw):
    img = bpy.data.images.new(image_name, size, size, alpha=False)
    mat = dst.data.materials[0]
    mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    mat.node_tree.nodes.active = node
    bpy.ops.object.select_all(action="DESELECT")
    src.select_set(True)
    dst.select_set(True)
    bpy.context.view_layer.objects.active = dst
    bpy.context.scene.render.bake.use_selected_to_active = True
    bpy.context.scene.render.bake.cage_extrusion = 0.02
    bpy.ops.object.bake(type=bake_type, **kw)
    return img, node


def _run():
    import bpy
    args = _argv()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.engine = "CYCLES"

    bpy.ops.import_scene.gltf(filepath=args.inp)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    src = bpy.context.view_layer.objects.active

    # retopo: duplicate, QuadriFlow remesh to the quad target
    bpy.ops.object.select_all(action="DESELECT")
    src.select_set(True)
    bpy.context.view_layer.objects.active = src
    bpy.ops.object.duplicate()
    dst = bpy.context.view_layer.objects.active
    dst.name = "retopo"
    bpy.ops.object.quadriflow_remesh(target_faces=quad_target(args.target_tris))

    # UVs for the retopo
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15)
    bpy.ops.object.mode_set(mode="OBJECT")
    if not dst.data.materials:
        dst.data.materials.append(bpy.data.materials.new("char_mat"))

    # resample maps src -> dst
    s = args.tex_size
    diff, dnode = _bake(bpy, src, dst, "albedo", "DIFFUSE", s,
                        pass_filter={"COLOR"})
    norm, _ = _bake(bpy, src, dst, "normal", "NORMAL", s)
    rough, _ = _bake(bpy, src, dst, "roughness", "ROUGHNESS", s)

    # wire baked maps into a Principled BSDF
    mat = dst.data.materials[0]
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for img, sock, noncolor in [(diff, "Base Color", False),
                                 (norm, None, True),
                                 (rough, "Roughness", True)]:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        if noncolor:
            img.colorspace_settings.name = "Non-Color"
        if sock:
            nt.links.new(tex.outputs["Color"], bsdf.inputs[sock])
        else:
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(tex.outputs["Color"], nmap.inputs["Color"])
            nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    # export retopo only
    bpy.ops.object.select_all(action="DESELECT")
    dst.select_set(True)
    bpy.ops.export_scene.gltf(filepath=args.out, use_selection=True,
                              export_format="GLB")
    print(f"WROTE {args.out}")


if __name__ == "__main__":
    _run()
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest artkit/test/test_retopo_bake.py -v'
```
Expected: PASS (2 tests).

- [ ] **Step 5: Run retopo+bake on the soldier (Blender headless)**

```bash
cd /c/Users/avino/swarm
blender -b -P artkit/generation/retopo_bake.py -- \
  --in swarm-art/characters/uwu_soldier/uwu_soldier_textured.glb \
  --out swarm-art/characters/uwu_soldier/uwu_soldier_baked.glb \
  --target-tris 30000
```
Expected: prints `WROTE .../uwu_soldier_baked.glb`, no Python tracebacks. (QuadriFlow + 3 bakes; a few minutes.)
> Fallback: if `quadriflow_remesh` fails on this mesh, replace it with a voxel remesh + decimate to `--target-tris` (set `dst.data.remesh_voxel_size`, `bpy.ops.object.voxel_remesh()`, then a DECIMATE modifier with `ratio` to hit the tri count) and log the deviation.

- [ ] **Step 6: Verify the baked mesh hits budget + carries textures**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && PYTHONPATH=/mnt/c/Users/avino/swarm /root/miniconda3/envs/hunyuan/bin/python - <<PY
import trimesh
from artkit.generation.mesh_utils import verify_tris
s = trimesh.load("swarm-art/characters/uwu_soldier/uwu_soldier_baked.glb", force="scene")
g = list(s.geometry.values())[0]
n = len(g.faces)
print("faces", n, "has_uv", getattr(g.visual, "uv", None) is not None)
assert verify_tris(n, 30000, 0.15), f"face count {n} not within 15% of 30000"
assert getattr(g.visual, "uv", None) is not None, "baked mesh lost UVs"
print("OK")
PY'
```
Expected: `faces ~30000 has_uv True` then `OK`.

- [ ] **Step 7: Visual checkpoint (user-reviewed)**

Open `uwu_soldier_baked.glb`. Confirm: clean, even quad-ish topology; the baked albedo/normal read on the surface; silhouette matches the textured source. Screenshot for the record.

- [ ] **Step 8: Commit**

```bash
cd /c/Users/avino/swarm
git add artkit/generation/retopo_bake.py artkit/test/test_retopo_bake.py
git commit -m "feat(artkit): Stage 2+3 retopo_bake.py (QuadriFlow + UV + PBR resample)"
```

---

### Task 4: Stage 4+5 — repose to A-pose + Mixamo rig (documented manual run)

**Files:**
- Create: `artkit/CHARACTER-GUIDE.md`
- Create (output, run): `swarm-art/characters/uwu_soldier/uwu_soldier_rigged.fbx`

**Interfaces:**
- Consumes: `uwu_soldier_baked.glb` from Task 3.
- Produces: `uwu_soldier_rigged.fbx` (skinned humanoid: skeleton + skin weights, optionally with an idle/walk clip), plus the written guide that makes the manual steps reproducible.

- [ ] **Step 1: Write CHARACTER-GUIDE.md (the manual stages)**

Create `artkit/CHARACTER-GUIDE.md`:
````markdown
# artkit — image→3D character guide (Stage C)

Full chain: `gen_character.py` → `retopo_bake.py` → **repose (manual)** →
**Mixamo (web)** → `finalize_character.py` → Godot. Stages 1–3 and 6 are
scripted (see WORKFLOW.md "Stage C"); this file covers the two manual stages.

## Stage 4 — Repose to A-pose (Blender)

Auto-riggers need a roughly A/T-pose, single, watertight mesh. The reference is
posed (arms holding the gun); open the arms enough for Mixamo to find the joints.

1. `blender swarm-art/characters/uwu_soldier/uwu_soldier_baked.glb`
2. Select the mesh → **Sculpt** workspace → **Pose** brush (or a quick temp
   armature) → rotate each upper arm/forearm outward toward ~45° (A-pose).
   Keep it light — just clear the torso so arms read as separate limbs.
3. The fused gun will follow the right arm; that is expected (gun is fused).
4. Check: no self-intersections at the armpits; mesh stays a single object.
5. Export selected → glTF 2.0 → `uwu_soldier_aposed.glb`.

**Fallback (logged):** if reposing tears the mesh, skip it and rig in the held
pose — Mixamo still rigs it; you just get in-place (idle/aim) animations rather
than a clean walk cycle. Acceptable for a weapon-holding hero.

## Stage 5 — Mixamo auto-rig (web, free)

1. Go to https://www.mixamo.com (free Adobe account; commercial use allowed).
2. **Upload Character** → `uwu_soldier_aposed.glb` (or `.fbx`).
3. Place the 6 markers (chin, wrists, elbows, groin, knees) → **Next** →
   auto-rig runs.
4. Pick animations: an **Idle**, a **Walk**, optionally an **Attack/Aim**.
5. **Download**: Format **FBX Binary (.fbx)**, Skin **With Skin**, 30 fps. Save
   as `swarm-art/characters/uwu_soldier/uwu_soldier_rigged.fbx`.
   (Download one clip "With Skin"; extra clips can be "Without Skin" and merged
   later, or just download the rigged T-pose "With Skin" and add clips in Godot.)

Result feeds Stage 6 (`finalize_character.py`).
````

- [ ] **Step 2: Do the repose (manual, Blender) — produces `uwu_soldier_aposed.glb`**

Follow CHARACTER-GUIDE.md Stage 4 on `uwu_soldier_baked.glb`. Save
`swarm-art/characters/uwu_soldier/uwu_soldier_aposed.glb`.
Verify it still loads and is one mesh:
```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -c "
import trimesh; s=trimesh.load(\"swarm-art/characters/uwu_soldier/uwu_soldier_aposed.glb\", force=\"scene\");
print(\"geoms\", len(s.geometry)); assert len(s.geometry)>=1; print(\"OK\")"'
```
Expected: `geoms 1` (or merged) then `OK`.

- [ ] **Step 3: Do the Mixamo rig (manual, web) — produces `uwu_soldier_rigged.fbx`**

Follow CHARACTER-GUIDE.md Stage 5. Save `uwu_soldier_rigged.fbx` into the
character dir.

- [ ] **Step 4: Verify the rig exists and has a skeleton (headless, Blender)**

Blender's `--python` needs a file (it can't read a script from stdin), so write a
throwaway checker to the scratchpad and run it:
```bash
cd /c/Users/avino/swarm
cat > /tmp/check_rig.py <<'PY'
import bpy, sys
path = sys.argv[sys.argv.index("--")+1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=path)
arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
nbones = len(arms[0].data.bones) if arms else 0
skinned = any(any(m.vertex_groups) for m in meshes)
print(f"armatures={len(arms)} bones={nbones} skinned={skinned}")
assert arms and nbones > 10 and skinned, "rig missing skeleton or skin weights"
print("OK")
PY
blender -b -P /tmp/check_rig.py -- swarm-art/characters/uwu_soldier/uwu_soldier_rigged.fbx
```
Expected: `armatures=1 bones=<N>` (a Mixamo rig has ~65 bones) `skinned=True` then `OK`.
> If `import_scene.fbx` is unavailable in this Blender build, enable the bundled
> FBX add-on (`bpy.ops.preferences.addon_enable(module="io_scene_fbx")`) at the top
> of the checker, or import the FBX once via the Blender GUI and re-export as GLB.

- [ ] **Step 5: Commit the guide (rigged.fbx is git-ignored per Task 2)**

```bash
cd /c/Users/avino/swarm
git add artkit/CHARACTER-GUIDE.md
git commit -m "docs(artkit): Stage 4+5 character guide (A-pose repose + Mixamo rig)"
```

---

### Task 5: Stage 6 — `finalize_character.py` (reconnect textures, export Godot-ready GLB)

**Files:**
- Create: `artkit/generation/finalize_character.py`
- Test: `artkit/test/test_finalize_character.py`
- Create (output, run): `swarm-art/characters/uwu_soldier/uwu_soldier_rigged.glb`

**Interfaces:**
- Consumes: `uwu_soldier_rigged.fbx` (Task 4), `uwu_soldier_baked.glb` (Task 3, for its PBR textures).
- Produces: `blender -b -P finalize_character.py -- --fbx <rigged.fbx> --textured <baked.glb> --out <rigged.glb>` → a Godot-ready GLB (Skeleton3D + skin + the baked PBR materials + any imported AnimationPlayer clips). Pure helper `texture_basename(material_name: str) -> str` strips Mixamo's `Ch##_` / `mixamo:` prefixes so baked maps can be re-matched.

- [ ] **Step 1: Write the failing test (pure helper)**

Create `artkit/test/test_finalize_character.py`:
```python
from artkit.generation.finalize_character import texture_basename


def test_strips_mixamo_prefixes():
    assert texture_basename("Ch36_body") == "body"
    assert texture_basename("mixamo:char_mat") == "char_mat"
    assert texture_basename("char_mat") == "char_mat"
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest artkit/test/test_finalize_character.py -v'
```
Expected: FAIL — `finalize_character` / `texture_basename` undefined.

- [ ] **Step 3: Implement finalize_character.py**

Create `artkit/generation/finalize_character.py`:
```python
"""Stage 6: take the Mixamo-rigged FBX, reattach the baked PBR textures from the
Stage-3 GLB, and export a Godot-ready GLB (Skeleton3D + skin + materials).

texture_basename is bpy-free and unit-tested; bpy use is inside _run.
"""
import re
import sys


def texture_basename(material_name: str) -> str:
    """Strip Mixamo's 'Ch##_' / 'mixamo:' decorations from a material name."""
    n = re.sub(r"^mixamo:", "", material_name)
    n = re.sub(r"^Ch\d+_", "", n)
    return n


def _argv():
    a = sys.argv[sys.argv.index("--") + 1:]
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--fbx", required=True)
    p.add_argument("--textured", required=True)
    p.add_argument("--out", required=True)
    return p.parse_args(a)


def _run():
    import bpy
    args = _argv()
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # import the rigged FBX (skeleton + skin + any clips)
    bpy.ops.import_scene.fbx(filepath=args.fbx)
    rig_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

    # pull the baked material (with its image nodes) from the Stage-3 GLB
    bpy.ops.import_scene.gltf(filepath=args.textured)
    baked_meshes = [o for o in bpy.context.scene.objects
                    if o.type == "MESH" and o not in rig_meshes]
    baked_mat = baked_meshes[0].data.materials[0] if baked_meshes else None

    # assign the baked material onto the rigged mesh, then drop the baked import
    if baked_mat is not None:
        for m in rig_meshes:
            m.data.materials.clear()
            m.data.materials.append(baked_mat)
    for o in baked_meshes:
        bpy.data.objects.remove(o, do_unlink=True)

    # export everything left (rig + skinned mesh + baked material)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB",
                              export_skins=True, export_animations=True)
    print(f"WROTE {args.out}")


if __name__ == "__main__":
    _run()
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python -m pytest artkit/test/test_finalize_character.py -v'
```
Expected: PASS (3 tests).

- [ ] **Step 5: Run finalize on the soldier (Blender headless)**

```bash
cd /c/Users/avino/swarm
blender -b -P artkit/generation/finalize_character.py -- \
  --fbx swarm-art/characters/uwu_soldier/uwu_soldier_rigged.fbx \
  --textured swarm-art/characters/uwu_soldier/uwu_soldier_baked.glb \
  --out swarm-art/characters/uwu_soldier/uwu_soldier_rigged.glb
```
Expected: prints `WROTE .../uwu_soldier_rigged.glb`.

- [ ] **Step 6: Verify final GLB has skeleton + survives load**

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/miniconda3/envs/hunyuan/bin/python - <<PY
import trimesh
s = trimesh.load("swarm-art/characters/uwu_soldier/uwu_soldier_rigged.glb", force="scene")
print("geometries", len(s.geometry))
assert len(s.geometry) >= 1, "no geometry in final glb"
print("OK")
PY'
```
Expected: `geometries 1` then `OK`. (Skeleton/animation presence is confirmed in Godot at Task 6; trimesh just guards loadability.)

- [ ] **Step 7: Commit**

```bash
cd /c/Users/avino/swarm
git add artkit/generation/finalize_character.py artkit/test/test_finalize_character.py
git commit -m "feat(artkit): Stage 6 finalize_character.py (reattach textures, Godot-ready GLB)"
```

---

### Task 6: Stage 7 — Godot integration + WORKFLOW.md + verification record

**Files:**
- Create: `swarm-template/art/characters/uwu_soldier_rigged.glb` (imported copy)
- Create: `swarm-template/test/test_character_glb_swaps_into_creature.gd`
- Modify: `artkit/WORKFLOW.md` (add "Stage C — image→3D character")
- Create: `artkit/docs/superpowers/plans/character-pipeline-verification.md`

**Interfaces:**
- Consumes: `uwu_soldier_rigged.glb` (Task 5); the existing `Creature` abstraction (`scenes/creatures/creature.tscn`, `set_visual(node: Node3D)`) from the env plan's Task 3.
- Produces: a passing GUT test proving the rigged character GLB swaps into `Creature.visual` with no consumer changes, and a filled verification record.

> Prerequisite: this task assumes the env plan's Task 3 (`Creature` abstraction) exists. If `scenes/creatures/creature.tscn` is not yet present, implement that env-plan task first (or, as a minimal stand-in, the test below instantiates a bare `Creature` node from `scripts/creatures/creature.gd`) — log which path was taken.

- [ ] **Step 1: Import the rigged GLB into the Godot project**

```bash
mkdir -p /c/Users/avino/swarm/swarm-template/art/characters
cp /c/Users/avino/swarm/swarm-art/characters/uwu_soldier/uwu_soldier_rigged.glb \
   /c/Users/avino/swarm/swarm-template/art/characters/uwu_soldier_rigged.glb
ls -la /c/Users/avino/swarm/swarm-template/art/characters/uwu_soldier_rigged.glb
```
Expected: the `.glb` exists under `swarm-template/art/characters/`.

- [ ] **Step 2: Write the failing GUT test**

Create `swarm-template/test/test_character_glb_swaps_into_creature.gd`:
```gdscript
extends GutTest

func test_rigged_character_loads_and_has_skeleton():
	var packed: PackedScene = load("res://art/characters/uwu_soldier_rigged.glb")
	assert_not_null(packed, "rigged character glb should import as a PackedScene")
	var root: Node = packed.instantiate()
	add_child_autofree(root)
	var skel = _find_type(root, "Skeleton3D")
	assert_not_null(skel, "imported character should contain a Skeleton3D")

func test_character_swaps_into_creature_visual():
	var CreatureScene = load("res://scenes/creatures/creature.tscn")
	assert_not_null(CreatureScene, "creature.tscn exists (env-plan Task 3)")
	var c = CreatureScene.instantiate()
	add_child_autofree(c)
	var glb: Node3D = load("res://art/characters/uwu_soldier_rigged.glb").instantiate()
	c.set_visual(glb)
	assert_eq(c.get_visual(), glb, "creature visual is now the rigged character, no API change")

func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var f = _find_type(child, type_name)
		if f != null:
			return f
	return null
```

- [ ] **Step 3: Run the test, verify it fails (or errors on missing creature.tscn)**

```bash
cd /c/Users/avino/swarm/swarm-template
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_character_glb_swaps_into_creature.gd -gexit
```
Expected: FAIL — either the glb import/Skeleton assertion fails, or `creature.tscn` missing (resolve per the task's prerequisite note).

- [ ] **Step 4: Trigger Godot import of the new asset, then run the test to pass**

Import the `.glb` (open the editor once, or import headless):
```bash
cd /c/Users/avino/swarm/swarm-template
godot --headless --import . || true
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_character_glb_swaps_into_creature.gd -gexit
```
Expected: PASS (2 tests) — the rigged GLB imports with a `Skeleton3D` and swaps cleanly into `Creature.visual`.

- [ ] **Step 5: Visual checkpoint (user-reviewed)**

Open the rigged GLB in the Godot editor: confirm the soldier renders textured, the `Skeleton3D` + `AnimationPlayer` are present, and at least one Mixamo clip plays. Screenshot for the record.

- [ ] **Step 6: Document Stage C in WORKFLOW.md**

Append a "Stage C — image→3D character" section to `artkit/WORKFLOW.md` with the exact command sequence:
```markdown
## Stage C — image→3D character (rigged)

One reference image → rigged, textured `.glb`. See CHARACTER-GUIDE.md for the
two manual stages (repose + Mixamo).

1. GENERATE  (WSL, conda `hunyuan`)
   PYTHONPATH=/mnt/c/Users/avino/swarm /root/miniconda3/envs/hunyuan/bin/python \
     artkit/generation/gen_character.py --image <ref.png> --name <slug>
2. RETOPO+BAKE (Blender)
   blender -b -P artkit/generation/retopo_bake.py -- \
     --in swarm-art/characters/<slug>/<slug>_textured.glb \
     --out swarm-art/characters/<slug>/<slug>_baked.glb --target-tris 30000
3. REPOSE (Blender, manual)   — CHARACTER-GUIDE.md Stage 4 → <slug>_aposed.glb
4. RIG (Mixamo, web)          — CHARACTER-GUIDE.md Stage 5 → <slug>_rigged.fbx
5. FINALIZE (Blender)
   blender -b -P artkit/generation/finalize_character.py -- \
     --fbx swarm-art/characters/<slug>/<slug>_rigged.fbx \
     --textured swarm-art/characters/<slug>/<slug>_baked.glb \
     --out swarm-art/characters/<slug>/<slug>_rigged.glb
6. IMPORT (Godot) — copy <slug>_rigged.glb to swarm-template/art/characters/,
   swap into Creature.visual via set_visual().
```

- [ ] **Step 7: Fill the verification record**

Create `artkit/docs/superpowers/plans/character-pipeline-verification.md` capturing the spec's acceptance checks (1–6) with PASS/notes + the screenshot references from Tasks 2, 3, and 6.

- [ ] **Step 8: Run the full Godot suite + commit**

```bash
cd /c/Users/avino/swarm/swarm-template
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
cd /c/Users/avino/swarm
git add swarm-template/art/characters/uwu_soldier_rigged.glb swarm-template/test/test_character_glb_swaps_into_creature.gd artkit/WORKFLOW.md artkit/docs/superpowers/plans/character-pipeline-verification.md
git commit -m "feat(world): integrate rigged uwu_soldier into Creature.visual + document Stage C"
```

---

## Notes / Known Risks

- **Manual stages (repose, Mixamo):** Stages 4–5 can't be headless-scripted; they're gated by the load/skeleton verification in Task 4 Step 4 and the Godot checkpoint in Task 6. The fused gun means a light A-pose; if locomotion looks bad, the documented fallback is in-place animation only.
- **QuadriFlow supersedes Instant Meshes.** The spec named Instant Meshes (not installed); Blender's built-in QuadriFlow is the same quad-remesh family with zero extra dependency. Voxel-remesh+decimate is the logged fallback.
- **Heavy intermediates are git-ignored** (`*_textured/_shape/_baked.glb`, `*_rigged.fbx`); only `reference.png` and the final `swarm-template/art/characters/uwu_soldier_rigged.glb` are committed. If the final GLB is large, revisit Git LFS.
- **Env-plan dependency:** Task 6 relies on the `Creature` abstraction (env plan Task 3). If absent, build it first or use the bare-node stand-in noted in Task 6.
- **Blender bake settings** (Cycles, cage extrusion 0.02, Smart-UV angle) may need a nudge per mesh; the gates catch a bad bake (missing UVs / wrong face count) before integration.
