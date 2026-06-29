# See docs/notes/weapon-system-3d.md
class_name Weapon3D extends Node3D
## Base class for every 3D signature ability. Subclasses override fire() and evolve().
## Mirrors Weapon (Node2D) verbatim; only change is the base type to Node3D.
## Gameplay is on the XZ plane (Y up); spatial constants are in world units (1 unit ≈ 16 px).
## VFX: timer calls _fire_internal() which emits skill_cast then delegates to fire().
## Subclasses only need to override fire(); cast VFX is free. See docs/notes/skill-vfx.md.

var level: int = 1
var stats: StatBlock
var evolved: bool = false
var base_cooldown: float = 1.0   # subclass sets before calling setup()
## VFX identifier passed to GameEvents.skill_cast/skill_hit. Set in subclass _init/_ready.
var vfx_id: StringName = &""
## Tint color for cast/hit VFX particles. Archetypes set distinct defaults in _init().
var vfx_color: Color = Color(1, 1, 1)

var _timer: Timer

func _ready() -> void:
	# Create and connect timer here, but do NOT start it or read stats —
	# setup() is called after add_child(), so stats is null at this point.
	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(_fire_internal)

## Internal wrapper called by the timer. Emits skill_cast then delegates to fire().
## This gives every subclass cast VFX for free without any per-skill changes.
## fire() remains directly callable for tests — calling it directly skips the VFX emit.
func _fire_internal() -> void:
	if is_inside_tree():
		GameEvents.skill_cast.emit(vfx_id, vfx_color, global_position)
	fire()

func setup(_player: Node, p_stats: StatBlock) -> void:
	stats = p_stats
	_refresh_cooldown()
	# Timer starts here (not in _ready) because setup() is called after add_child(weapon),
	# meaning stats would be null if we tried to read fire_rate_mult during _ready().
	if _timer and _timer.is_inside_tree():
		_timer.start()

func fire() -> void:
	pass  # override in subclass

func level_up() -> void:
	level += 1
	_refresh_cooldown()

func evolve() -> void:
	evolved = true  # override to swap behavior, then call super or _refresh_cooldown()

func is_max_level(max_level: int) -> bool:
	return level >= max_level

## Public wrapper — called by Player3D.apply_stat_upgrade so external code
## doesn't touch the private _refresh_cooldown directly.
func refresh_cooldown() -> void:
	_refresh_cooldown()

## Virtual no-op. Subclasses override to apply their dedicated passive bonus.
## value is the per-level effect_value from the passive Upgrade resource.
func apply_passive(_value: float) -> void:
	pass

func _refresh_cooldown() -> void:
	if not _timer:
		return
	if not stats:
		return
	_timer.wait_time = max(0.05, base_cooldown / stats.fire_rate_mult)

## Pure cooldown fraction: 0.0 = just fired, 1.0 = ready. Static for testability.
static func cooldown_fraction_of(time_left: float, wait_time: float) -> float:
	if wait_time <= 0.0:
		return 1.0
	return clampf(1.0 - time_left / wait_time, 0.0, 1.0)

## Live cooldown fraction for the HUD (0.0 just fired … 1.0 ready).
func cooldown_fraction() -> float:
	if not _timer or _timer.is_stopped():
		return 1.0
	return cooldown_fraction_of(_timer.time_left, _timer.wait_time)
