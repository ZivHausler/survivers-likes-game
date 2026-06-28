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
## Variant thresholds:
##   t <  60  → [swarmer]
##   t >= 60  → [swarmer, tank]
##   t >= 120 → [swarmer, tank, spitter]
##
## Boss windows: one boss per 300 s boundary (300, 600, 900, …).
## Caller calls mark_boss_spawned() to acknowledge; flag stays clear until next window.

const INTERVAL_START: float = 3.0   ## seconds between spawns at t=0
const INTERVAL_FLOOR: float = 0.25  ## minimum seconds between spawns (hard floor)

## The slope chosen so that INTERVAL_FLOOR is reached at ~240 s:
## 3.0 - 240 * k = 0.25  →  k ≈ 0.01146
const INTERVAL_SLOPE: float = 0.01146

const TANK_THRESHOLD:    float = 60.0
const SPITTER_THRESHOLD: float = 120.0
const BOSS_PERIOD:       float = 300.0

## Last window index for which a boss was acknowledged (-1 = none).
var _last_boss_window: int = -1
## The most recently queried t; used by mark_boss_spawned().
var _last_queried_t: float = 0.0


func state_at(t: float) -> Dictionary:
	_last_queried_t = t

	# ── spawn interval ────────────────────────────────────────────────────────
	var interval: float = clamp(INTERVAL_START - t * INTERVAL_SLOPE,
								INTERVAL_FLOOR, INTERVAL_START)

	# ── allowed variants ─────────────────────────────────────────────────────
	var variants: Array[StringName] = [&"swarmer"]
	if t >= TANK_THRESHOLD:
		variants.append(&"tank")
	if t >= SPITTER_THRESHOLD:
		variants.append(&"spitter")

	# ── boss due? ─────────────────────────────────────────────────────────────
	var current_window: int = int(t / BOSS_PERIOD)
	var boss_due: bool = current_window >= 1 and current_window > _last_boss_window

	return {
		spawn_interval = interval,
		allowed_variants = variants,
		boss_due = boss_due,
	}


## Call this after spawning a boss to prevent re-triggering in the same 300 s window.
func mark_boss_spawned() -> void:
	_last_boss_window = int(_last_queried_t / BOSS_PERIOD)
