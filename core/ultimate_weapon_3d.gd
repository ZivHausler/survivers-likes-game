class_name UltimateWeapon3D extends Weapon3D
## Base for manually-activated ultimates. Unlike Weapon3D, it does NOT auto-fire:
## the Weapon3D auto-timer is never started. SPACE → Player3D.activate_ultimate()
## → activate(), which runs _do_ult() and starts a manual cooldown. Ultimates are
## never offered as level-up cards and never upgraded (fixed power).

## Big cooldown between activations (seconds). Subclasses set in _ready().
var ult_cooldown: float = 30.0
## Seconds left until ready; 0 = ready.
var _cd_remaining: float = 0.0
var _player_ref: Node3D = null

func setup(player: Node, p_stats: StatBlock) -> void:
	# Deliberately do NOT call super(): that would start the auto-fire timer.
	_player_ref = player as Node3D
	stats = p_stats
	if _timer:
		_timer.stop()

func _process(delta: float) -> void:
	if _cd_remaining > 0.0:
		tick(delta)

## Advance the cooldown by dt. Public so tests drive it without the frame loop.
func tick(dt: float) -> void:
	_cd_remaining = max(0.0, _cd_remaining - dt)

func is_ready() -> bool:
	return _cd_remaining <= 0.0

## Fire the ultimate if ready. Returns true if it activated.
func activate() -> bool:
	if not is_ready():
		return false
	if is_inside_tree():
		GameEvents.skill_cast.emit(vfx_id, vfx_color, global_position)
	_do_ult()
	_cd_remaining = ult_cooldown
	return true

## Override per ultimate with the actual effect.
func _do_ult() -> void:
	pass

## HUD: 0.0 just fired … 1.0 ready.
func cooldown_fraction() -> float:
	if ult_cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - _cd_remaining / ult_cooldown, 0.0, 1.0)
