# Ranged & Dasher Enemy Archetypes — Design Spec

> Date: 2026-06-29 · Branch: `feature/v1-vertical-slice` · Status: approved for planning

## Goal

Add enemies that threaten the player beyond melee contact: **ranged attackers**
(archers / magicians that keep distance and fire dodgeable projectiles) and
**gap-close dashers** (hold back, telegraph, then lunge). Delivered as a reusable,
data-driven enemy-attack system so new variants are authored as data, not code.

Today every enemy is melee-only: `Enemy3D` deals damage only within
`CONTACT_RANGE` (1.5u). `EnemyData.is_ranged` exists and `spitter.tres` sets it, but
ranged enemies merely stop at `RANGED_STANDOFF` (6u) and **never attack** — they
stand there harmlessly. This feature makes ranged enemies actually fire, adds the
dasher archetype, and keeps the melee behavior intact.

## Decisions (locked during brainstorming)

| Question | Decision |
|---|---|
| Archetypes | **Both** — RANGED (projectile) and DASHER (gap-close), via one reusable system. |
| Ranged delivery | **Travelling projectile, dodgeable, BLOCKED by terrain** (trees/rocks/walls are cover). |
| Concrete variants / assets | **Source new CC0 archer + magician models** for the ranged variants (fallback: tinted existing model if sourcing fails); ship a dasher too. |
| Architecture | **Attack-behavior strategy component** per enemy (keeps `enemy_3d.gd` lean, each archetype testable in isolation). |
| Fairness | Both ranged fire and dash have a short **wind-up telegraph** — no instant unavoidable hits. |

## Current state (verified)

- `enemies/enemy_data.gd` (`EnemyData`): `id, color, max_hp, move_speed, contact_damage,
  xp_value, is_ranged, radius, model_scene, model_scale, model_y_offset`.
- `enemies/enemy_3d.gd` (`Enemy3D`, `CharacterBody3D`): `_physics_process` steers toward
  target, applies RVO/collision-slide movement, and deals `contact_damage` within
  `CONTACT_RANGE`. `is_ranged` only zeroes desired speed inside `RANGED_STANDOFF`.
- Projectile reference pattern: `weapons/bubble_3d.gd` (`Bubble3D`, `Area3D`) — travels
  along an XZ direction, `body_entered` → hit, pierce/no-double-hit.
- Player: `Player3D` body layer 1 / mask 16; **`Hurtbox` `Area3D` layer 2 / mask 0**;
  `take_damage(amount)` respects i-frames (`is_invulnerable()`).
- Spawner: `spawning/spawner_3d.gd` `_variants = {swarmer, tank, spitter}`, spawns from
  `DifficultyTimeline.state_at(t).allowed_variants` each interval.
- Gating (`spawning/difficulty_timeline.gd`): `t<60 → [swarmer]`; `t≥60 → +tank`;
  `t≥120 → +spitter`.
- Physics layers: player body 1, player hurtbox 2, bubble 3, enemy 4 (`collision_layer=8`),
  obstacles/walls/water 5 (`=16`). Skills don't mask 16.

## Architecture: attack-behavior strategy

`EnemyData` gains `attack_kind`. `Enemy3D.setup()` instantiates one attack-behavior
object for that kind and stores it; `_physics_process` delegates to it via a single
`attack_tick(dt)` call. The behavior owns both the **movement shaping** (kite / dash)
and the **attack** (fire / lunge) for its archetype. Melee's existing logic is
extracted into `MeleeAttack` so all three share one path and `enemy_3d.gd` stops
branching on behavior.

```
Enemy3D._physics_process(dt):
  (charm / target-validity guards as today)
  desired = _attack.desired_velocity(self, target, dt)   # kite/approach/dash/chase
  velocity = desired ; _apply_movement(dt)               # existing RVO+fallback move
  _attack.attack_tick(self, target, dt)                  # fire / dash-hit / contact
```

Files (new, small, focused — under `enemies/attacks/`):
- `enemy_attack.gd` — `EnemyAttack` base: `desired_velocity(enemy, target, dt) -> Vector3`,
  `attack_tick(enemy, target, dt) -> void`. Default = chase + melee contact.
- `melee_attack.gd` — `MeleeAttack`: today's chase + `CONTACT_RANGE` contact damage
  (behavior-preserving extraction).
- `ranged_attack.gd` — `RangedAttack`: kite to `attack_range`; when in range + LOS +
  off cooldown → `windup_time` telegraph → spawn `EnemyProjectile3D` at the player.
- `dash_attack.gd` — `DashAttack`: approach to `dash_trigger_range`; telegraph
  `dash_windup`; dash toward the player's position at `dash_speed` for `dash_duration`
  (contact deals `contact_damage`); then `dash_cooldown`. State machine: APPROACH →
  WINDUP → DASH → COOLDOWN.

`Enemy3D` maps `attack_kind` → behavior in `setup()`. Back-compat: `is_ranged == true`
with `attack_kind == MELEE` maps to `RANGED` so existing data/tests don't break.

## Data model (`EnemyData` additions)

- `attack_kind: int` — enum `AttackKind { MELEE = 0, RANGED = 1, DASHER = 2 }`, default `MELEE`.
- Ranged: `attack_range: float = 12.0`, `attack_cooldown: float = 2.0`,
  `windup_time: float = 0.4`, `projectile_speed: float = 16.0`,
  `projectile_damage: float = 6.0`.
- Dasher: `dash_trigger_range: float = 14.0`, `dash_windup: float = 0.5`,
  `dash_speed: float = 30.0`, `dash_duration: float = 0.35`, `dash_cooldown: float = 2.5`.
