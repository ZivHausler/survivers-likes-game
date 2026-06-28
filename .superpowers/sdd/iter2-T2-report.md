# Iter2 T2 Report — Time-Based Difficulty Ramp

## Growth Formulas

| Factor | Formula | At t=0 | At t=120 | At t=600 |
|--------|---------|--------|----------|----------|
| `hp_mult` | `1.0 + t / 120.0` | 1.0× | 2.0× | 6.0× |
| `enemy_scale` | `1.0 + (t / 600.0) * 0.5` | 1.00 | 1.10 | 1.50 |
| `spawn_interval` | `clamp(3.0 - t*0.01146, 0.25, 3.0)` | 3.00s | 1.63s | 0.25s (floor) |

**hp_mult** doubles enemy HP every 2 minutes; enemies are ~6× tougher at 10 minutes.  
**enemy_scale** grows 50% larger at 10 minutes — subtle so the screen doesn't feel absurd.

## Boss Configuration

| Boss | Trigger | HP Formula | Scale | XP | Color |
|------|---------|-----------|-------|----|-------|
| Mini-boss | Every 180 s (`BOSS_PERIOD=180`) | `base × 8 × hp_mult` | 3× | 50 | Red `(1.0, 0.15, 0.1)` |
| Big boss | Once at t≥600 | `base × 40 × hp_mult` | 5× | 200 | Purple `(0.5, 0.0, 1.0)` |

At t=600, `hp_mult=6`, so big boss effective HP = `base_tank × 240`.

## Tests Added / Updated

- **Updated** (adjusted 300→180 window boundaries): `test_boss_due_near_t300`, `test_boss_due_true_at_t301`, `test_mark_boss_spawned_clears_flag_within_same_window`, `test_boss_due_again_at_next_window_sequential_flow`, `test_consecutive_windows_each_trigger_once`
- **Added** (hp_mult): `test_hp_mult_is_1_at_t0`, `test_hp_mult_strictly_increases`, `test_hp_mult_doubles_at_t120`, `test_hp_mult_is_approx_6_at_t600`
- **Added** (enemy_scale): `test_enemy_scale_is_1_at_t0`, `test_enemy_scale_strictly_increases`, `test_enemy_scale_is_at_most_1_5_at_t600`
- **Added** (big_boss_due): `test_big_boss_not_due_before_t600`, `test_big_boss_due_at_t600`, `test_big_boss_due_at_t601`, `test_mark_big_boss_spawned_clears_flag_permanently`, `test_big_boss_fires_only_once`

## Full Suite Result

**212/212 tests passing** (up from 200/200 — added 12 new tests).

## Files Changed

- `spawning/difficulty_timeline.gd` — added hp_mult, enemy_scale, big_boss_due, mark_big_boss_spawned(); BOSS_PERIOD 300→180
- `spawning/spawner.gd` — normal spawns apply hp_mult+enemy_scale; mini-boss applies hp_mult; big boss (BIG_BOSS_HP_MULT=40, BIG_BOSS_SCALE_MULT=5, BIG_BOSS_XP_VALUE=200, purple color)
- `test/test_difficulty_timeline.gd` — updated 5 + added 13 tests
- `docs/notes/difficulty-timeline.md` — updated API, tables, boss sections
- `docs/notes/spawner.md` — documented growth, mini-boss change, big boss constants

## Manual Playtest Notes (required, not unit-testable)

1. Enemies should visibly grow in size and become noticeably harder to kill by minute 3+.
2. Red mini-boss should appear at ~3 min, ~6 min, ~9 min.
3. Giant purple boss appears at ~10 min and should feel significantly threatening.
4. To test fast: temporarily set `BOSS_PERIOD = 30.0` and `BIG_BOSS_THRESHOLD = 60.0` in difficulty_timeline.gd.

## Concerns

- **Big boss HP**: at t=600, effective HP = base_tank × 240. If base tank HP is low (e.g. 10), big boss has only 2400 HP — may feel too easy. Recommend verifying `tank.tres` base HP value during playtest.
- **enemy_scale applied to mini/big boss**: mini-boss still uses fixed `BOSS_SCALE_MULT=3.0`; it does NOT stack with `enemy_scale`. This is intentional to keep boss sizing predictable, but worth noting.
