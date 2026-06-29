# See docs/notes/char-natali.md
class_name NataliLaughter3D extends NovaWeapon3D
## Natali signature skill: "Laughter" — a healing nova pulse that restores the
## player's HP by a small amount each fire, clamped to max_hp, AND deals light
## damage to nearby enemies.
##
## BESPOKE fire() override: heals the owner-player, then calls AoE damage
## (mirroring NovaWeapon3D logic) on enemies within radius.

const HEAL_AMOUNT: float = 6.0

var _player_ref: Node = null

func _ready() -> void:
	radius         = 6.0
	damage         = 6.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()

func setup(player: Node, p_stats: StatBlock) -> void:
	_player_ref = player
	super(player, p_stats)

## Bespoke fire: heal player then deal light AoE to enemies.
func fire() -> void:
	if not stats:
		return
	# ── Heal the player ──────────────────────────────────────────────────────
	if is_instance_valid(_player_ref) and "hp" in _player_ref:
		if _player_ref.has_method("heal"):
			# Preferred path: delegates hp update + HUD notification to Player3D.heal().
			_player_ref.heal(HEAL_AMOUNT)
		else:
			# Fallback for stub players or tests that don't implement heal().
			var max_hp: float = 100.0
			if "stats" in _player_ref and _player_ref.stats != null:
				max_hp = _player_ref.stats.max_hp
			_player_ref.hp = minf(_player_ref.hp + HEAL_AMOUNT, max_hp)
	# ── Light AoE damage to nearby enemies ───────────────────────────────────
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var targets: Array = affected_enemies(all_enemies, global_position)
	var dmg: float = damage * stats.damage_mult
	for enemy in targets:
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
