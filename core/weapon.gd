# See docs/notes/weapon-system.md
class_name Weapon extends Node2D
## Base class for every signature ability. Subclasses override fire() and evolve().

var level: int = 1
var stats: StatBlock
var evolved: bool = false
var base_cooldown: float = 1.0   # subclass sets before calling setup()

var _timer: Timer

func _ready() -> void:
	# Create and connect timer here, but do NOT start it or read stats —
	# setup() is called after add_child(), so stats is null at this point.
	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(fire)

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

## Public wrapper — called by Player.apply_stat_upgrade so external code
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
	_timer.wait_time = max(0.05, base_cooldown / stats.fire_rate_mult)