- (`contact_damage`, `move_speed`, `radius`, model fields reused as-is.)

All values are playtest-tunable defaults; concrete variants override in their `.tres`.

## `EnemyProjectile3D` (new — `Area3D`, modeled on `Bubble3D`)

- `setup(direction, speed, damage)`; travels along the XZ `direction` each physics frame.
- **Collision mask = layer 2 (player hurtbox) + layer 16 (obstacles/walls)**:
  - Player hurtbox (`area_entered`) → `player.take_damage(damage)` (i-frames respected),
    then free.
  - Obstacle/wall (`body_entered`, layer 16) → free (terrain is cover).
  - Never masks layer 8 → cannot hit other enemies; never masks ground.
- Lifetime cap (despawn after N seconds / max distance) so strays don't accumulate.
- Spawned into the arena (the enemy's parent / a projectiles container), **not** parented
  to the firing enemy (so it persists if the enemy dies).
- Pure `_advance(dt)` method (like `Bubble3D`) for headless unit testing of travel.

## Line-of-sight / cover

`RangedAttack`, before firing, casts a ray enemy→player against **layer 16** via
`PhysicsRayQueryParameters3D` on the enemy's `get_world_3d().direct_space_state`.
Blocked → hold fire and reposition (steer toward a clear angle / sidestep). The
projectile *also* collides with terrain mid-flight, so cover holds even if the player
ducks behind something after the shot. A pure static helper
`is_los_blocked(ray_result) -> bool` isolates the decision for testing; the raycast call
itself is thin and exercised structurally.

## Fairness / telegraph

- `RangedAttack`: during `windup_time` the enemy is locked facing the player with a
  visible cue (model color/scale pulse via the existing `Juice3D`/`HitFlash3D`-style
  hook or a `GameEvents` VFX signal), *then* the projectile launches.
- `DashAttack`: `dash_windup` plays a crouch/flash cue before the lunge.
- No archetype can deal damage on the same frame it acquires the player — there is
  always a telegraph window to react by moving.

## Spawn integration & gating

- `spawning/spawner_3d.gd`: add `archer`, `magician`, `dasher` to `_variants` (load their
  `.tres`). No other spawner change — `_spawn_normal` already honors `allowed_variants`.
- `spawning/difficulty_timeline.gd` `state_at()`: extend the tiered `allowed_variants`:
  - `t ≥ 150` → `+archer` (ranged pressure mid-run)
  - `t ≥ 180` → `+dasher`
  - `t ≥ 240` → `+magician` (harder-hitting ranged late)
  - (existing tiers unchanged; thresholds tunable.)
- `spitter.tres` upgraded to `attack_kind = RANGED` so the existing spitter finally fires
  (cheap, low projectile damage) — the first ranged enemy the player meets at `t≥120`.

## Concrete variants (`.tres`)

| Variant | Kind | Model | Notes |
|---|---|---|---|
| `spitter` (existing) | RANGED | plant_monster (existing) | low-damage starter projectile |
| `archer` (new) | RANGED | **new CC0 model** | fast arrow, medium range |
| `magician` (new) | RANGED | **new CC0 model** | slower, harder-hitting bolt, longer range |
| `dasher` (new) | DASHER | existing fast model (e.g. swarmer/bug), recolored | lunges; reuse avoids an extra asset hunt |

**Asset sourcing (CC0):** archer + magician humanoid models from a CC0 source
(Quaternius RPG/fantasy character packs — mage, skeleton archer — are CC0 glTF; or
Kenney). Downloaded under `art/enemies_3d/<name>/`, recorded in
`docs/notes/asset-licenses.md`. **Fallback (pre-approved):** if no suitable CC0 model is
found, reuse an existing monster model with a distinct `color` tint and flag it — the
behavior ships regardless of art.

## Decoupled VFX (optional, consistent with existing pattern)

Projectile cast/impact and dash cues emit additive `GameEvents` so the `SkillVFX`/`Juice3D`
autoloads can render them; gameplay/tests never depend on visuals (matches the repo's
decoupled-visuals rule).

## Testing

Headless GUT (use `assert_true(x <= y)`, never `assert_le`/`assert_ge`).
- **Pure helpers:** projectile `_advance` travel; `RangedAttack` cooldown/windup gating
  (fires only when in range + LOS + off cooldown); `is_los_blocked`; `DashAttack` phase
  state-machine transitions and dash target/velocity math.
- **Behavior wiring:** `Enemy3D.setup()` selects the correct behavior per `attack_kind`
  (and `is_ranged` back-compat → RANGED).
- **Projectile damage:** `EnemyProjectile3D` calls `player.take_damage` on hurtbox hit,
  is freed by an obstacle hit, and ignores enemy bodies.
- **Spawn gating:** `DifficultyTimeline.state_at(t).allowed_variants` includes
  archer/dasher/magician at the right thresholds and not before.
- Full suite stays green (currently ~1018) and rises with the new tests; no silent skips.

## Out of scope (YAGNI)

- Smart/navmesh repositioning beyond simple kite/sidestep (local steering only).
- Friendly-fire among enemies; projectile bounce/pierce; status effects on hit.
- Per-archetype bespoke death/attack animations beyond the existing anim/telegraph hooks.
- New boss archetypes (bosses stay melee serpents).

## Known tradeoffs

- Reusing the dasher model (vs sourcing a 3rd new model) trades visual distinctiveness for
  speed; recolor keeps it readable.
- LOS raycasts add a little per-ranged-enemy cost; cheap at expected counts, revisit if
  many ranged enemies fire simultaneously.
- Projectiles are dodgeable by design; with many ranged enemies the screen can get busy —
  spawn gating + cooldowns keep it fair, tune in playtest.
