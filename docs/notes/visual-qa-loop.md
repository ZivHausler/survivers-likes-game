# Visual QA Loop — screenshot-based self-iteration

**You are not done when the scene compiles.** You must visually inspect your own output
using screenshots, compare it against the art-direction brief, identify failures, and
iterate until the scene reaches production-quality visual standards.

The target is a polished top-down / isometric roguelite swarm arena, **not a prototype map**.

## The loop (repeat until score ≥ 85/100)

1. Run the Godot scene (arena via `tools/screenshot.tscn`; HUD via `tools/hud_preview.tscn`).
2. Capture screenshots.
3. Analyze the screenshots visually.
4. Score the result using the rubric below.
5. Identify the top 5 visual problems.
6. Fix the highest-impact problems.
7. Run the scene again and take new screenshots.
8. Repeat until the score is at least **85/100**.

Do not stop after one attempt unless the screenshot clearly passes the rubric.

## Automatic failure (scene fails if ANY are true)

- Large flat colored terrain blobs are visible.
- Different floor types meet with harsh, ugly borders.
- Props are sparse, tiny, random, or low quality.
- There are no meaningful prop clusters.
- The map looks like a prototype instead of a game arena.
- The HUD looks like debug UI.
- The floor has no tile / trim / decal variation.
- The central combat area has no visual hierarchy.
- The full-map screenshot looks like unrelated biome islands pasted together.

## Report format (write after EVERY screenshot review, verbatim format)

```
VISUAL QA REPORT

Overall score: __ / 100

Biggest visual failures:
1.
2.
3.
4.
5.

What is working:
1.
2.
3.

Required fixes for next iteration:
1.
2.
3.
4.
5.
```

Do not make random changes. Fix the most important art-direction problems first.

## Priority order (fix in this order)

1. Fix map structure and terrain transitions.
2. Add authored floor detail: trims, decals, tile variation.
3. Add prop clusters and landmarks.
4. Improve HUD hierarchy and readability.
5. Improve lighting, shadows, colors, and polish.

## Analysis checklist (ask yourself each pass)

**Map**
- Does this look like a real designed arena or a random terrain generator?
- Is there a strong central landmark?
- Are the districts connected naturally?
- Are paths and walkable areas clear?

**Floors**
- Are floor materials detailed enough at gameplay camera distance?
- Do transitions have trims, borders, dirt blending, cracks, grass creep, or decorative separators?
- Are there obvious harsh material boundaries?
- Are there giant empty flat areas?

**Props**
- Are props arranged in believable clusters?
- Does each biome have its own prop language?
- Are there enough medium and large props?
- Are small props supported by decals and shadows?
- Are props placed near paths, corners, landmarks, and edges instead of randomly?

**HUD**
- Can I instantly read HP, EXP, level, timer, kills, wave, and abilities?
- Does the HUD look designed or temporary?
- Are icons consistent? Are cooldowns visible?
- Is the UI too empty, too large, or too flat?

**Gameplay**
- Could enemies and projectiles remain readable on this background?
- Is the center too noisy or too empty?
- Does the scene still read well when zoomed out?

## Fix playbook

**If the floor looks bad:** replace large blobs with modular tile zones; add edge trims
between materials; add transition tiles; add cracks/stains/dirt/grass-creep/metal-seams/
engraved-lines/decals; use curved transitions instead of straight biome borders; add
variation tiles so repeated areas don't look flat.

**If props look bad:** create prop clusters instead of random scatter; add one large
landmark per zone; 3–6 medium props per zone; 10–25 small details per zone; place props
near corners/paths/walls/landmarks/themed areas; add shadows / contact grounding; add floor
decals around props.

**If the map composition looks bad:** create a central circular hub; connect 4–6 surrounding
districts through designed paths; give each district a readable silhouette; avoid disconnected
biome islands; keep the central combat area open but decorated with floor detail.

**If the HUD looks bad:** replace debug bars with styled translucent panels; add framed
ability icons; add cooldown rings/overlays; add HP and EXP bars with labels; add timer, wave,
kill count, minimap/radar, and boss bar; align UI elements consistently; avoid giant black
rectangles.

## Quality bar

The result should look like a vertical-slice screenshot from a real stylized roguelite/swarm
game. The player should instantly understand: where they can walk, where the central arena
is, what district they're in, where enemies come from, their HP / EXP / level, ability
cooldowns, kill count, timer, and boss/wave status. The map should feel dense, intentional,
and polished, while still being readable during fast combat.
