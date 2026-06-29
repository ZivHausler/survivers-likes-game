extends Node3D
## Headless autoplay harness — drives a real 3D run with a survival/avoidance bot.
## Loads main_3d.tscn, picks a character via RunState, then every physics tick reads
## live enemy positions (group "enemies"), steers the player away from the swarm and
## back from the arena edge through the REAL input path (Input.get_vector), and
## auto-picks level-up cards so the run never softlocks. Quits on death or at 10:00.

const MAIN_3D := "res://game/main_3d.tscn"
const DEFAULT_CHAR := "res://characters/ziv_3d.tres"
const RUN_SECONDS := 900.0          # 15 in-game minutes (run ends earlier if the big boss dies)
const KEEP_RADIUS := 58.0           # stay inside the arena walls
const CONTACT_RADIUS := 2.5         # enemy this close = about to land a melee hit → flee hard
const SENSE_RADIUS := 22.0          # enemies within this define the cluster centroid to engage
const PROJ_RADIUS := 14.0           # dodge incoming enemy projectiles within this range
const WALL_CLOCK_CAP_MS := 900000   # hard real-time safety: bail after 15 min wall clock

## Per-character BOT STATS. SAME playstyle for everyone; only the numbers differ. `standoff`
## is the distance the bot tries to hold the swarm at — tuned to each signature's reach so
## the weapon actually connects: orbit kits brawl on their ring, nova kits hold just inside
## the pulse, ranged kits kite far. (Reaches measured from each signature weapon.)
const BOT_STATS := {
	&"ziv":     {"standoff": 3.5},   # OrbitWeapon3D, ring 3.5 — brawl close
	&"barak":   {"standoff": 3.0},   # OrbitWeapon3D, ring 3.0 — brawl close
	&"avihay":  {"standoff": 9.0},   # ranged auto-aim projectiles — kite far
	&"avinoam": {"standoff": 5.0},   # Nova r6
	&"ido":     {"standoff": 5.0},   # Nova r6
	&"matan":   {"standoff": 6.0},   # Nova r7
	&"natali":  {"standoff": 5.0},   # Nova r6
	&"yinon":   {"standoff": 5.0},   # Nova r6
	&"yoav":    {"standoff": 4.5},   # Nova r5.5
	&"yuval":   {"standoff": 5.0},   # Nova r6
}
const DEFAULT_STANDOFF := 5.0

var _main: Node = null
var _player = null
var _gm = null
var _rng := RandomNumberGenerator.new()
var _game_time := 0.0
var _next_log := 0.0
var _dead := false
var _peak_enemies := 0
var _levels := 0
var _orbs := 0                       # XP orbs collected (GameEvents.xp_collected)
var _last_kill_t := 0.0              # game-time of the most recent kill (for adaptive engage)
var _standoff := DEFAULT_STANDOFF    # per-character hold distance (set from BOT_STATS in _ready)
var _seen_bosses := {}               # instance_id → true, to detect new boss spawns
var _start_ms := 0
var _min_hp := 1e9
var _char_name := "?"
var _big_boss_spawn_t := -1.0        # game-time the big boss appeared (-1 = not yet)
var _big_boss_hp := 0.0
var _big_boss_killed_t := -1.0       # game-time the big boss died (-1 = still alive / never)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # keep auto-picking while the tree is paused
	process_physics_priority = -100              # set input before Player3D reads it
	_rng.seed = 1337
	_start_ms = Time.get_ticks_msec()
	# Windowed (watchable) → real time; headless (data run) → fast-forward.
	Engine.time_scale = 1.0 if DisplayServer.get_name() != "headless" else 6.0
	var char_path := OS.get_environment("FS_CHAR")
	if char_path == "":
		char_path = DEFAULT_CHAR
	RunState.selected_character = load(char_path)
	GameEvents.player_died.connect(_on_died)
	GameEvents.player_leveled_up.connect(func(l): _levels += 1; _log_event("LEVEL UP → %d" % l))
	GameEvents.xp_collected.connect(func(_v): _orbs += 1)
	GameEvents.enemy_killed_3d.connect(func(_p, _x): _last_kill_t = _game_time)
	GameEvents.boss_spawned.connect(func(n, mhp): _big_boss_spawn_t = _game_time; _big_boss_hp = mhp; _log_event("★ BIG BOSS SPAWNED: %s (%.0f hp)" % [n, mhp]))
	GameEvents.boss_killed_3d.connect(_on_boss_killed)
	GameEvents.evolution_unlocked.connect(func(wid): _log_event("✦ EVOLUTION UNLOCKED: %s" % wid))
	var scene := load(MAIN_3D) as PackedScene
	_main = scene.instantiate()
	add_child(_main)                              # GameManager3D.start() runs here, reads RunState
	_player = _main.get_node_or_null("Player")
	_gm = _main.get_node_or_null("GameManager3D")
	_char_name = RunState.selected_character.display_name if RunState.selected_character else "?"
	var cid = RunState.selected_character.id if RunState.selected_character else &""
	_standoff = BOT_STATS[cid]["standoff"] if BOT_STATS.has(cid) else DEFAULT_STANDOFF
	print("[BOT] run start — character=%s  standoff=%.1f  player=%s  gm=%s" % [_char_name, _standoff, _player, _gm])

