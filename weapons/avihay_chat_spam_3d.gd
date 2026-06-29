# See docs/notes/weapon-avihay-3d.md
class_name AvihayChatSpam3D extends Weapon3D
## Avihay's 3D signature ability: "Chat Spam"
##
## Fires message-bubble projectiles (Bubble3D Area3D) toward the nearest enemy
## in a directional spread on the XZ plane. Each level-up increases bubble count,
## pierce, and damage.
##
## All directions are XZ unit vectors: Vector3(cos a, 0, sin a).
##
## Evolution — "Reply-All Apocalypse":
##   Bubbles become homing (they steer toward the nearest enemy each frame)
##   and fire in a dense 360° pattern.

const MAX_LEVEL := 5

## Number of bubbles spawned per fire() activation.
var bubble_count: int = 3
## Damage dealt per bubble hit (multiplied by stats.damage_mult at fire time).
var bubble_damage: float = 15.0
## Pierce count per bubble — how many enemies each bubble can pass through.
var bubble_pierce: int = 1
## Half-angle (radians) of the directional spread cone in non-evolved mode.
const SPREAD_HALF_ANGLE: float = TAU / 8.0   # 45°

var _player_ref: Node3D = null
var _bubble_scene: PackedScene = null
## Whether spawned bubbles track the nearest enemy (set by evolve()).
var _homing_mode: bool = false

func _ready() -> void:
	base_cooldown = 2.0
	vfx_id = &"avihay_chat_spam"
	vfx_color = Color(0.3, 0.6, 1.0)  # blue/chat
	super()
	_bubble_scene = load("res://weapons/bubble_3d.tscn")

func setup(player: Node, p_stats: StatBlock) -> void:
	_player_ref = player as Node3D
	super(player, p_stats)

func fire() -> void:
	if not is_instance_valid(_player_ref) or not _bubble_scene:
		return
	var spawn_parent := _player_ref.get_parent()
	if not spawn_parent:
		return
	var damage := bubble_damage * stats.damage_mult
	for dir in _get_fire_directions():
		var bubble: Bubble3D = _bubble_scene.instantiate()
		# Add to tree FIRST so global_position assignment is valid (node must be in
		# the scene tree before global_position can be set on a Node3D).
		spawn_parent.add_child(bubble)
		bubble.global_position = _player_ref.global_position
		bubble.setup(dir, damage, bubble_pierce, _homing_mode)

## Return the list of XZ fire directions for this activation.
## In evolved mode: dense 360° ring (bubble_count × 2 directions).
## In normal mode: `bubble_count` directions spread around nearest enemy.
## Exposed as public so tests can verify direction count/spread without
## invoking the full fire() pipeline.
func _get_fire_directions() -> Array[Vector3]:
	var directions: Array[Vector3] = []
	if evolved:
		var total := bubble_count * 2
		for i in range(total):
			var a := TAU * i / float(total)
			directions.append(Vector3(cos(a), 0.0, sin(a)))
	else:
		var base_dir := _nearest_enemy_direction()
		var base_angle := atan2(base_dir.z, base_dir.x)
		for i in range(bubble_count):
			var t := 0.5 if bubble_count == 1 \
				else float(i) / float(bubble_count - 1)
			var angle := base_angle - SPREAD_HALF_ANGLE + t * SPREAD_HALF_ANGLE * 2.0
			directions.append(Vector3(cos(angle), 0.0, sin(angle)))
	return directions

## Return normalised XZ direction from player to nearest enemy, or (1,0,0) if none.
## Exposed as public for test verification of the XZ direction mapping.
func _nearest_enemy_direction() -> Vector3:
	if not is_instance_valid(_player_ref) or not is_inside_tree():
		return Vector3(1, 0, 0)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var my_pos := _player_ref.global_position
	var nearest: Node3D = null
	var best_dist := INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d := my_pos.distance_to((e as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			nearest = e as Node3D
	if nearest:
		var diff := nearest.global_position - my_pos
		diff.y = 0.0
		return diff.normalized()
	return Vector3(1, 0, 0)

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
