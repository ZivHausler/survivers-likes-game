# Boss HP Bars — Design

**Date:** 2026-06-29
**Status:** Approved (pending spec review)

## Goal

Give bosses visible health feedback:

- **Big boss** (`_spawn_big_boss`, once at t=600): a screen-anchored HP bar at the
  **top-center** of the screen, showing the boss name, a fill bar, and a numeric
  `current / max` readout.
- **Mini-boss** (`_spawn_boss`, every 180s): a small **floating HP bar above its head**
  in world space, always visible while alive, showing remaining HP as a left-anchored
  red fill.
- **Normal enemies**: no HP bar (unchanged).

## Context (current state)

- Mini-boss and big-boss are both `Enemy3D` instances. They differ only in HP/scale,
  the serpent model, and tint. There is **no boss-type marker** on the enemy today.
- `Enemy3D` holds `hp: float` and `data.max_hp`; `take_damage()` mutates `hp`, emits
  `enemy_killed_3d` on death, and `queue_free()`s. There is **no per-enemy HP signal**.
- `HUD` (`ui/hud.gd` + `ui/hud.tscn`) is a `CanvasLayer` driven by the `GameEvents`
  signal bus; `process_mode = ALWAYS`. It already uses `ProgressBar` + `StyleBoxFlat`.
- The 3D scene (`game/main_3d.tscn`) has a single angled follow camera
  (`GameCamera3D`, pitch −55°). Bosses are added as children of `Main3D` by the spawner.

## Architecture

Three cooperating units, each independently testable:

### Part C — Boss identity & wiring (`enemies/enemy_3d.gd`, `spawning/spawner_3d.gd`)

`Enemy3D` additions:

- `enum BossKind { NONE, MINI, BIG }`
- `var boss_kind: int = BossKind.NONE`
- `var boss_name: String = ""`
- `var _health_bar: HealthBar3D = null` (mini-boss only)
- `func configure_boss(kind: int, p_name: String = "") -> void` — called by the spawner
  **after** `setup()`:
  - `BIG`: store kind/name, emit `GameEvents.boss_spawned(p_name, data.max_hp)`.
    No head bar.
  - `MINI`: store kind, instance a `HealthBar3D`, add it as a child positioned above
    the head, `set_ratio(1.0)`.
- `take_damage(amount)` additions (after `hp` is reduced):
  - Non-lethal hit:
    - `BIG` → `GameEvents.boss_hp_changed(hp, data.max_hp)`
    - `MINI` → `_health_bar.set_ratio(hp / data.max_hp)` (guard `_health_bar` valid)
  - Lethal hit (before `queue_free()`):
    - `BIG` → `GameEvents.boss_died()`

`Spawner3D` additions:

- `_spawn_boss()`: after instancing + tint, `boss.configure_boss(Enemy3D.BossKind.MINI)`.
- `_spawn_big_boss()`: after instancing + tint,
  `boss.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")`.

### Part A — Big-boss screen bar (`autoload/game_events.gd`, `ui/hud.tscn`, `ui/hud.gd`)

New `GameEvents` signals:

```gdscript
signal boss_spawned(boss_name: String, max_hp: float)
signal boss_hp_changed(current: float, max_hp: float)
signal boss_died()
```

`hud.tscn` — add a top-center `BossBar` `Control` (a `VBoxContainer` or anchored
container), hidden by default (`visible = false`):

- `BossNameLabel: Label` — centered, e.g. "Undead Serpent".
- `BossHPBar: ProgressBar` — wide (≈ 60% of screen, `custom_minimum_size` ~ `(600, 24)`),
  centered, dark-red background + bright-red fill `StyleBoxFlat` (reuse the HP palette).
- `BossHPText: Label` — overlaid on the bar center, shows `"%d / %d"`.

`hud.gd` — `@onready` refs to the new nodes; connect in `_ready()`:

- `boss_spawned(name, max_hp)` → set `BossNameLabel.text`, `BossHPBar.max_value = max_hp`,
  `BossHPBar.value = max_hp`, set text `"max / max"`, `BossBar.visible = true`.
- `boss_hp_changed(current, max_hp)` → `BossHPBar.max_value = max_hp`,
  `BossHPBar.value = current`, `BossHPText.text = "%d / %d" % [current, max_hp]`.
- `boss_died()` → `BossBar.visible = false`.

### Part B — Mini-boss floating head bar (`ui/health_bar_3d.gd`)

New `class_name HealthBar3D extends Node3D`, built entirely in GDScript (no `.tscn`):