func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_summary("DIED")
	get_tree().quit()

## End the run the moment the big boss dies (success condition for this batch).
func _on_boss_killed(k: int) -> void:
	_log_event("☠ BOSS DEFEATED (%s)" % _boss_kind_name(k))
	if k == Enemy3D.BossKind.BIG and not _dead:
		_dead = true
		_big_boss_killed_t = _game_time
		_summary("BIG BOSS KILLED")
		get_tree().quit()

func _process(_dt: float) -> void:
	# Runs even while paused (PROCESS_MODE_ALWAYS) — drain the level-up card queue.
	if _gm and _gm.skill_system != null and _gm._choosing:
		_auto_pick()
	if Time.get_ticks_msec() - _start_ms > WALL_CLOCK_CAP_MS and not _dead:
		_summary("WALL-CLOCK CAP HIT")
		get_tree().quit()

func _auto_pick() -> void:
	var sys = _gm.skill_system
	var ui = _gm._upgrade_ui
	# Synthesize the exact left-click the UI listens for, so it picks the DISPLAYED
	# card 0, hides its panel (_panel.visible=false), then emits `chosen` → GameManager.
	# (Calling the GM handler directly would apply the upgrade but leave the panel painted.)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var guard := 0
	while _gm._choosing and sys.has_available_choices() and guard < 64:
		var idx := _best_choice_index(ui)
		var picked = ui._choices[idx] if (ui._choices != null and idx < ui._choices.size()) else null
		ui._on_card_input(click, idx)
		if picked != null:
			_log_event("   ↳ picked \"%s\"  [%s]" % [picked.display_name, _kind_name(picked)])
		guard += 1

## Pick the displayed card with the highest priority. Skills/evolutions first, passives last.
func _best_choice_index(ui) -> int:
	var choices = ui._choices
	if choices == null or choices.is_empty():
		return 0
	var best := 0
	var best_rank := -1
	for i in choices.size():
		var rank := _kind_rank(choices[i])
		if rank > best_rank:
			best_rank = rank
			best = i
	return best

func _kind_rank(u) -> int:
	match u.kind:
		Upgrade.Kind.SYNERGY: return 4   # skill evolution — strongest
		Upgrade.Kind.SKILL:   return 3   # new or leveled ability (prioritized)
		Upgrade.Kind.GENERIC: return 1   # generic stat bonus
		Upgrade.Kind.PASSIVE: return 0   # passive — lowest priority
	return 2

func _kind_name(u) -> String:
	match u.kind:
		Upgrade.Kind.SYNERGY: return "EVOLUTION"
		Upgrade.Kind.SKILL:   return "SKILL"
		Upgrade.Kind.GENERIC: return "stat"
		Upgrade.Kind.PASSIVE: return "passive"
	return "?"

func _boss_kind_name(k: int) -> String:
	return "mini-boss" if k == Enemy3D.BossKind.MINI else "BIG BOSS"

## Emit a timestamped event line (level-ups, picks, boss spawn/death, milestones).
func _log_event(msg: String) -> void:
	print("[EVENT t=%6.1fs] %s" % [_game_time, msg])

## Scan the enemy group for bosses we haven't announced yet (mini-boss spawn has no
## signal; the big boss does, but this also catches it uniformly and harmlessly).
func _scan_new_bosses() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.get("boss_kind") != null and e.boss_kind != Enemy3D.BossKind.NONE:
			var id := e.get_instance_id()
			if not _seen_bosses.has(id):
				_seen_bosses[id] = true
				# Big boss is already announced (named) via the boss_spawned signal; only the
				# mini-boss needs catching here since it emits no spawn signal.
				if e.boss_kind == Enemy3D.BossKind.MINI:
					_log_event("★ MINI-BOSS APPEARED (%.0f hp)" % float(e.hp))

