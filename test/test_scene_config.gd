extends GutTest
## Regression guards for scene-level configuration that the physics-bypassing
## unit tests can't catch: collision layer/mask wiring and HUD process_mode.

# ── Projectile-vs-enemy collision detection ──────────────────────────────────

## Bug #1 guard: Bubble.collision_mask must intersect Enemy.collision_layer,
## otherwise body_entered never fires in a real run and Avihay deals zero damage.
func test_bubble_mask_intersects_enemy_layer() -> void:
	var bubble: Area2D = autofree(load("res://weapons/bubble.tscn").instantiate())
	var enemy:  Node   = autofree(load("res://enemies/enemy.tscn").instantiate())
	assert_ne(bubble.collision_mask & enemy.collision_layer, 0,
		"Bubble.collision_mask (%d) must overlap Enemy.collision_layer (%d) so the projectile can detect enemies"
		% [bubble.collision_mask, enemy.collision_layer])

## Sanity: Ziv's Beam Area2D must also be able to detect enemies on their layer.
func test_ziv_beam_mask_intersects_enemy_layer() -> void:
	var weapon: Node2D = autofree(load("res://weapons/ziv_stunning_looks.tscn").instantiate())
	var beam:   Area2D = weapon.get_node("Beam")
	var enemy:  Node   = autofree(load("res://enemies/enemy.tscn").instantiate())
	assert_ne(beam.collision_mask & enemy.collision_layer, 0,
		"Beam.collision_mask (%d) must overlap Enemy.collision_layer (%d)"
		% [beam.collision_mask, enemy.collision_layer])

## Enemy must keep collision_layer = 1 so weapon/pickup Area2Ds can see it.
func test_enemy_stays_on_layer_one() -> void:
	var enemy: Node = autofree(load("res://enemies/enemy.tscn").instantiate())
	assert_ne(enemy.collision_layer & 1, 0,
		"Enemy must remain on collision_layer bit 1 for Area2D detection")

## Player must keep collision_layer = 1 so the XPGem Area2D can detect it.
func test_player_stays_on_layer_one() -> void:
	var player: Node = autofree(load("res://player/player.tscn").instantiate())
	assert_ne(player.collision_layer & 1, 0,
		"Player must remain on collision_layer bit 1 for XPGem detection")

# ── HUD process_mode ──────────────────────────────────────────────────────────

## Bug #2 guard: HUD must use PROCESS_MODE_ALWAYS so its _process (timer, kills,
## XP bar) runs during normal play AND while the level-up overlay pauses the tree.
func test_hud_process_mode_is_always() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"HUD root process_mode must be PROCESS_MODE_ALWAYS (not WHEN_PAUSED, which freezes it during play)")

## UpgradeUI is correctly WHEN_PAUSED — it must respond only while paused.
func test_upgrade_ui_process_mode_is_when_paused() -> void:
	var ui: Node = add_child_autofree(load("res://upgrades/upgrade_ui.tscn").instantiate())
	assert_eq(ui.process_mode, Node.PROCESS_MODE_WHEN_PAUSED,
		"UpgradeUI root process_mode must be PROCESS_MODE_WHEN_PAUSED")
