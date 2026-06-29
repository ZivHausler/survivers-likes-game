extends GutTest
## Unit tests for Enemy3D.resolve_clip() — the pure static helper that maps a logical
## animation state ("idle"/"move") onto a real AnimationPlayer clip name.
##
## Motivates support for self-contained GLBs (e.g. CC0 Quaternius monsters) whose clips
## are named "CharacterArmature|Idle", "CharacterArmature|Walk"/"Run"/"Fast_Flying",
## while preserving the legacy convention where _try_load_anim injects a literal "move"
## clip. No scene tree required — resolve_clip is engine-state-free.

func _clips(arr: Array) -> PackedStringArray:
	return PackedStringArray(arr)

# ── exact match ────────────────────────────────────────────────────────────────

func test_exact_match_is_case_insensitive() -> void:
	var got := Enemy3D.resolve_clip(_clips(["Idle", "Move"]), _clips(["move"]))
	assert_eq(got, "Move", "exact (case-insensitive) match should win")

func test_legacy_injected_move_clip_resolves() -> void:
	# Legacy path: _try_load_anim adds a clip literally named "move".
	var got := Enemy3D.resolve_clip(_clips(["move", "RESET"]), _clips(["move", "run", "walk"]))
	assert_eq(got, "move", "literal 'move' clip must still resolve (back-compat)")

# ── Quaternius "Armature|Clip" leaf matching ───────────────────────────────────

func test_idle_resolves_quaternius_leaf() -> void:
	var clips := _clips(["CharacterArmature|Idle", "CharacterArmature|Walk", "CharacterArmature|Death"])
	var got := Enemy3D.resolve_clip(clips, _clips(["idle", "flying_idle"]))
	assert_eq(got, "CharacterArmature|Idle", "leaf after '|' should match idle")

func test_move_prefers_run_over_walk() -> void:
	var clips := _clips(["CharacterArmature|Walk", "CharacterArmature|Run", "CharacterArmature|Idle"])
	var got := Enemy3D.resolve_clip(clips, _clips(["move", "run", "walk", "fast_flying", "flying"]))
	assert_eq(got, "CharacterArmature|Run", "run is preferred over walk for move")

func test_move_falls_back_to_walk_when_no_run() -> void:
	# Wizard-style: Walk but no Run.
	var clips := _clips(["CharacterArmature|Walk", "CharacterArmature|Idle", "CharacterArmature|Bite_Front"])
	var got := Enemy3D.resolve_clip(clips, _clips(["move", "run", "walk", "fast_flying", "flying"]))
	assert_eq(got, "CharacterArmature|Walk", "walk used when no run clip present")

# ── flying creatures (Ghost / Demon / Dragon) ──────────────────────────────────

func test_flying_idle_resolves_for_idle() -> void:
	var clips := _clips(["CharacterArmature|Flying_Idle", "CharacterArmature|Fast_Flying", "CharacterArmature|Death"])
	var got := Enemy3D.resolve_clip(clips, _clips(["idle", "flying_idle"]))
	assert_eq(got, "CharacterArmature|Flying_Idle", "flying idle resolves for idle state")

func test_fast_flying_resolves_for_move() -> void:
	var clips := _clips(["CharacterArmature|Flying_Idle", "CharacterArmature|Fast_Flying", "CharacterArmature|Death"])
	var got := Enemy3D.resolve_clip(clips, _clips(["move", "run", "walk", "fast_flying", "flying"]))
	assert_eq(got, "CharacterArmature|Fast_Flying", "fast_flying resolves for move when no run/walk")

# ── no match ───────────────────────────────────────────────────────────────────

func test_returns_empty_when_nothing_matches() -> void:
	var got := Enemy3D.resolve_clip(_clips(["Take 001", "RESET"]), _clips(["idle", "flying_idle"]))
	assert_eq(got, "", "no match → '' so caller no-ops and procedural bob covers it")

func test_returns_empty_for_empty_clip_list() -> void:
	var got := Enemy3D.resolve_clip(_clips([]), _clips(["move", "run", "walk"]))
	assert_eq(got, "", "empty clip list → ''")

# ── attack/cast gesture clip ────────────────────────────────────────────────────

const ATTACK_CANDS := ["attack", "cast", "shoot", "punch", "headbutt", "bite_front", "throw"]

func test_attack_resolves_punch_for_ghost_demon() -> void:
	var clips := _clips(["CharacterArmature|Punch", "CharacterArmature|Headbutt", "CharacterArmature|Flying_Idle"])
	assert_eq(Enemy3D.resolve_clip(clips, _clips(ATTACK_CANDS)), "CharacterArmature|Punch",
		"punch is the attack gesture for ghost/demon/dragon")

func test_attack_resolves_bite_front_for_wizard() -> void:
	var clips := _clips(["CharacterArmature|Bite_Front", "CharacterArmature|Idle", "CharacterArmature|Walk"])
	assert_eq(Enemy3D.resolve_clip(clips, _clips(ATTACK_CANDS)), "CharacterArmature|Bite_Front",
		"wizard's only attack-like clip is Bite_Front")
