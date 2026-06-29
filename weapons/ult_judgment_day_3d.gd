class_name UltJudgmentDay3D extends UltimateWeapon3D
## Avinoam's ultimate "Judgment Day": a holy strike that hits every enemy within
## `radius` for heavy damage. Offensive. (Stun/telegraph polish is playtest-tunable.)

var radius: float = 12.0
var damage: float = 120.0

func _ready() -> void:
	ult_cooldown = 25.0
	vfx_id = &"judgment_day"
	vfx_color = Color(1.0, 0.95, 0.5)   # holy gold
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position
	var dmg := damage * (stats.damage_mult if stats else 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if e3d and origin.distance_to(e3d.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
				GameEvents.skill_hit.emit(vfx_id, vfx_color, e3d.global_position)
