#!/usr/bin/env python
"""Batch SDXL generator for game ability ICONS and character PORTRAITS.

Reads one or more JSON manifests (each a list of items) and renders them all in
a single model load. Each item: {"subject": str, "out": str, "kind":
"icon"|"portrait", "seed": int, "size_out": int}. The style block per kind is
baked in so the manifest only carries the subject + destination.

The heavy runtime (torch + diffusers + the DreamShaper-XL weights) lives in the
WSL venv; only THIS script + the manifests are version-controlled in the game
repo. Run it from WSL, e.g.:

  /root/sdgen/.venv/bin/python \
    /mnt/c/Users/avino/survivers-likes-game/tools/icons/gen_icon.py \
    --manifest /mnt/c/Users/avino/survivers-likes-game/tools/icons/manifests/*.json
"""
import argparse
import gc
import json
import os
import sys

import torch
from diffusers import StableDiffusionXLPipeline, DPMSolverMultistepScheduler

ICON_STYLE = (
    "{subject}, video game ability icon, single centered glowing emblem, "
    "dark slate radial gradient background, neon rim light, cel-shaded, "
    "bold clean shapes, high contrast, crisp, polished game UI icon"
)
PORTRAIT_STYLE = (
    "{subject}, character portrait bust, head and shoulders, stylized cyber-anime, "
    "strong neon rim light, dark vignette background, centered, heroic, clean, polished"
)
NEG_ICON = (
    "text, words, letters, numbers, watermark, signature, ui buttons, grid of icons, "
    "multiple emblems, collage, tiled pattern, many small objects, repeated, "
    "phone app screenshot, multiple screens, border, frame, photo, realistic, blurry, "
    "noisy, cluttered, deformed"
)
NEG_PORTRAIT = (
    "text, watermark, extra limbs, extra heads, deformed, bad anatomy, blurry, "
    "low contrast, cluttered background, full body, tiny, multiple people"
)

PRIMARY_MODEL = "Lykon/dreamshaper-xl-1-0"
FALLBACK_MODEL = "stabilityai/stable-diffusion-xl-base-1.0"


def load_pipe(model_id):
    try:
        print(f"Loading model: {model_id}", flush=True)
        pipe = StableDiffusionXLPipeline.from_pretrained(
            model_id, torch_dtype=torch.float16, use_safetensors=True
        )
    except Exception as e:
        print(f"  failed ({e}); falling back to {FALLBACK_MODEL}", flush=True)
        pipe = StableDiffusionXLPipeline.from_pretrained(
            FALLBACK_MODEL, torch_dtype=torch.float16, use_safetensors=True
        )
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(
        pipe.scheduler.config, use_karras_sigmas=True, algorithm_type="dpmsolver++"
    )
    return pipe.to("cuda")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True, nargs="+",
                    help="One or more manifest JSON files (each a list of items).")
    ap.add_argument("--steps", type=int, default=32)
    ap.add_argument("--cfg", type=float, default=7.0)
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--model", default=PRIMARY_MODEL)
    ap.add_argument("--skip-existing", action="store_true",
                    help="Skip items whose output PNG already exists (resume a batch).")
    args = ap.parse_args()

    if not torch.cuda.is_available():
        print("ERROR: CUDA not available to torch.", file=sys.stderr)
        sys.exit(1)

    items = []
    for path in args.manifest:
        with open(path) as f:
            items.extend(json.load(f))
    print(f"Loaded {len(items)} item(s) from {len(args.manifest)} manifest(s).", flush=True)

    pipe = load_pipe(args.model)
    for it in items:
        if args.skip_existing and os.path.exists(it["out"]):
            print(f"SKIP (exists) {it['out']}", flush=True)
            continue
        kind = it.get("kind", "icon")
        style = PORTRAIT_STYLE if kind == "portrait" else ICON_STYLE
        neg = NEG_PORTRAIT if kind == "portrait" else NEG_ICON
        prompt = style.format(subject=it["subject"])
        seed = int(it.get("seed", 12345))
        print(f"[{kind}] {it['out']}\n  {prompt}", flush=True)
        gen = torch.Generator(device="cuda").manual_seed(seed)
        image = pipe(
            prompt=prompt, negative_prompt=neg,
            num_inference_steps=args.steps, guidance_scale=args.cfg,
            width=args.size, height=args.size, generator=gen,
        ).images[0]
        size_out = int(it.get("size_out", 256))
        if size_out and size_out != args.size:
            from PIL import Image
            image = image.resize((size_out, size_out), Image.LANCZOS)
        image.save(it["out"])
        print(f"SAVED {it['out']}", flush=True)
        # Free per-image VRAM so a long batch doesn't fill the GPU and spill into
        # (very slow) shared system RAM. Without this, SDXL's cached activations
        # accumulate across images until the driver pages over PCIe.
        del image
        gc.collect()
        torch.cuda.empty_cache()
    print("BATCH_DONE", flush=True)


if __name__ == "__main__":
    main()
