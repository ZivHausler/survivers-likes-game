# LoL Swarm Weapon Re-Skin — Design Spec

**Date:** 2026-06-29
**Status:** Approved design, pending implementation plan
**Branch base:** `feature/holy-smite-vfx` (where the bespoke-VFX registry + descending-pillar template already exist; `main` does not have them)

## 1. Goal

Recreate **League of Legends: Swarm**'s weapon arsenal inside friends-swarm. Every existing skill slot adopts a Swarm weapon **wholesale** — its mechanic, its behavior, and its visual effect — recolored to the owning character's palette.

**Fidelity bar (hard requirement):** the effects must look like a *copy-paste of LoL Swarm* — AAA-grade juice. That means, per weapon: chunky bloom/glow, ring shockwaves on impact, anime-style "smear" impact frames, bright rim-lit projectiles that pop against the arena, screen shake on heavy hits, and clean telegraphs. "Recolored Nova/Orbit placeholder" does **not** meet the bar. Each weapon is its own bespoke, hand-tuned effect.

### Non-goals
- Character models / rigs (explicitly out of scope).
- Passive **visuals** — see §6. Swarm passives are stat-only; there is nothing visual to copy.
- New game systems beyond what each weapon's behavior requires.

## 2. Key decisions (locked with stakeholder)

| Decision | Choice |
|---|---|
| Relationship to existing roster | **Re-skin** — keep the ~50 slots, drop a Swarm weapon into each |
| Visuals vs behavior | **Full match** — recreate mechanic + behavior, not just the look |
| Theme/color | **Recolor per character** — import mechanic + VFX structure wholesale, tint each copy to the character palette |
| Spec scope | **Full mapping now + deep-spec one character (Avinoam) first**, rest phased |
| First deep-spec target | **Avinoam** |

## 3. Architecture

### 3.1 Two VFX channels

Swarm weapons need both transient and persistent visuals, so the design uses two channels:

**Channel 1 — Transient FX via the `skill_vfx.gd` registry.** Fire-and-forget effects keyed by `vfx_id` (cast bursts, hit sparks, descending pillars, impact shockwaves). Each effect is a scene honoring the `play_at(pos, color)` contract. Pattern already established by commit `08355e3`:

```gdscript
const _CAST_REGISTRY := { &"avinoam_holy_smite": _HolySmiteCastScene }
const _HIT_REGISTRY  := { &"avinoam_holy_smite": _HolySmiteHitScene }
# _on_skill_cast/_hit: scene = _CAST_REGISTRY.get(vfx_id, _SkillCastFxScene)
```

**Channel 2 — Persistent FX owned by the weapon scene.** Effects that live for the weapon's lifetime (sun-auras, orbiting bodies, pet models, rotating telegraphs, sustained beams, DoT trails). Authored into the weapon `.tscn` and driven by the weapon script. These cannot be fire-and-forget.

### 3.2 Color parameterization (makes "recolor per character" cheap)

> Build each of the 20 Swarm weapon VFX **once**, fully **color-driven**. Both channels accept a tint. A character's copy only sets its exported `vfx_color` (+ optional `vfx_color_secondary`). Same scene, different palette.
>
> **Result: 20 weapon VFX built, not 50.** Avinoam's Bunny Mega-Blast is gold; Yinon's is military-orange; Ido's is toxic-green — identical scene, different tint.

Implementation requirements:
- Bespoke transient scenes must derive their colors from the `play_at(pos, color)` argument, never hardcode.
- Persistent weapon-owned visuals must read an exported `vfx_color` (and secondary) and apply it to materials/particles at `_ready()`.
- Where a weapon needs two tones (e.g. core white + rim gold), the secondary is derived from `vfx_color` unless the character overrides it.

### 3.3 New mechanical archetypes required

The roster today is almost entirely `NovaWeapon3D` (AoE pulse at a point) and `OrbitWeapon3D` (bodies circling the player). Swarm's arsenal needs ~10 behaviors that don't exist yet. These are real gameplay engineering, not recolors:

