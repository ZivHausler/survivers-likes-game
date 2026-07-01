# Visual Technical Standards — Friends Swarm (binding)

The project-wide technical/quality bar for all visual work. **Binding** alongside the north-star
visual identity (`docs/superpowers/specs/2026-06-30-lol-swarm-visual-identity-design.md`). Referenced
by the arena overhaul spec/plan and applies to every zone and asset going forward.

## Quality target

- Stylized **3D**, not pixel art. No pixel-art sprites. No low-resolution textures. No blurry AI textures.
- All assets must look clean **from the gameplay camera** distance.
- Target: polished stylized 3D with League Swarm / Temtem Swarm readability — not retro 2D.

## Rendering

- Use **3D meshes** (not 2D sprites) for characters, enemies, props, and environment objects.
- High-resolution textures where needed — typically **1024–2048 px** for important props/characters.
- Use **texture atlases** for small repeated props.
- Enable **anti-aliasing** in Godot (MSAA and/or FXAA).
- Use **mipmaps** correctly so textures do not shimmer or pixelate.
- Use **anisotropic filtering** for floor textures viewed at an angle.
- **Controlled bloom** only on emissive/neon details.
- **Ambient occlusion / contact shadows** to ground objects.
- Clean stylized materials with **strong color separation**.

## Camera

- Test all assets from the **actual gameplay camera** distance (MOBA-style ~ -65° angled top-down,
  `GameCamera3D`), not close-up only.
- Keep the camera far enough that medium-poly stylized assets look polished.
- Avoid zooming so close that AI mesh defects or blurry textures become obvious.

## Asset rules (AI → game pipeline)

- Hunyuan 3D (or any AI) output is a **starting point, not the final asset**.
- Every AI-generated model is cleaned in **Blender** before importing to Godot:
  - decimate messy geometry; fix UVs when needed; replace bad materials; simplify material slots;
    bake detail into clean textures; re-author blurry/ugly textures manually or with another pass;
    create **simple collision shapes manually**.
- Use consistent **scale, proportions, and color palette** across all assets.

## Style consistency

- Same **material families** across the whole game.
- Same bevel size, edge softness, texture sharpness, and glow intensity across all zones.
- Do **not** mix realistic, cartoon, pixel, and AI-noisy props in one scene.
- All zones share the same stylized 3D art direction (identities differ; DNA is shared — see spec §0.1).

## Environment quality

- Floors use **clean modular 3D tiles**, not stretched low-res images.
- Varied floor materials: pavement, grass, metal, stone, dirt, neon lines.
- Add **bevels or normal maps** to floor panels so they do not look flat.
- Props **clustered intentionally**, not scattered randomly.
- Each zone needs **landmarks, medium props, small details, and clear walkable paths**.

## Minimum visual bar (gate)

- Player instantly readable. Enemies instantly readable.
- Floor varied but not noisy. Props look intentional.
- Textures sharp from gameplay distance. Lighting gives depth.
- VFX bright but controlled. Nothing looks like pixel art unless intentionally designed so.

## Godot project settings implied by the above

- `rendering/anti_aliasing/quality/msaa_3d` = 2× or 4× (MSAA).
- `rendering/anti_aliasing/quality/screen_space_aa` = FXAA (optional, for edge cleanup).
- Texture import: **Mipmaps ON** for floor/prop albedos; **anisotropic** filter for angled floors.
- `rendering/textures/default_filters/anisotropic_filtering_level` ≥ 4.
- `WorldEnvironment`: SSAO or contact shadows on; glow/bloom threshold high enough to fire only on
  emissive accents.

## Change log

- 2026-07-01 — Created from user-provided technical/quality stack for the art-directed arena overhaul.
