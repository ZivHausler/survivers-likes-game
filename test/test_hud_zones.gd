extends GutTest
## HUD splits skills into zones: weapons (right) vs ultimate (center) from
## collect_cooldowns; passives (left) from collect_passives.

class _StubWeapon extends Node3D:
	func cooldown_fraction() -> float: return 0.3
class _StubUlt extends Node3D:
	func cooldown_fraction() -> float: return 0.7
class _StubPlayer extends Node3D:
	var weapons := {}
	var ultimate = null
	var passives := {}

func test_collect_passives_lists_levels() -> void:
	var hud = load("res://ui/hud.gd").new()
	var p := _StubPlayer.new()
	p.passives = { &"pew_pew": 2, &"trigger_finger": 1 }
	var got: Array = hud.collect_passives(p)
	assert_eq(got.size(), 2)
	# entries carry id + level
	var ids := []
	for e in got: ids.append(e["id"])
	assert_true(ids.has(&"pew_pew"))

func test_collect_passives_empty_when_none() -> void:
	var hud = load("res://ui/hud.gd").new()
	assert_eq(hud.collect_passives(_StubPlayer.new()).size(), 0)

func test_radial_fraction_clamped() -> void:
	var r = load("res://ui/radial_cooldown.gd").new()
	r.set_fraction(1.5)
	assert_almost_eq(r.fraction, 1.0, 0.0001)
	r.set_fraction(-0.2)
	assert_almost_eq(r.fraction, 0.0, 0.0001)
