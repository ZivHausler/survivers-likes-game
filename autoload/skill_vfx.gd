# See docs/notes/skill-vfx.md
extends Node
## SkillVFX — decoupled skill visual-effects layer for the 3D game.
## Listens to GameEvents.skill_cast and GameEvents.skill_hit and spawns
## colored 3D particle effects at the relevant world positions.
## Disabling or removing this autoload leaves all game logic unaffected.

const _SkillCastFxScene: PackedScene = preload("res://vfx/skill_cast_fx_3d.tscn")
const _SkillHitFxScene: PackedScene = preload("res://vfx/skill_hit_fx_3d.tscn")

func _ready() -> void:
	GameEvents.skill_cast.connect(_on_skill_cast)
	GameEvents.skill_hit.connect(_on_skill_hit)

# ── Private helpers ───────────────────────────────────────────────────────────

## Returns a safe scene parent for effect nodes, or null if unavailable.
## Mirrors Juice3D._safe_parent() but derives the tree from self rather than
## a registered player, so it works from the first frame.
func _safe_parent() -> Node:
	if not is_inside_tree():
		return null
	var tree: SceneTree = get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_skill_cast(_vfx_id: StringName, color: Color, position: Vector3) -> void:
	var parent: Node = _safe_parent()
	if parent == null:
		return
	# Small cast burst only. The expanding AoE ring that used to spawn around the
	# character on EVERY cast was removed as unwanted visual noise — genuine AoE skills
	# (e.g. NovaWeapon3D) draw their own telegraph sized to their real blast radius.
	var fx: SkillCastFx3D = _SkillCastFxScene.instantiate()
	parent.add_child(fx)
	fx.play_at(position, color)

func _on_skill_hit(_vfx_id: StringName, color: Color, position: Vector3) -> void:
	var parent: Node = _safe_parent()
	if parent == null:
		return
	var fx: SkillHitFx3D = _SkillHitFxScene.instantiate()
	parent.add_child(fx)
	fx.play_at(position, color)
