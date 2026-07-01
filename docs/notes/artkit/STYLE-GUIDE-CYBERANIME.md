# Style-Consistency Setup — Cyber-Anime Neon Sci-Fi (SDXL, NVIDIA 16GB)

How to generate a **neon cyber-anime roster that all looks like one game**, on a local
NVIDIA GPU (RTX 4080 SUPER 16GB). The same consistency principle as the cute pack applies:
identical STYLE BLOCK + settings → IP-Adapter lock → **style LoRA** for permanent style lock.

Trigger phrase for this pack: **`cyber-anime swarm style`**

Goal order: get generating today → keep the style consistent with prompts/seed →
**lock the style permanently by training a small LoRA.**

---

## 1. Checkpoint (base model)

Use **SDXL** (not SD1.5): the pipeline already runs SDXL (`gen.py` / DreamShaper XL),
16GB VRAM handles 1024px easily, and SDXL LoRA training fits in 16GB.

Do **NOT** use ToonYou or any SD1.5 checkpoint — they are incapable of the neon cyber-anime
look and lack sufficient detail resolution for 1024px game assets.

**Recommended checkpoints (download from Civitai into `models/Stable-diffusion/`):**

- **DreamShaper XL** (`Lykon/dreamshaper-xl-1-0`) — **already installed and cached**
  (`/root/.cache/huggingface`). Solid all-rounder; handles sci-fi and stylized characters.
  Start here — no new download needed.

- **Animagine XL 3.1** — preferred upgrade if DreamShaper XL results feel too generic.
  Purpose-built for anime aesthetics on SDXL; stronger cyber-anime character detail and
  cleaner anime-style proportions. Swap in when refining the final roster.

- **Pony Diffusion V6 XL** — alternate option; excellent for stylized game art with
  strong graphic silhouettes. Try if Animagine XL doesn't land the right look.

Start with **DreamShaper XL** (zero friction — already running). Switch to Animagine XL 3.1
once concept refs are approved and you are doing final character generation for Hunyuan3D
input images.

---

## 2. Generate consistently (no training yet)

Use `PROMPTS-CYBERANIME.md`. The consistency levers, weakest → strongest:

1. **Identical STYLE BLOCK + NEGATIVE + settings** for every asset. (Baseline —
   do this always.)
2. **Lock the seed** while iterating one character so changes are controlled.
3. **IP-Adapter (style reference)** — feed one approved character render as a style image
   so new characters inherit its look. In Forge: enable the IP-Adapter unit, load your
   reference, set weight ~0.5–0.7. Good for nudging the roster toward a single anchor.
4. **ControlNet reference-only / lineart** — to regenerate a *specific* character in a
   new pose or angle while staying on-model. Use `lineart` or `reference_only` with your
   approved concept as the control image.

This gets you "pretty consistent." For "locked," train a LoRA.

---

## 3. Train a STYLE LoRA — the consistency lock ⭐

A style LoRA bakes the cyber-anime look into a small file. After training, prepend
**`cyber-anime swarm style`** (the trigger word) to any prompt and every new asset
inherits the exact look — even new friends or enemies designed later.

### What you need
- **15–30 of your best approved character/enemy/prop renders** (varied subjects, uniform
  style — do not train on bad generations). Quality beats quantity.
- Tool: **kohya_ss GUI** (`bmaltais/kohya_ss`). Runs on 16GB for SDXL.

### Steps
1. **Prep images:** square, 1024×1024 (run `artkit process --size 1024` on them).
   Plain background — either the light-grey from character gens or white from prop gens.
   Put them in `train/img/10_cyberanime style/` (the `10_` is the repeat count).
2. **Caption them:** one `.txt` per image. Start every caption with the trigger word,
   then describe the subject only (NOT the style — the LoRA learns the style from images):
   `cyber-anime swarm style, gold and white cyber-paladin, angelic tech wings`
   Use kohya's BLIP auto-captioner, then prepend the trigger word manually.
3. **kohya settings for 16GB / SDXL:**

   | Setting | Value |
   |---|---|
   | Base model | DreamShaper XL (or your preferred SDXL checkpoint) |
   | Network type | LoRA (LierLa) |
   | Network Rank (dim) | 32 |
   | Network Alpha | 16 |
   | Learning rate | 1e-4 (unet), 5e-5 (text encoder) |
   | Scheduler | cosine |
   | Epochs | 10 |
   | Total steps | ~1,500–2,500 (count × repeats × epochs) |
   | Batch size | 1 |
   | Mixed precision | bf16 (SDXL preferred over fp16) |
   | Memory savers | gradient checkpointing ON, xformers ON |
   | Resolution | 1024×1024 |

4. **Train** (~40–90 min on 16GB for SDXL). Output `.safetensors` → `models/Lora/` in Forge.
5. **Use it:** add `<lora:cyberanime_swarm:0.8> cyber-anime swarm style,` to the front of
   the STYLE BLOCK. Tune weight 0.6–1.0.

Now every new friend, enemy, or prop is locked to the neon look. Re-train later with
more images to tighten it.

### Per-character consistency (optional)
For a specific character that must look identical across many shots:
- Train a tiny **character LoRA** the same way (10–15 approved images of that character), or
- Use **ControlNet reference-only** with one canonical render as the reference.

---

## 4. Recommended end-to-end workflow

```
1. Lock STYLE BLOCK + NEGATIVE + settings + DreamShaper XL checkpoint.
2. Generate concept refs for the roster (10 friends + enemies + props), one subject per
   prompt slot from PROMPTS-CYBERANIME.md.
3. Approve ~15 best → artkit process --size 1024 → train a cyber-anime swarm style LoRA.
4. Re-generate / generate new assets WITH the LoRA + trigger word.
   -> Every new asset now matches the locked look.
5. For 3D characters: pick each character's canonical T-pose concept ref
   -> hand off to Hunyuan3D pipeline (CHARACTER-GUIDE.md Stage 0→5).
6. For 3D props: pick canonical side-3/4 prop ref
   -> Hunyuan3D gen_character.py → attach to hand bone in Godot.
7. artkit process (cutout/normalize if 2D sprites) → artkit pack → Godot.
```

---

## 5. If you'd rather skip local setup (fallback: Midjourney)

Easiest possible path, ~$10/mo, no install:
- Build the same STYLE BLOCK as a Midjourney prompt.
- Consistency: `--sref <url-or-id>` (style reference) on every asset, and
  `--cref <url>` (character reference) for a specific character across shots.
- Add `--no background, shadow, text` and request `plain grey background` (characters)
  or `plain white background` (props).
- Download, then run through `artkit process` exactly the same way.

Tradeoff: no LoRA-level lock and per-image cost, but zero technical setup and strong
cyber-anime quality out of the box with `--style raw` + style references.

---

## Cheat sheet

- **One look across the roster** = identical style block + seed + (eventually) a style LoRA.
- **A specific character on-model** = character LoRA or ControlNet reference-only.
- **Clean cutouts** = plain background, no drop shadow → `artkit process`.
- **Riggable characters** = T-pose, open/empty hands, separate props — see CHARACTER-GUIDE.md.
- **SDXL, not SD1.5**: better resolution, stronger anime/sci-fi quality, 16GB handles it.
- **Trigger word:** `cyber-anime swarm style` — prepend after LoRA is trained.
