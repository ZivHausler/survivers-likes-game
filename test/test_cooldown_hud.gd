extends GutTest
## HUD gathers one cooldown entry per active skill (weapons + ultimate, ult last).

class _StubWeapon extends Node3D:
	var _f := 1.0
	func cooldown_fraction() -> float: return _f

class _StubUlt extends Node3D:
	var _f := 1.0
	func cooldown_fraction() -> float: return _f

class _StubPlayer extends Node3D:
	var weapons := {}
	var ultimate = null

func test_empty_player_has_no_entries() -> void:
	var hud = load("res://ui/hud.gd").new()
	assert_eq(hud.collect_cooldowns(_StubPlayer.new()).size(), 0)

func test_weapons_then_ultimate_last() -> void:
	var hud = load("res://ui/hud.gd").new()
	var p := _StubPlayer.new()
	var w := _StubWeapon.new(); w._f = 0.25
	p.weapons = { &"pew_pew": w }
	var u := _StubUlt.new(); u._f = 0.5
	p.ultimate = u
	var got: Array = hud.collect_cooldowns(p)
	assert_eq(got.size(), 2, "one per weapon + ult")
	assert_eq(got[0]["id"], &"pew_pew")
	assert_almost_eq(got[0]["fraction"], 0.25, 0.0001)
	assert_false(got[0]["is_ultimate"])
	assert_true(got[1]["is_ultimate"], "ultimate is last")
	assert_almost_eq(got[1]["fraction"], 0.5, 0.0001)
