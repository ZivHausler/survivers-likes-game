# Swarm Game — AI Art Pipeline (Master Workflow)

End-to-end workflow for producing cute 2D creature sprites for a top-down Godot
swarm game, using AI generation + local tooling. **Graphics only** — game logic
is owned by someone else.

This file is the index. Each stage links to its detailed guide. It also contains
the exact commands to reproduce the setup or generate a new creature from a fresh
session.

---

## File map

```
C:\Users\avino\
├─ artkit\                      # the graphics toolkit + all docs
│  ├─ artkit.py                 # CLI: `process` (cutout/normalize) + `pack` (spritesheet)
│  ├─ requirements.txt          # Pillow + rembg
│  ├─ WORKFLOW.md               # <- this file
│  ├─ PROMPTS-CYBERANIME.md     # [ACTIVE] neon cyber-anime prompt pack
│  ├─ STYLE-GUIDE-CYBERANIME.md # [ACTIVE] style consistency + LoRA training (neon)
│  ├─ PROMPTS.md                # ⚠️ DEPRECATED — see PROMPTS-CYBERANIME.md
│  ├─ STYLE-GUIDE.md            # ⚠️ DEPRECATED — see STYLE-GUIDE-CYBERANIME.md
│  ├─ ANIMATION-GUIDE.md        # DragonBones rig -> walk/attack frames
│  └─ generation\
│     ├─ setup.sh               # one-time WSL env setup (uv + py3.11 + torch + diffusers)
│     └─ gen.py                 # SDXL text-to-image generator
├─ swarm-art\                   # generated images land here
│  └─ raw\                      # raw generations (pre-cutout)
└─ swarm-template\              # OLD Godot 4 scaffold — superseded by the game repo
                               #   (survivers-likes-game); assets now drop into THAT repo

WSL (Ubuntu, user=root):
/root/sdgen\
├─ .venv\                       # uv-managed Python 3.11 venv (torch+diffusers)
└─ gen.py                       # permanent copy of the generator
/root/.cache/huggingface\       # downloaded SDXL model cache (DreamShaper XL)
```

---

## The pipeline

```
1. GENERATE   (WSL + SDXL)      cute creature PNG            -> swarm-art\raw\
2. CUTOUT     (artkit process)  transparent, uniform sprite  -> swarm-art\<name>\
3. ANIMATE    (DragonBones)     rig -> idle/walk/attack       -> baked PNG frames
4. PACK       (artkit pack)     spritesheet + grid JSON       -> sheets\
5. IMPORT     (Godot)           AnimatedSprite2D SpriteFrames
```

Detailed stage guides: generation settings in **PROMPTS-CYBERANIME.md** + **STYLE-GUIDE-CYBERANIME.md** (active pack); the cute pair (`PROMPTS.md` / `STYLE-GUIDE.md`) is kept for reference only.
animation in **ANIMATION-GUIDE.md**.

> **3D rigged characters** (image → Hunyuan3D-2.1 → Mixamo rig → Godot, with props
> modelled separately and attached to hand bones) are a separate track — see
> **CHARACTER-GUIDE.md** for the full end-to-end playbook and `artkit/tools/` for the
> Blender helpers.

---

## Stage 1 — Generate (WSL2 + Stable Diffusion XL)

**Environment (already built; verified 2026-06-29).** Runs in WSL2 Ubuntu. GPU
passthrough works (RTX 4080 SUPER, 16GB). A `uv`-managed **Python 3.11** venv is
used because the system WSL Python (3.14) is too new for PyTorch.

Stack: torch 2.5.1+cu121, diffusers 0.38, transformers 5.x.
Model: **DreamShaper XL** (`Lykon/dreamshaper-xl-1-0`), cached under
`/root/.cache/huggingface`. ~6 seconds per 1024px image.

### Generate a new creature (the common command)

From Windows PowerShell, calling into WSL. Put the command in a tiny `.sh` to avoid
quote-mangling across PowerShell -> WSL -> bash (lesson learned: nested quotes break
the creature string). Pattern:

```bash
# run_gen.sh  (edit --creature and --out, then run: wsl bash run_gen.sh)
/root/sdgen/.venv/bin/python /root/sdgen/gen.py \
  --creature "a translucent blue water-slime blob, glossy, droplet eyes" \
  --out "/mnt/c/Users/avino/swarm/swarm-art/raw/waterslime.png" \
  --seed 12345
```

`gen.py` options: `--creature` (required), `--out` (required), `--seed` (default
12345; lock it for consistency), `--steps` (30), `--cfg` (6.5), `--size` (1024),
`--model` (defaults to DreamShaper XL, falls back to base SDXL).

The style block + negative prompt are baked into `gen.py` (match PROMPTS.md). Only
swap `--creature`.

### Rebuild the environment from scratch (new machine / wiped WSL)

```
wsl bash /mnt/c/Users/avino/swarm/artkit/generation/setup.sh
```

This installs uv, Python 3.11, the venv, torch (cu121), and the diffusers stack,
then verifies CUDA. ~3 GB download. Then `gen.py` downloads the model on first run
(~7 GB).

---

## Stage 2 — Cutout & normalize (artkit process)

Removes the background, trims, centers, and makes every sprite a uniform square.