- On `_ready()`/build: create two `MeshInstance3D` children with `QuadMesh`:
  - **background** quad — dark grey/black, unshaded `StandardMaterial3D`.
  - **fill** quad — bright red, unshaded, drawn slightly in front; parented under a
    pivot `Node3D` anchored at the bar's left edge so it shrinks from the right.
  - Materials: `shading_mode = UNSHADED`, `cull_mode = DISABLED`,
    `no_depth_test` optional (draw over the body), `transparency` off.
- `func set_ratio(r: float) -> void` — clamp `r` to `[0, 1]`; set the fill pivot's
  `scale.x` (and reposition so the left edge stays fixed).
- `func _process(_dt)` — face the active camera each frame:
  `var cam := get_viewport().get_camera_3d(); if cam: look_at(...)` (or copy the
  camera basis) so the bar reads as a flat rectangle from the angled cam.
- Pure static helper for unit tests:
  `static func compute_fill_scale(ratio: float) -> float` — returns `clamp(ratio, 0, 1)`.
  (Plus a helper for the left-anchor offset if needed.)
- Constants: `WIDTH`, `HEIGHT`, `HEAD_OFFSET_Y` (local units; the bar inherits the
  boss's scale, so a 3× mini-boss gets a proportionally larger bar — acceptable).

## Data flow

```
damage → Enemy3D.take_damage()
  ├─ BIG  → GameEvents.boss_hp_changed → HUD.BossHPBar/Text update
  │         (death) GameEvents.boss_died → HUD.BossBar hidden
  └─ MINI → Enemy3D._health_bar.set_ratio(hp/max) → fill quad scales

spawn → Spawner3D._spawn_big_boss → Enemy3D.configure_boss(BIG, "Undead Serpent")
        → GameEvents.boss_spawned → HUD.BossBar shown
      → Spawner3D._spawn_boss → Enemy3D.configure_boss(MINI)
        → HealthBar3D child created above head
```

## Error handling / edge cases

- `set_ratio` clamps to `[0, 1]`; division guarded against `max_hp <= 0`.
- `_health_bar` updates guarded with `is_instance_valid`.
- Big boss dying emits `boss_died()` before `queue_free()` so the screen bar always hides.
- Multiple mini-bosses alive simultaneously each carry their own independent head bar.
- Head bar is a visual-only child `Node3D`; it never affects collision or contact damage.
- If no active camera (headless tests), `_process` no-ops the facing logic.

## Testing (GUT, headless)

- **`test_enemy_3d.gd`**:
  - `configure_boss(BIG, name)` emits `boss_spawned` with `data.max_hp`.
  - BIG `take_damage` (non-lethal) emits `boss_hp_changed` with `(hp, max_hp)`.
  - BIG lethal `take_damage` emits `boss_died`.
  - `configure_boss(MINI)` creates a `HealthBar3D` child; non-lethal damage sets its
    ratio to `hp / max_hp`.
  - NONE (normal enemy) emits none of the boss signals and has no `HealthBar3D` child.
- **`test_health_bar_3d.gd`** (new): `compute_fill_scale` clamps; `set_ratio` updates the
  fill pivot scale; full ratio = 1.0, zero ratio = 0.0.
- **`test_hud.gd`** (extend if present, else new): `boss_spawned` shows the bar + sets
  name/max; `boss_hp_changed` updates value + text; `boss_died` hides the bar.
- **`test_spawner_3d.gd`**: mini-boss spawn yields `boss_kind == MINI` + a `HealthBar3D`
  child; big-boss spawn yields `boss_kind == BIG`.

## Files touched

- `autoload/game_events.gd` — 3 new signals.
- `enemies/enemy_3d.gd` — boss enum/fields, `configure_boss()`, `take_damage()` hooks.
- `spawning/spawner_3d.gd` — `configure_boss()` calls in both boss spawners.
- `ui/hud.tscn` + `ui/hud.gd` — top-center boss bar nodes + signal handlers.
- `ui/health_bar_3d.gd` — new floating world-space bar (no `.tscn`).
- Tests: `test_enemy_3d.gd`, `test_spawner_3d.gd`, `test_hud.gd`, `test_health_bar_3d.gd`.

## Out of scope (YAGNI)

- No HP bars for normal enemies.
- Big boss gets only the screen bar (no head bar); mini-boss gets only the head bar.
- No fade-in/out or damage-flash animation beyond the fill changing.
- No boss portrait/icon.
