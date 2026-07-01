# Ability-icon & portrait generation

Self-contained SDXL pipeline for the HUD/upgrade-card ability icons and command-bar
character portraits. **Everything the repo needs lives here** — the generator script and
the per-character prompt manifests — and the finished PNGs land directly in
[`art/icons/`](../../art/icons/). Nothing from outside the repo is required except the
runtime (a WSL Python venv with `torch` + `diffusers`, and the cached DreamShaper-XL
weights — multi-GB, so not vendored).

## Layout

- `gen_icon.py` — batch generator. Loads DreamShaper-XL once, renders every item across all
  given manifests. Style/negative blocks are baked in per `kind` (`icon` | `portrait`).
- `manifests/<char>.json` — one file per character. Each item is
  `{"kind", "seed", "size_out", "subject", "out"}`. The `subject` is the only creative part;
  the shared "video game ability icon, glowing emblem, dark slate background, neon rim
  light, cel-shaded…" style is appended by the script.

## Convention (why no `.tres` edits are needed)

The HUD and upgrade cards auto-resolve art by path:

- ability icon → `art/icons/abilities/<skill_id>.png`
- portrait    → `art/icons/portraits/<char_id>.png`

So dropping a correctly-named PNG in is enough. `SkillData.icon` / `CharacterData.portrait`
still win if explicitly set. Text abbreviation is the fallback when no PNG exists.

Note: where an ultimate shares a skill's `id` (natali `comic_relief`, yuval `bass_drop`),
one icon serves both — the manifest only renders it once.

## Run (from WSL)

```sh
/root/sdgen/.venv/bin/python \
  /mnt/c/Users/avino/survivers-likes-game/tools/icons/gen_icon.py \
  --manifest /mnt/c/Users/avino/survivers-likes-game/tools/icons/manifests/*.json
```

Then let Godot import the new PNGs (`godot47 --headless --editor --quit`) and commit the
`art/icons/**` PNGs + `.import` files. Do **not** commit model weights, the venv, or any
1024px raw renders — the manifests write final 256/512px PNGs straight into `art/icons/`, so
there are no raw intermediates.
