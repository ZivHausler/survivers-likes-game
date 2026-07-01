# Visual QA Loop — screenshot-based self-iteration

**You are not done when the scene compiles.** You must visually inspect your own output
using screenshots, compare it against the art-direction brief, identify failures, and
iterate until the scene reaches production-quality visual standards.

The target is a polished top-down / isometric roguelite swarm arena, **not a prototype map**.

## This document is authoritative (added 2026-07-01)

The screenshot + its score is the source of truth for how the game looks. **Your
impression of your own work is not.** When they disagree, the screenshot wins — every
time, without exception. There is no move where you conclude "the scorer is unreliable"
or "the critic didn't see my improvements." That conclusion is banned: it is the same
rationalization as rewording an auto-fail into a strength, one level up. If a score
seems wrong, the resolution is *always* to open the exact scored PNG and look at it — not
to discount the number.

This rule exists because it already failed twice: once by self-scoring a greybox 87/100,
and once by dismissing an accurate 23/100 as "unreliable" while the builder believed
quality was improving. Both times the screenshot was right and the builder was wrong.

## Non-negotiable process rules (added 2026-07-01 after a false pass)

A prior run self-scored a flat, AI-textured greybox at 87/100 and shipped it. It failed a
human on sight. The gap was process, not effort. These rules are now mandatory:

1. **Grade the ABSOLUTE bar, never the delta.** The only question is "would this ship in a
   commercial game?" — never "is this better than the last version?" Improvement is not a
   passing grade. If you catch yourself citing the previous state as evidence, stop.
2. **Compare against the north-star references EVERY pass.** Open the shipped-game refs in
   `docs/superpowers/specs/assets/map-refs/` (LoL Swarm, Battlerite, Temtem) and score your
   screenshot *next to them*. Judging in isolation is how the 87 happened — the loop never
   once looked at the references it was supposedly targeting.
3. **The final gate is an INDEPENDENT adversarial reviewer, not self-assessment.** Before
   claiming a passing score, dispatch a fresh subagent that did NOT build the scene, give it
   the screenshots + the reference images + the auto-fail list, and instruct it to default to
   FAIL and be harsh. The builder's own score does not count as the gate. (See the
   adversarial-critic dispatch used on 2026-07-01.)
4. **Auto-fails are LITERAL and DISQUALIFYING.** If any auto-fail condition below is present,
   the scene fails and the score is capped at 55 — no matter how good anything else is. Do not
   reword an auto-fail into a strength ("harsh borders" → "clean trims", "sparse props" →
   "intentional open space"). If the words of the condition match what you see, it fails.

## More non-negotiable rules (added 2026-07-01 after dismissing an accurate score)

5. **Look at the EXACT scored PNG before forming any opinion.** Open the actual
   `res://_shots/*.png` (or `_progress_snapshots/*.png`) that was rendered this pass and view
   it *next to* the references. Never judge from the live editor viewport, from memory, or
   from close-up texture crops — those are different images than the one being scored, and the
   scored one is what ships. Your eyes and the scorer's must be on the same pixels.
6. **Grade the FRAME, not the asset.** A nice individual texture does not raise the score. The
   rubric scores the whole composition; the auto-fails (borders, centerpiece integration,
   greybox overview, prop density) dominate and cap it. Score those first. Being proud of one
   surface while the frame trips three auto-fails is exactly the trap.
7. **Monotonic score movement is SIGNAL, not noise.** If the score moves consistently in one
   direction as you change one variable, it is tracking a real effect of that change — follow
   it, do not dismiss it. (A score that fell as zone albedo was pushed toward near-white was
   correctly reporting that near-white multiply washed the floor into flat pale blobs.)
8. **The overview shot is a real gate.** If the full-map render looks like a small flat colored
   tile floating in empty background, that is a greybox and it fails — regardless of how the
   close-up reads. Do not exempt any camera angle from the auto-fail list.

## The loop (repeat until an INDEPENDENT reviewer scores ≥ 85/100)

1. Run the Godot scene (arena via `tools/screenshot.tscn`; HUD via `tools/hud_preview.tscn`).
2. Capture screenshots.
3. Analyze the screenshots visually.
4. Score the result using the rubric below.
5. Identify the top 5 visual problems.
6. Fix the highest-impact problems.
7. Run the scene again and take new screenshots.
8. Repeat until the score is at least **85/100**.

Do not stop after one attempt unless the screenshot clearly passes the rubric.

## Automatic failure (scene fails + score capped at 55 if ANY are true)

- Large flat colored terrain blobs are visible.
- **Flat textured planes with no 3D form** — zones all at one height, no curbs/walls/relief.
  A textured floor plane is still a greybox.
- Different floor types meet with harsh, ugly, straight borders.
- Props are sparse, tiny, random, or low quality.
- There are no meaningful prop clusters.
- The map looks like a prototype/greybox instead of a shipped game arena.
- **Floor/prop materials are stylistically inconsistent with each other** — e.g. painterly
  grass beside cartoon-ink-outlined cobble beside semi-photoreal stone. Mixed styles read as
  an asset-flip / AI-generated mashup. One locked treatment across every surface.
- **No real directional lighting** — flat ambient with no sun angle, no cast shadows, no
  ambient occlusion in seams/under props. Light is what creates 3D form; without it, flat.
- The HUD looks like debug UI.
- The floor has no tile / trim / decal variation.
- The central combat area has no integrated visual hierarchy (a flat pasted-on decal that
  doesn't glow or inlay into the floor does NOT count as hierarchy).
- **Visible AI-texture artifacts** — mushy/misaligned tile grout, obvious repeating tiling.
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