| New behavior | Used by (Swarm weapon) | Suggested base |
|---|---|---|
| Random-target delayed orbital strike + telegraph | Bunny Mega-Blast, Searing Shortbow | `OrbitalStrikeWeapon3D` |
| Directional / dual-direction projectiles | Lioness's Lament, Battle Bunny Crossbow | `ProjectileWeapon3D` |
| Persistent damaging aura | Radiant Field | `AuraWeapon3D` |
| Rotating spiral emitter | Vortex Glove | `SpiralEmitterWeapon3D` |
| Chain / bounce between enemies | Statikk Sword, Anti-Shark Sea Mine, Echoing Batblades | `ChainWeapon3D` |
| Boomerang (out-and-back) | Blade-o-rang | `BoomerangWeapon3D` |
| Ground-pool / mine DoT zones | Searing Shortbow, Ani-Mines | `GroundZoneWeapon3D` |
| Poison trail behind player | Paw Print Poisoner | `TrailWeapon3D` |
| Cone DoT stream | Gatling Bunny-Guns | `ConeStreamWeapon3D` |
| Autonomous pet AI | T.I.B.B.E.R.S, YuumiBot | `PetWeapon3D` |
| Vehicle line-sweep | Final City Transit | `VehicleWeapon3D` |
| Frost-shell block + nova | Iceblast Armor | `ShellNovaWeapon3D` |

### 3.4 Asset / shader strategy (required to hit the fidelity bar)

The `godot_vfx` addon already ships reusable building blocks we should lean on:
- **Particle scenes:** `energy_burst`, `lightning_chain`, `combo_ring`, `magic_aura`, `summon_circle`, `sparks`, `dash_trail`, `portal_vortex`, `fireball_trail`, `poison_cloud`, `ice_frost`, `shield_break`, `heal_particles`.
- **Shaders:** `outline_glow`, `flash_white`, `chromatic_aberration`, `radial_blur`, `dissolve`, `energy_barrier`, `heat_distortion`, `frozen`, `poison`, `burning`, `color_change`, `blink`.

Fidelity techniques to standardize across all weapons:
- Additive/emissive materials with `emission_energy_multiplier` ≥ 3 for the bloom-heavy Swarm look.
- Ground **ring shockwave** decals (expanding scaled torus/quad with `outline_glow` + alpha fade) on every heavy impact.
- Short **smear/flash** frame (`flash_white` quad billboard) at the moment of impact.
- `Juice3D.add_shake` (public hook from commit `964d42e`) scaled to impact weight.
- Pets / train / large props that lack a model use a **stylized stand-in** (emissive primitive silhouette + glow) until/unless real models are added — flagged per weapon.

## 4. Full mapping (all ~50 slots → Swarm weapons)

Ults map to Swarm's **evolved/awakened** forms. Each weapon is reused ~2–3× across characters, recolored per palette.

### Avinoam ⭐ (deep-spec target) — palette: gold `(1.0,0.84,0.30)`, core white `(1.0,0.97,0.85)`, amber `(1.0,0.62,0.17)`
| Slot | Current | → Swarm weapon |
|---|---|---|
| holy_smite (sig) | Nova | Bunny Mega-Blast |
| judgment | Nova | Lioness's Lament |
| radiant_pulse | Nova | Radiant Field |
| smite_orbs | Orbit | Vortex Glove |
| ult judgment_day | Ult | The Annihilator → Animapocalypse |

