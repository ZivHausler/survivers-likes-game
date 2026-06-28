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
#   { spawn_interval: float, allowed_variants: Array[StringName], boss_due: bool }

mark_boss_spawned() -> void
# Acknowledges boss for the current 300 s window; boss_due stays false
# until the next 300 s boundary.
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

## Variant Thresholds

| Variant  | Unlocks at |
|----------|-----------|
| swarmer  | t = 0 s   |
| tank     | t = 60 s  |
| spitter  | t = 120 s |

## Boss Windows

A boss is due at every 300 s boundary (300, 600, 900, …).  
The caller checks `state.boss_due`, spawns the boss, then calls `mark_boss_spawned()` to
prevent re-triggering within the same window.

Internally tracked via `_last_boss_window: int` (window index = `floor(t / 300)`).

## Tests

`test/test_difficulty_timeline.gd` — 14 tests, 100 % pass.

- Interval strictly decreasing from t=0 → t=240
- Floor clamped for large t (9999 s)
- Variant thresholds (tank @60 s, spitter @120 s)
- Boss flag at 300 s / 600 s; `mark_boss_spawned()` resets within same window

See [[spawner]] for the scene that consumes this class.
