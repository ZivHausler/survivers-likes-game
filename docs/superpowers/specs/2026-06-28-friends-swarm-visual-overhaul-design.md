# Friends Swarm — Visual Overhaul Design Spec

**Date:** 2026-06-28 · **Realigned:** 2026-06-30 to the LoL Swarm visual identity
**Engine:** Godot 4.7 (GDScript), tilted-perspective **3D** (post 3D-pivot)
**North star:** [LoL Swarm Visual Identity](2026-06-30-lol-swarm-visual-identity-design.md) — the authoritative art-direction reference. This spec is *how we hit that target* in our actual engine and pipeline.
**Related:** [3D Pivot & Feature Expansion plan](../plans/2026-06-29-3d-pivot-and-feature-expansion.md) · [LoL Swarm Weapon Re-Skin](2026-06-29-lol-swarm-weapon-reskin-design.md)

> **History.** This doc originally (2026-06-28) specified a *2D* placeholder→sprite overhaul. The project has since pivoted to **3D**. This realignment retargets it to the **neon cyber-anime LoL Swarm** identity in 3D. The 2D-era sprite/tilemap content is superseded; the **decoupling principle** below is unchanged and still load-bearing.

## 1. Goal

Transform the game's current look — Kenney blocky humanoids, Quaternius monsters, flat `StandardMaterial3D` colors, basic particle juice — into the **bright cyber-fantasy chaos** of League of Legends: Swarm: colorful cyber-anime champions carving through dense purple/blue alien waves in a clean neon sci-fi arena, with saturated additive VFX and a dark readable HUD.

The target look, palette, shape language, and per-layer rules are fully defined in the **north star** doc. This spec defines the **production strategy, architecture, locked decisions, and success criteria** to get there.

## 2. Guiding Principle (unchanged — still load-bearing)

**Game logic is tested and working — visuals are a decoupled presentation layer, not a rewrite.** We do not change the run loop, upgrade/evolution/synergy systems, spawning, multi-skill routing, or collision rules. The GUT logic suite (220+ currently) MUST stay green throughout. Visuals attach in three decoupled ways only:

1. **A render/VFX/juice layer** that listens to existing `GameEvents` signals and applies materials/shaders/effects (no logic coupling) — e.g. `Juice3D`, `SkillVFX`.
2. **Per-`*Data` model swaps** — `CharacterData.model_scene` / `EnemyData.model_scene` already isolate visuals from logic; remaking an asset means swapping a `.glb`/material, never touching mechanics.
3. **Project-wide render settings** — `WorldEnvironment`, shaders, and a palette resource, all reversible.

The render/VFX layer must remain **removable**: disabling it reverts to plain logic with no errors — the proof of decoupling.

## 3. Production reality (what we actually build with)

