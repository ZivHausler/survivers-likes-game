# See docs/notes/skill-vfx.md
extends Node
## SkillVFX — decoupled skill visual-effects layer for the 3D game.
## Listens to GameEvents.skill_cast and GameEvents.skill_hit and spawns
## colored 3D particle effects at the relevant world positions.
## Disabling or removing this autoload leaves all game logic unaffected.

const _SkillCastFxScene: PackedScene = preload("res://vfx/skill_cast_fx_3d.tscn")
const _SkillHitFxScene: PackedScene = preload("res://vfx/skill_hit_fx_3d.tscn")
const _AoeTelegraphScene: PackedScene = preload("res://vfx/aoe_telegraph_3d.tscn")

## Default AoE radius (world units) used when the cast signal carries no radius.
## CONCERN: GameEvents.skill_cast carries (vfx_id, color, position) — no radius.
## All casts receive a telegraph at this default size. Nova/ground casts are not
## distinguishable from the signal alone; dispatched for ALL casts intentionally.
const _DEFAULT_TELEGRAPH_RADIUS := 6.0

## Minimum interval (ms) between successive telegraph spawns for the same skill.
## Prevents visual spam from fast-firing weapons that emit multiple skill_cast signals.
const TELEGRAPH_MIN_INTERVAL_MS := 350

## Tracks the last time a telegraph was spawned for each vfx_id (ms since startup).
var _last_telegraph_ms: Dictionary = {}

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
	var fx: SkillCastFx3D = _SkillCastFxScene.instantiate()
	parent.add_child(fx)
	fx.play_at(position, color)
	# AoE telegraph — additive ring decal on the ground plane (LoL Swarm readability).
	# Rate-limited per skill to avoid spam from fast-firing weapons.
	var now := Time.get_ticks_msec()
	if now - int(_last_telegraph_ms.get(_vfx_id, -100000)) >= TELEGRAPH_MIN_INTERVAL_MS:
		_last_telegraph_ms[_vfx_id] = now
		var tele: AoeTelegraph3D = _AoeTelegraphScene.instantiate()
		parent.add_child(tele)
		tele.play_at(position, _DEFAULT_TELEGRAPH_RADIUS, color)

func _on_skill_hit(_vfx_id: StringName, color: Color, position: Vector3) -> void:
	var parent: Node = _safe_parent()
	if parent == null:
		return
	var fx: SkillHitFx3D = _SkillHitFxScene.instantiate()
	parent.add_child(fx)
	fx.play_at(position, color)
