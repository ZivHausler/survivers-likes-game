# See docs/notes/difficulty-timeline.md
class_name DifficultyTimeline extends RefCounted
## Pure difficulty curve — no scene-tree deps, fully unit-testable.
##
## Interval curve: linear decay clamped to a floor.
##   spawn_interval(t) = clamp(3.0 - t * 0.01146, INTERVAL_FLOOR, INTERVAL_START)
##   t=0   → 3.00 s
##   t=60  → ~2.31 s
##   t=120 → ~1.63 s
##   t=240 → 0.25 s  (floor reached)
##   t=240+→ 0.25 s  (floor, held)
##
## HP multiplier (enemies get tankier over time):
##   hp_mult(t) = 1.0 + t / 120.0
##   t=0   → 1.0×   (baseline)
##   t=120 → 2.0×   (doubles at 2 min)
##   t=300 → 3.5×
##   t=600 → 6.0×   (~6× at 10 min)
##
## Enemy scale (visual size grows modestly):
##   enemy_scale(t) = 1.0 + (t / 600.0) * 0.5
##   t=0   → 1.00   (baseline)
##   t=300 → 1.25
##   t=600 → 1.50   (50% larger at 10 min)
##
## Variant thresholds:
##   t <  60  → [swarmer]
##   t >= 60  → [swarmer, tank]
##   t >= 120 → [swarmer, tank, spitter]
##
## Mini-boss windows: one boss per 180 s boundary (180, 360, 540, …).
## Caller calls mark_boss_spawned() to acknowledge; flag stays clear until next window.
##
## Big boss: fires ONCE at t >= 600 (10 min).
## Caller calls mark_big_boss_spawned() to acknowledge; never re-fires.

const INTERVAL_START: float = 3.0   ## seconds between spawns at t=0
const INTERVAL_FLOOR: float = 0.25  ## minimum seconds between spawns (hard floor)

## The slope chosen so that INTERVAL_FLOOR is reached at ~240 s:
## 3.0 - 240 * k = 0.25  →  k ≈ 0.01146
const INTERVAL_SLOPE: float = 0.01146

const TANK_THRESHOLD:    float = 60.0
const SPITTER_THRESHOLD: float = 120.0
const BOSS_PERIOD:       float = 180.0  ## mini-boss every 3 minutes
const BIG_BOSS_THRESHOLD: float = 600.0 ## 10-minute big boss

## Last window index for which a boss was acknowledged (-1 = none).
var _last_boss_window: int = -1
## The most recently queried t; used by mark_boss_spawned().
var _last_queried_t: float = 0.0
## Whether the big boss has been spawned (fires only once).
var _big_boss_spawned: bool = false


func state_at(t: float) -> Dictionary:
	_last_queried_t = t

	# ── spawn interval ────────────────────────────────────────────────────────
	var interval: float = clamp(INTERVAL_START - t * INTERVAL_SLOPE,
								INTERVAL_FLOOR, INTERVAL_START)

	# ── hp multiplier (enemies grow tankier over time) ────────────────────────
	# Doubles every 2 minutes; ~6× at 10 minutes.
	var hp_mult: float = 1.0 + t / 120.0

	# ── enemy scale (modest visual growth) ───────────────────────────────────
	# Grows from 1.0 → ~1.5 over 10 minutes; subtle enough to not feel absurd.
	var enemy_scale: float = 1.0 + (t / 600.0) * 0.5

	# ── allowed variants ─────────────────────────────────────────────────────
	var variants: Array[StringName] = [&"swarmer"]
	if t >= TANK_THRESHOLD:
		variants.append(&"tank")
	if t >= SPITTER_THRESHOLD:
		variants.append(&"spitter")

	# ── mini-boss due? ────────────────────────────────────────────────────────
	var current_window: int = int(t / BOSS_PERIOD)
	var boss_due: bool = current_window >= 1 and current_window > _last_boss_window

	# ── big boss due? (fires once at t >= 600) ───────────────────────────────
	var big_boss_due: bool = (t >= BIG_BOSS_THRESHOLD) and not _big_boss_spawned

	return {
		spawn_interval   = interval,
		allowed_variants = variants,
		boss_due         = boss_due,
		big_boss_due     = big_boss_due,
		hp_mult          = hp_mult,
		enemy_scale      = enemy_scale,
	}


## Call this after spawning a mini-boss to prevent re-triggering in the same 180 s window.
func mark_boss_spawned() -> void:
	_last_boss_window = int(_last_queried_t / BOSS_PERIOD)


## Call this after spawning the 10-minute big boss. Fires only once per run.
func mark_big_boss_spawned() -> void:
	_big_boss_spawned = true
