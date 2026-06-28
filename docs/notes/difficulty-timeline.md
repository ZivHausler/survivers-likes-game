---
id: difficulty-timeline
title: Difficulty Timeline
tags: [spawning, balance]
links: [[spawner]]
---

# Difficulty Timeline

`spawning/difficulty_timeline.gd` — `class_name DifficultyTimeline extends RefCounted`

Pure logic class (no scene-tree dependencies); fully unit-tested via GUT.

## Responsibilities

- Returns the current difficulty **state** for any elapsed time `t` (seconds).
- Tracks which boss windows have been acknowledged.

## API

```gdscript
state_at(t: float) -> Dictionary
# returns:
#   {
#     spawn_interval:   float,            # seconds between spawns
#     allowed_variants: Array[StringName], # which enemy types to pick from
#     boss_due:         bool,             # mini-boss window open?
#     big_boss_due:     bool,             # 10-min big boss window open?
#     hp_mult:          float,            # scale enemy HP by this
#     enemy_scale:      float,            # scale enemy visual size by this
#   }

mark_boss_spawned() -> void
# Acknowledges mini-boss for the current 180 s window; boss_due stays false
# until the next 180 s boundary.

mark_big_boss_spawned() -> void
# Acknowledges the 10-min big boss; big_boss_due is permanently false after this.
```

## Interval Curve

Linear decay clamped to a floor:

```
spawn_interval(t) = clamp(3.0 - t * 0.01146, 0.25, 3.0)
```

| t (s) | interval (s) |
|-------|-------------|
| 0     | 3.00        |
| 60    | 2.31        |
| 120   | 1.63        |
| 180   | 0.94        |
| 240   | 0.25 (floor)|
| ∞     | 0.25 (floor)|

Slope chosen so the floor is reached at ~240 s, giving a ~4-minute ramp before maximum density.

## HP Multiplier

Enemies grow tankier over time:

```
hp_mult(t) = 1.0 + t / 120.0
```

| t (s) | hp_mult |
|-------|---------|
| 0     | 1.0×    |
| 120   | 2.0×    |
| 300   | 3.5×    |
| 600   | 6.0×    |

Applied to all normal enemies, mini-bosses, and scaled further for the big boss.

## Enemy Scale

Enemies grow modestly in visual size:

```
enemy_scale(t) = 1.0 + (t / 600.0) * 0.5
```

| t (s) | scale |
|-------|-------|
| 0     | 1.00  |
| 300   | 1.25  |
| 600   | 1.50  |

Kept subtle (max 1.5× at 10 min) so screen doesn't feel overwhelmed by giant enemies.

## Variant Thresholds

| Variant  | Unlocks at |
|----------|-----------|
| swarmer  | t = 0 s   |
| tank     | t = 60 s  |
| spitter  | t = 120 s |

## Mini-Boss Windows

A mini-boss is due at every 180 s boundary (180, 360, 540, …).  
The caller checks `state.boss_due`, spawns the boss, then calls `mark_boss_spawned()` to
prevent re-triggering within the same window.

Internally tracked via `_last_boss_window: int` (window index = `floor(t / 180)`).

## 10-Minute Big Boss

A single very tough big boss fires **once** when `t >= 600`.  
The caller checks `state.big_boss_due`, spawns the big boss, then calls `mark_big_boss_spawned()`.  
The flag never re-fires — `_big_boss_spawned: bool` is permanent.

See [[spawner]] for big-boss constants (HP×40, scale×5, XP=200).

## Tests

`test/test_difficulty_timeline.gd` — 27 tests, 100 % pass.

- Interval strictly decreasing from t=0 → t=240; floor clamped for large t
- Variant thresholds (tank @60 s, spitter @120 s)
- hp_mult: ~1.0 at t=0, doubles at t=120, ~6× at t=600, strictly increasing
- enemy_scale: 1.0 at t=0, ~1.5 at t=600, strictly increasing, stays subtle
- Mini-boss flag at 180/360/540 s windows; `mark_boss_spawned()` resets within window
- Big boss due at t≥600; `mark_big_boss_spawned()` permanently clears; fires exactly once

See [[spawner]] for the scene that consumes this class.
