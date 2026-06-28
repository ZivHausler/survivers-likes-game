# See docs/notes/weapon-avihay.md
class_name AvihayChatSpam extends Weapon
## Avihay's signature ability: "Chat Spam"
##
## Fires message-bubble projectiles (Bubble Area2D) toward the nearest enemy
## in a directional spread. Each level-up increases bubble count, pierce, and
## damage. Bubbles pierce through enemies; pierce count grows with level.
##
## Evolution — "Reply-All Apocalypse":
##   Bubbles become homing (they steer toward the nearest enemy each frame)
##   and fire in a dense 360° pattern, filling the screen with tracking messages.

const MAX_LEVEL := 5

## Number of bubbles spawned per fire() activation.
var bubble_count: int = 3
## Damage dealt per bubble hit (multiplied by stats.damage_mult at fire time).
var bubble_damage: float = 15.0
## Pierce count per bubble — how many enemies each bubble can pass through.
var bubble_pierce: int = 1
## Half-angle (radians) of the directional spread cone in non-evolved mode.
const SPREAD_HALF_ANGLE: float = TAU / 8.0   # 45°

var _player_ref: Node2D = null
var _bubble_scene: PackedScene = null
## Whether spawned bubbles track the nearest enemy (set by evolve()).
var _homing_mode: bool = false

func _ready() -> void:
	base_cooldown = 2.0
	super()
	_bubble_scene = load("res://weapons/bubble.tscn")

func setup(player: Node, p_stats: StatBlock) -> void:
	_player_ref = player as Node2D
	super(player, p_stats)

func fire() -> void:
	if not is_instance_valid(_player_ref) or not _bubble_scene:
		return
	var spawn_parent := _player_ref.get_parent()
	if not spawn_parent:
		return
	var damage := bubble_damage * stats.damage_mult
	for dir in _get_fire_directions():
		var bubble: Bubble = _bubble_scene.instantiate()
		bubble.global_position = _player_ref.global_position
		spawn_parent.add_child(bubble)
		bubble.setup(dir, damage, bubble_pierce, _homing_mode)

## Return the list of fire directions for this activation.
## In evolved mode: dense 360° ring (bubble_count × 2 directions).
## In normal mode: `bubble_count` directions spread around nearest enemy.
## Exposed as public so tests can verify direction count/spread without
## invoking the full fire() pipeline.
func _get_fire_directions() -> Array[Vector2]:
	var directions: Array[Vector2] = []
	if evolved:
		var total := bubble_count * 2
		for i in range(total):
			directions.append(Vector2.RIGHT.rotated(TAU * i / total))
	else:
		var base_dir := _nearest_enemy_direction()
		var base_angle := base_dir.angle()
		for i in range(bubble_count):
			var t := 0.5 if bubble_count == 1 \
				else float(i) / float(bubble_count - 1)
			var angle := base_angle - SPREAD_HALF_ANGLE + t * SPREAD_HALF_ANGLE * 2.0
			directions.append(Vector2.from_angle(angle))
	return directions

## Return normalised direction from player to nearest enemy, or RIGHT if none.
func _nearest_enemy_direction() -> Vector2:
	if not is_instance_valid(_player_ref) or not is_inside_tree():
		return Vector2.RIGHT
	var enemies := get_tree().get_nodes_in_group("enemies")
	var my_pos := _player_ref.global_position
	var nearest: Node2D = null
	var best_dist := INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d := my_pos.distance_to((e as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			nearest = e as Node2D
	if nearest:
		return (nearest.global_position - my_pos).normalized()
	return Vector2.RIGHT

## Passive bonus: increases fire rate (bubbles per second).
## value = passive Upgrade's effect_value (fire_rate_mult delta per passive level).
func apply_passive(value: float) -> void:
	if stats:
		stats.fire_rate_mult += value
		refresh_cooldown()

func level_up() -> void:
	super()
	bubble_count  += 1
	bubble_pierce += 1
	bubble_damage += 5.0

func evolve() -> void:
	super()          # sets evolved = true
	_homing_mode = true