func _physics_process(dt: float) -> void:
	if _dead or get_tree().paused or not is_instance_valid(_player):
		return
	_game_time += dt
	_scan_new_bosses()
	var ppos: Vector3 = _player.global_position
	var enemies := get_tree().get_nodes_in_group("enemies")
	_peak_enemies = max(_peak_enemies, enemies.size())
	var nearest := 1e9
	var nearest_to := Vector3.ZERO     # direction TOWARD the nearest enemy
	var contact := Vector3.ZERO        # hard repulsion from enemies within CONTACT_RADIUS (avoid hits)
	var crowd := Vector3.ZERO          # repulsion from enemies inside our standoff (maintain spacing)
	var centroid := Vector3.ZERO       # average position of the local cluster
	var cluster := 0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var epos: Vector3 = (e as Node3D).global_position
		var to: Vector3 = ppos - epos
		to.y = 0.0
		var d := to.length()
		if d < nearest:
			nearest = d
			nearest_to = -to
		if d < CONTACT_RADIUS and d > 0.001:
			contact += to.normalized() * ((CONTACT_RADIUS - d) / CONTACT_RADIUS)
		if d < _standoff and d > 0.001:
			crowd += to.normalized() * ((_standoff - d) / _standoff)
		if d < SENSE_RADIUS:
			centroid += epos
			cluster += 1
	# SAME playstyle for every character; the per-character `_standoff` is the only knob.
	#   GOAL    — collect the nearest XP orb (or close on the swarm to bring it into range).
	#   STANDOFF— hold the swarm at ~_standoff (= the signature's reach) and circle-strafe so
	#             enemies dwell in the kill band: orbit kits on the ring, nova kits in the pulse.
	#   AVOID   — always flee point-blank enemies (CONTACT) and DODGE incoming projectiles.
	var gem = _nearest_gem(ppos)
	var steer := Vector3.ZERO
	var throttle := 1.0
	if gem != null:
		var to_gem: Vector3 = (gem as Node3D).global_position - ppos
		to_gem.y = 0.0
		steer += to_gem.normalized()                                 # GOAL: run to the orb
	elif cluster > 0 and nearest > _standoff + 1.0:
		var to_c := (centroid / cluster) - ppos
		to_c.y = 0.0
		steer += to_c.normalized() * 0.8                             # too far → close to engage
		throttle = 0.8
	else:
		steer += Vector3(sin(_game_time * 0.7), 0.0, cos(_game_time * 0.9)) * 0.4
	# Hold the standoff band + circle-strafe so enemies keep crossing the weapon's hit zone.
	if cluster > 0:
		var n := nearest_to.normalized()
		steer += Vector3(-n.z, 0.0, n.x) * 0.9                       # strafe around the swarm
	steer += crowd * 2.2                                             # push back to ≥ standoff
	# AVOID HITS (always on, dominates the goal): point-blank flee + projectile dodge.
	steer += contact * 4.0
	steer += _projectile_dodge(ppos) * 5.0
	# Keep inside the arena: strong inward pull near the edge.
	var radial := Vector3(ppos.x, 0.0, ppos.z)
	if radial.length() > KEEP_RADIUS:
		steer += -radial.normalized() * 2.5
	if steer.length() < 0.01:
		steer = Vector3(1, 0, 0)
	var dir := steer.normalized()
	_drive(Vector2(dir.x, dir.z) * throttle)

	_min_hp = min(_min_hp, float(_player.hp))
	if _game_time >= _next_log:
		_next_log += 10.0
		print("[BOT] t=%5.1fs  hp=%6.1f/%-5.0f  lvl=%2d  kills=%4d  orbs=%4d  enemies=%3d  gems=%2d  nearest=%4.1f" % [
			_game_time, float(_player.hp), float(_player.stats.max_hp), int(_player.level),
			int(_gm.kills), _orbs, enemies.size(), _count_gems(), (0.0 if nearest > 1e8 else nearest)])
	if _game_time >= RUN_SECONDS:
		_summary("SURVIVED 15:00 (big boss still alive)" if _big_boss_killed_t < 0.0 else "SURVIVED 15:00")
		get_tree().quit()