```powershell
cd C:\Users\avino\swarm\artkit
# one-time: pip install -r requirements.txt   (adds rembg for background removal)
python artkit.py process C:\Users\avino\swarm\swarm-art\raw  C:\Users\avino\swarm\swarm-art\firefox  --size 512
```

Use `--no-bg` if an image is already transparent. See README.md for flags.

---

## Stage 3 — Animate (DragonBones)

Turn ONE clean creature into idle/walk/attack without drawing frames: cut into
parts -> bone rig -> keyframe poses -> bake a PNG sequence. Full steps in
**ANIMATION-GUIDE.md**.

---

## Stage 4 — Pack frames into a spritesheet (artkit pack)

```powershell
python artkit.py pack C:\path\to\walk_frames  C:\Users\avino\swarm\swarm-art\sheets\firefox_walk.png
```

Writes the spritesheet + a `.json` with the grid (columns x rows) for Godot import.

> ⚠️ Do NOT run `artkit process` on animation frames — it re-centers each frame
> independently and causes jitter. DragonBones frames are already aligned; go
> straight to `pack`.

---

## Stage 5 — Import into Godot

`AnimatedSprite2D` -> SpriteFrames panel -> select `idle`/`walk`/`attack` ->
Add frames from sprite sheet -> set Horizontal/Vertical from the pack JSON ->
set FPS (idle/walk ~8, attack ~10-12), loop on for idle/walk, off for attack.

> ⚠️ **Legacy (2D) track.** Stages 1–5 above produce 2D sprites for the old
> `swarm-template/` scaffold and do **not** apply to this 3D game. The live track for
> this repo is the **3D rigged-character** pipeline in `CHARACTER-GUIDE.md` (plus the
> seamless ground textures in Stage T below). Kept here for reference only.

---

## Stage T — Tiling ground textures (seamless albedo maps for Terrain3D)

Generate seamlessly tileable 1024×1024 albedo PNGs for Terrain3D ground slots
using SDXL with circular Conv2d padding (all UNet + VAE Conv2d layers switched to
`padding_mode="circular"` before sampling so opposite edges wrap).

Script: `artkit/generation/gen_texture.py`

```bash
# Generate the three standard ground textures
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && O=swarm-art/textures && mkdir -p $O && \
 /root/sdgen/.venv/bin/python artkit/generation/gen_texture.py --prompt "lush green grass lawn" --out $O/grass_albedo.png --seed 11 && \
 /root/sdgen/.venv/bin/python artkit/generation/gen_texture.py --prompt "dry brown dirt soil ground" --out $O/dirt_albedo.png --seed 22 && \
 /root/sdgen/.venv/bin/python artkit/generation/gen_texture.py --prompt "fine golden beach sand" --out $O/sand_albedo.png --seed 33'
```

Each run prints `saved <path>  seamless=True/False`. Circular padding makes tiling
near-perfect; verify visually with a 3×3 montage:

```bash
wsl bash -lc 'cd /mnt/c/Users/avino/swarm && /root/sdgen/.venv/bin/python -c "
from PIL import Image
for n in [\"grass\",\"dirt\",\"sand\"]:
    im=Image.open(f\"swarm-art/textures/{n}_albedo.png\"); w,h=im.size
    m=Image.new(\"RGB\",(w*3,h*3));
    [m.paste(im,(x*w,y*h)) for x in range(3) for y in range(3)]
    m.save(f\"swarm-art/textures/{n}_tile3x3.png\")
print(\"montages written\")"'
```

Outputs land in `swarm-art/textures/`. Assign them to Terrain3D slots in the
Godot editor (see Task 6 notes for that GUI step).

---

## Known issues / gotchas

- **CLIP 77-token limit:** the PROMPTS.md style block is slightly too long, so the
  tail ("sticker, even soft lighting") truncates. Harmless, but trim the style
  block to ≤77 tokens or add `compel` for long prompts.
- **Backgrounds aren't pure white:** model adds a light-grey bg, a drop shadow, and
  sometimes a white "sticker" border. The grey removes fine with rembg, but the
  shadow/border can leave artifacts. Strengthen negatives: `no outline, no border,
  no drop shadow`, and/or use a flat chroma (magenta) background.
- **WSL paths:** keep the SD env on the WSL native filesystem (`/root/sdgen`), not
  `/mnt/c`, for speed. Only write final outputs across to `/mnt/c/...`.
- **PowerShell -> WSL quoting:** wrap multi-word args in a `.sh` script rather than
  passing them through nested quotes.

---

## Quick start (from a fresh session)

```
# 1. Generate (edit creature + out path inside, or reuse the pattern above)
wsl bash -lc '/root/sdgen/.venv/bin/python /root/sdgen/gen.py \
  --creature "a leafy green sprout critter, big leaf on head, vine arms" \
  --out "/mnt/c/Users/avino/swarm/swarm-art/raw/sprout.png" --seed 12345'

# 2. Cut out + normalize
cd C:\Users\avino\swarm\artkit
python artkit.py process C:\Users\avino\swarm\swarm-art\raw C:\Users\avino\swarm\swarm-art\sprout --size 512

# 3. (animate in DragonBones per ANIMATION-GUIDE.md, then)
python artkit.py pack <frames_dir> C:\Users\avino\swarm\swarm-art\sheets\sprout_walk.png
```