### Other characters (phased deep-spec)
| Character | Slots → Swarm weapons |
|---|---|
| **Avihay** | spam→UwU Blaster · voice_blast→Gatling Bunny-Guns · group_call→Cyclonic Slicers · mass_dm→Vortex Glove · ult→YuumiBot (evolved) |
| **Barak** | loyal_hounds→T.I.B.B.E.R.S · fetch→Blade-o-rang · howl→Iceblast Armor · pack_tactics→Cyclonic Slicers · ult→Tibbers B.E.E.G (evolved) |
| **Ido** | toxic_cloud→Paw Print Poisoner · corrosion→Searing Shortbow · miasma→Radiant Field · venom_orbs→Vortex Glove · ult→Bearfoot Chem-Dispenser (evolved) |
| **Matan** | pestering_swarm→Echoing Batblades · annoyance_orbit→Cyclonic Slicers · irritation_aura→Radiant Field · outburst→Ani-Mines · ult→Neverending Mobstomper (evolved) |
| **Natali** | giggle_burst→Bunny Mega-Blast · laughter→Statikk Sword · comic_relief→Lioness's Lament · joy_orbit→Vortex Glove · ult→The Annihilator |
| **Yinon** | airstrike→Bunny Mega-Blast · bombardment→Searing Shortbow · cluster_bomb→Ani-Mines · rocket_barrage→Battle Bunny Crossbow · ult→Tri-Namite (evolved) |
| **Yoav** | drive_by→Final City Transit · delivery_orbit→Vortex Glove · express_run→Anti-Shark Sea Mine · hot_meal→YuumiBot · ult→FC Limited Express (evolved) |
| **Yuval** | soundwave→Lioness's Lament · bass_drop→Iceblast Armor · echo_orbit→Vortex Glove · resonance→Radiant Field · ult→The Annihilator |
| **Ziv** | mirror_shards→Echoing Batblades · charm→Iceblast Armor · selfie_flash→Bunny Mega-Blast · adoring_aura→Radiant Field · ult→The Annihilator |