We own a working **local AI→3D pipeline** at `C:\Users\avino\swarm\artkit\` (separate repo). See its `CHARACTER-GUIDE.md` / `WORKFLOW.md`. Capabilities and **hard edges**:

| Need | Pipeline path | Status |
|---|---|---|
| **Humanoid characters** (10 friends) | SDXL concept (T-pose, empty hands) → Hunyuan3D-2.1 mesh+PBR → Mixamo auto-rig → `finalize_character.py` → `.glb` (idle/walk/run) | ✅ Works (proven on UwU soldier) |
| **Weapon / hand props** | SDXL concept (isolated) → Hunyuan → attach to `mixamorig:RightHand` via `BoneAttachment3D` | ✅ Works |
| **Environment props** (sci-fi structures, barriers, machinery) | SDXL concept → Hunyuan → Blender cleanup → static `.glb` | ✅ Works |
| **Tiling ground textures** | `gen_texture.py` (circular-padding seamless SDXL) → Terrain3D / material | ✅ Works |
| **Alien enemies (non-humanoid)** | Hunyuan can make the *mesh*, but **Mixamo auto-rig is humanoid-only** — no skeletal walk for bugs/serpents | ⚠️ Hard edge — see §5.3 |
| **The neon "LoL Swarm" look itself** | **In-engine** shaders + bloom + palette + VFX | ❌ Does not exist yet — biggest gap, biggest ROI (§5.1) |

**Key insight:** the LoL Swarm identity is ~70% **render layer**, ~30% geometry. The game has **zero custom shaders** today and the `addons/godot_vfx` library (24 shaders incl. dissolve, outline_glow, energy_barrier) is **dormant**. The single highest-leverage work is the in-engine stylized render layer — it makes even *current* geometry read as LoL Swarm.

## 4. Locked Decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| VO-1 | Overall strategy | **3-layer remake** (render/VFX → assets → UI), §5 | Render layer is the cheapest, highest-impact lever |
| VO-2 | Sequencing | **Pilot one character end-to-end first**, then fan out | Proves the full chain + the look on a vertical slice before heavy asset gen; explicit go/no-go gate |
| VO-3 | Enemy visuals | **Both, phased** — recolor + emissive + dissolve existing CC0 monsters first; then progressively replace key enemies/bosses with generated alien Primordian meshes | Keeps real animation cheaply now; upgrades silhouettes where it matters |
| VO-4 | artkit style guides | **Add a cyber-anime prompt pack** to artkit (`STYLE-GUIDE`/`PROMPTS`), derived from north-star §17; keep the old cute-chibi pack as deprecated alternate | The pipeline currently produces cute pastel chibi — the opposite style; must be retargeted or it makes the wrong assets |
| VO-5 | Camera | Keep the **fixed** tilted-perspective view (~-55°/-65°, drag-rotate already removed) | Matches LoL Swarm's fixed combat-board framing |
| VO-6 | Decoupling | Render/VFX layer stays **signal-driven + removable**; tests stay green | §2 |

## 5. Architecture — the three layers

### 5.1 Layer 1 — In-engine stylized render & VFX (do first)

Where the neon identity actually lives. All additive to existing scenes, all reversible.

- **Stylized material/shader set** (`.gdshader`): cel + rim-light + screen-space-ish outline for characters/enemies; emissive-mask channel for sci-fi accents; **dissolve-death** shader for enemy deaths (north-star §11). Activate/adapt the dormant `godot_vfx` shaders where they fit.
- **Post-processing:** `WorldEnvironment` **glow/bloom** tuned so emissive VFX bloom but the ground stays calm; subtle SSAO/contact shadows; controlled exposure (north-star §7). Bright, low-contrast, gameplay-readable — no dramatic darkness.
- **Palette system:** the north-star §8 palette as a single project resource (`palette.tres` or autoload) mapping roles → colors (player VFX cyan/gold, enemies purple/blue/magenta, danger red/orange, pickups green/blue/yellow, environment muted neutrals). Existing per-instance materials and `skill_vfx`/`xp_gem` tiers read from it.
- **VFX hierarchy** (north-star §11): player effects powerful (cyan/gold), enemy attacks readable (purple/magenta), **boss telegraphs override** background noise, AoE **telegraph decals** for nova/orbit/ground skills, dissolve deaths, impact flashes. Built on the existing decoupled `SkillVFX`/`Juice3D` registries.
- **Lighting pass:** bright ambient + soft shadows, neutral ground, emissive sci-fi accents as the drama.

### 5.2 Layer 2 — Asset regeneration via artkit

On-theme geometry, produced by the pipeline (§3), consumed via the existing `*Data.model_scene` swap points (zero logic change).

- **10 cyber-anime friends:** per-friend SDXL concept (cyber-anime hero, animal/tech motif, palette accent) → Hunyuan → Mixamo rig → `.glb`; weapon prop attached to the right hand. Tints/accents per character via the palette.
- **Modular sci-fi arena ("Final City"):** seamless ground textures (asphalt / sci-fi pavement / neon-accent zones) via `gen_texture.py`; Hunyuan props (barriers, circular structures, machinery); replace the grassland with readable combat-board zones (north-star §5). Keep navigation/obstacle collision behavior intact.
- **Enemy restyle (VO-3 phased):** Phase A recolor+emissive+dissolve the existing monsters to the Primordian palette; Phase B generate alien meshes for bosses + 2–3 key enemy archetypes (static mesh + procedural wobble/shader motion).

### 5.3 Layer 3 — 2D / UI art

- **Dark sci-fi HUD theme** (north-star §12): dark panels, bright icons, readable HP/XP bars, ultimate-cooldown HUD, upgrade-choice cards. Godot `Theme` + `StyleBox`.
- **Ability / upgrade-card / passive icons:** SDXL 2D pipeline (`gen.py` + `artkit process`) in the cyber-anime style; painterly icon language.
- **XP-tier orb glow** and pickup readability driven by the palette.

## 6. Scope

**In scope:** all six asset classes — characters (10), enemies + bosses, environment/arena, VFX, UI/HUD, pickups/projectiles — plus the in-engine render layer and the artkit cyber-anime prompt pack.

**Out of scope:** gameplay/logic changes; audio; the 2D-era sprite/tilemap approach (superseded); any single specific-grip two-handed weapon pose beyond what `BoneAttachment3D` + a stock grip gives (artkit Stage 4B is opt-in per hero asset).

## 7. Cross-repo note

This is the **consumer** repo. Asset *production* (prompts, Hunyuan, Mixamo, Blender, the cyber-anime pack — VO-4) happens in `C:\Users\avino\swarm\artkit\`, which has its own specs/plans. Finished `.glb`/texture/icon assets are copied into this repo's `art/` and wired via `*Data` resources. The implementation plan spans both repos and must say which repo each task touches.

## 8. Testing

- The full GUT **logic** suite stays green (220+); no logic file changed by visual work.
- **Structural/headless tests:** `godot --headless --import` + `--headless --quit` load `main_3d.tscn` with zero errors after each visual change; shaders/materials compile; the render/VFX layer connects to `GameEvents` without touching logic; disabling the layer reverts cleanly.
- **Asset-license tracking:** every generated/sourced asset recorded in `docs/notes/asset-licenses.md` (artkit-generated assets are ours; note any base-model/tooling licenses).
- **Visual quality = human playtest** (headless can't see pixels): an updated `docs/notes/how-to-playtest.md` checklist per the north-star per-layer rules (readability under swarm density, palette role-separation, telegraph clarity, no VFX hiding the player/ground).

## 9. Success Criteria

- The game reads as **neon cyber-anime LoL Swarm**: emissive/rim/outline materials + bloom, the §8 palette enforced by role, dissolve enemy deaths, readable AoE telegraphs, dark sci-fi HUD.
- The **pilot vertical slice** (VO-2) demonstrates the full chain end-to-end: render layer + one regenerated cyber-anime friend + recolored Primordian enemies + one sci-fi arena zone — and is the approved gate for fan-out.
- All 10 friends, the enemy roster (recolored; key ones/bosses regenerated), and the arena are remade to the identity.
- The artkit cyber-anime prompt pack exists and reproducibly yields on-style assets.
- Logic suite green; `main_3d.tscn` loads cleanly; the visual layer is removable.

## 10. Build Approach

Subagent-driven (per the 3D-pivot plan's method): each task = implementer subagent → reviewer (spec + quality) → fix loop, logic suite kept green, atomic commits, Zettelkasten notes + `INDEX.md` updated, `HANDOFF.md` after each wave. Asset-gen tasks run against the artkit repo; integration tasks against this repo. Detailed phasing lives in the implementation plan (next deliverable, via writing-plans).