## Nearest uncollected XP orb. Gems are added as direct children of the run scene root
## (GameManager3D._on_enemy_killed) and free themselves on pickup, so live children are
## exactly the orbs still on the ground. Not in a group, hence the scan.
func _nearest_gem(ppos: Vector3):
	var best: Node3D = null
	var bd := 1e9
	for c in _main.get_children():
		if c is XPGem3D:
			var d := ppos.distance_to((c as Node3D).global_position)
			if d < bd:
				bd = d
				best = c
	return best

## Dodge incoming enemy projectiles (EnemyProjectile3D — children of the run scene root).
## Only reacts to shots actually heading toward the player, and SIDESTEPS perpendicular to
## the shot's path (slip it) rather than backpedalling down its line. Returns a steer vector.
func _projectile_dodge(ppos: Vector3) -> Vector3:
	var v := Vector3.ZERO
	for c in _main.get_children():
		if not (c is EnemyProjectile3D):
			continue
		var pp := (c as Node3D).global_position
		var to_me := Vector3(ppos.x - pp.x, 0.0, ppos.z - pp.z)
		var d := to_me.length()
		if d < 0.01 or d > PROJ_RADIUS:
			continue
		var pdir: Vector3 = c._direction
		pdir.y = 0.0
		if pdir.length() < 0.01 or pdir.normalized().dot(to_me.normalized()) < 0.3:
			continue                                  # not coming at us → ignore
		var perp := Vector3(-pdir.z, 0.0, pdir.x)     # sidestep across the shot's path
		if perp.dot(to_me) < 0.0:
			perp = -perp
		v += perp.normalized() * ((PROJ_RADIUS - d) / PROJ_RADIUS)
	return v

func _count_gems() -> int:
	var n := 0
	for c in _main.get_children():
		if c is XPGem3D:
			n += 1
	return n

func _drive(v: Vector2) -> void:
	_set_axis("move_right", "move_left", v.x)
	_set_axis("move_down", "move_up", v.y)

func _set_axis(pos_action: String, neg_action: String, val: float) -> void:
	if val >= 0.0:
		Input.action_release(neg_action)
		Input.action_press(pos_action, clampf(val, 0.0, 1.0))
	else:
		Input.action_release(pos_action)
		Input.action_press(neg_action, clampf(-val, 0.0, 1.0))

func _summary(verdict: String) -> void:
	var lvl = int(_player.level) if is_instance_valid(_player) else -1
	var hp = float(_player.hp) if is_instance_valid(_player) else -1.0
	var kills = int(_gm.kills) if _gm else 0
	var max_hp := float(_player.stats.max_hp) if is_instance_valid(_player) and _player.stats else -1.0
	var spd := float(_player.stats.move_speed) if is_instance_valid(_player) and _player.stats else -1.0
	var min_hp := (_min_hp if _min_hp < 1e8 else -1.0)
	# Big-boss outcome: time-to-kill if killed, else "alive" / "never spawned".
	var boss_ttk := -1.0
	if _big_boss_killed_t >= 0.0 and _big_boss_spawn_t >= 0.0:
		boss_ttk = _big_boss_killed_t - _big_boss_spawn_t
	var boss_outcome := "never_spawned"
	if _big_boss_killed_t >= 0.0:
		boss_outcome = "KILLED in %.1fs" % boss_ttk
	elif _big_boss_spawn_t >= 0.0:
		boss_outcome = "survived_not_killed"
	print("\n========== AUTOPLAY SUMMARY ==========")
	print("character:      ", _char_name)
	print("verdict:        ", verdict)
	print("survived:       %.1f s of %.0f" % [_game_time, RUN_SECONDS])
	print("final level:    ", lvl)
	print("final hp:       %.1f / %.0f" % [hp, max_hp])
	print("min hp seen:    %.1f" % min_hp)
	print("move_speed:     %.2f" % spd)
	print("total kills:    ", kills)
	print("orbs collected: ", _orbs)
	print("levels gained:  ", _levels)
	print("peak enemies:   ", _peak_enemies)
	print("big boss:       ", boss_outcome)
	print("real wall-clock:%.1f s" % ((Time.get_ticks_msec() - _start_ms) / 1000.0))
	print("======================================")
	# Single machine-parseable line for cross-character aggregation:
	print("RESULT|%s|%s|%.1f|%d|%d|%.1f|%.0f|%.2f|%d|%s" % [
		_char_name, verdict, _game_time, lvl, kills, min_hp, max_hp, spd, _peak_enemies, boss_outcome])