**Character palettes (to be finalized at each character's phase):** Avihay = social blue; Barak = pack amber/brown; Ido = toxic green; Matan = pest yellow-green; Natali = joy magenta/rainbow; Yinon = military orange; Yoav = delivery red/chrome; Yuval = bass cyan/purple; Ziv = charm pink.

## 5. Avinoam deep-spec (frame-level)

All five must hit the §1 fidelity bar. Colors below use Avinoam's palette; the same scenes serve other characters via `vfx_color`.

### 5.1 Holy Smite → Bunny Mega-Blast (signature)
- **Mechanic:** every cooldown (7→4s by level), select N random enemies in range (targets 2→4 by level). At each, draw a ~0.5s ground telegraph, then slam a vertical strike dealing AoE damage at that point. Base: `OrbitalStrikeWeapon3D`.
- **Channel 2 (telegraph):** gold ring decal on the ground at each target — thin bright ring that pulses/contracts over 0.5s (`outline_glow`), with a faint downward light cone hinting the incoming strike.
- **Channel 1 (impact, reuses commit `dc6f246` pillar):** descending gold→white light pillar (tall cylinder, additive, bright white core / gold rim), lands in ~0.12s; on land: expanding gold ring shockwave decal (scale 0→full over 0.25s, alpha fade), radial gold spark burst (`sparks`/`energy_burst`), one `flash_white` smear billboard, `Juice3D.add_shake` (light).
- **Wiring:** `vfx_id = &"avinoam_bunny_megablast"`; register pillar in `_HIT_REGISTRY`; telegraph owned by weapon.
- **Evolved (Rapid Rabbit Raindown):** a rolling barrage of strikes over ~1.25s ending in one oversized blast.

### 5.2 Judgment → Lioness's Lament
- **Mechanic:** every ~0.53s, fire crescent projectiles horizontally in two opposite directions, alternating; piercing; beams 2→4 by level. Base: `ProjectileWeapon3D`.
- **Channel 2 (projectile):** white-gold crescent (crescent-shaped mesh or alpha quad), additive glow + soft lens-flare sparkle at the tips, thin ribbon trail (`dash_trail`-style), gentle scale pulse as it travels.
- **Channel 1 (hit):** brief gold slash spark + tiny ring tick.
- **Wiring:** `vfx_id = &"avinoam_lioness_lament"`.
- **Evolved (Enveloping Light):** replace crescents with solid sustained horizontal light beams both directions (`energy_barrier`-style emissive beam mesh).

### 5.3 Radiant Pulse → Radiant Field
- **Mechanic:** persistent aura around the player, ticks ~0.26s, radius + damage scale with Max HP. Base: `AuraWeapon3D` (continuous Area3D, replaces the current pulsed nova).
- **Channel 2 (persistent):** warm gold sun-aura disc on the ground (`magic_aura` recolored), slow-rotating inner glyph, pulsing additive rim ring, rising gold light motes (`fireflies` recolored). Subtle heat-haze (`heat_distortion`) at the rim for the "solar" read.
- **Channel 1 (tick):** tiny gold flicker on each enemy hit (cheap — many ticks).
- **Wiring:** `vfx_id = &"avinoam_radiant_field"`; aura node lives in weapon scene, tinted by `vfx_color`.
- **Evolved (Explosive Embrace):** enemies dying inside the field erupt in a secondary gold burst.

### 5.4 Smite Orbs → Vortex Glove
- **Mechanic:** continuous stream of piercing orbs from a launch point that rotates clockwise (a sprinkler of light); orbs 1→3 by level. Base: `SpiralEmitterWeapon3D`.
- **Channel 2 (orbs):** glowing gold-white energy spheres (sphere mesh, additive, bright core), each with a short comet trail, emitted along the rotating angle so they form a readable spiral arc.
- **Channel 1 (hit):** small orb-pop spark.
- **Wiring:** `vfx_id = &"avinoam_vortex_glove"`.
- **Evolved (Tempest's Gauntlet):** add a second counter-rotating spiral (double helix).

### 5.5 Ult Judgment Day → The Annihilator (Animapocalypse)
- **Mechanic:** long-cooldown screen-clear (`UltimateWeapon3D`). ~3s telegraph, then a colossal strike clears a large area. Evolved showers large XP gems.
- **Channel 2 (charge):** giant slow-rotating gold rune / targeting circle on the ground (layered glyph rings via `summon_circle` + `portal_vortex`), rising columns of light, intensifying glow over the 3s charge.
- **Channel 1 (detonation):** colossal light pillar/hammer; screen-wide white flash (`flash_white` on a CanvasLayer); massive expanding gold ring shockwave decal; brief `radial_blur` + `chromatic_aberration` punch; heavy `Juice3D.add_shake`.
- **Wiring:** `vfx_id = &"avinoam_annihilator"`.

## 6. Passives

LoL Swarm passives are **pure stat cards** (Max Health, Damage, Crit, Area Size, Ability Haste, Duration, etc.) with **no on-screen VFX** — the spectacle lives entirely in weapons and their evolutions. friends-swarm passives (`effect_kind`/`effect_value` upgrade cards) are already stat-only, so they **already match** and need **no visual work**. The only indirect "passive visuals" are emergent: Area Size → bigger AoEs, Projectile Count → more projectiles, Crit → more/bigger crit pops. No changes required.

## 7. Phasing

1. **Phase 0 — Foundations:** color-parameterization plumbing (`vfx_color`/secondary on persistent FX), shared fidelity helpers (ring-shockwave decal, smear/flash billboard, shake scaling), and the first batch of new base archetypes needed by Avinoam (`OrbitalStrikeWeapon3D`, `ProjectileWeapon3D`, `AuraWeapon3D`, `SpiralEmitterWeapon3D`).
2. **Phase 1 — Avinoam (vertical slice):** build all 5 weapons (mechanic + Channel 1/2 VFX) to the fidelity bar. Proves the pattern end-to-end.
3. **Phases 2–10 — remaining characters:** each phase = one character, reusing the 20 color-parameterized weapon VFX + remaining base archetypes (chain, boomerang, ground-zone, trail, cone, pet, vehicle, shell-nova). Order TBD; Yinon (tightest thematic fit) or Barak (hardest behaviors, de-risk early) are good seconds.

## 8. Risks / open items

- **Scope:** ~10 new mechanical archetypes + 20 bespoke high-fidelity VFX. This is large; the vertical slice gates the rest.
- **Asset gap:** pets (Tibbers, Yuumi), the train, and crescent/bunny-gun shapes want real models/textures for true copy-paste fidelity. Phase 1 (Avinoam) is model-light (pillars, auras, orbs, beams) — deliberately chosen so we validate the VFX pipeline before committing to model work.
- **Performance:** persistent auras + many projectiles + heavy additive bloom across 50 abilities. `perf_monitor.gd` is in the tree; budget per-weapon particle counts and add pooling if needed.
- **Branch:** implementation should build on `feature/holy-smite-vfx`. The bespoke registry + pillar template are not on `main`.
- **Legal/IP:** this recreates a third-party game's content for a personal/fan project; that's the stakeholder's call and out of scope for this design.
