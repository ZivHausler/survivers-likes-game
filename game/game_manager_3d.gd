# See docs/notes/game-manager-3d.md
class_name GameManager3D extends Node
## Owns the 3D run: timer, kill counter, XP gem spawning, level-up flow, death routing.
## Constructs run skills in priority: (1) type-gated pool (ultimate + type-filtered shared pool);
## (2) char-specific SkillSystem roster; (3) legacy UpgradeSystem (signature/passive/evolution).

## Seconds of invulnerability granted to the player when the level-up card flow resolves.
const LEVELUP_INVULN := 2.0

const GEM_SCENE_PATH := "res://pickups/xp_gem_3d.tscn"
const GAME_OVER_SCENE := "res://ui/game_over.tscn"
const ZIV_3D_PATH := "res://characters/ziv_3d.tres"
const PLAYER_SCENE := preload("res://player/player_3d.tscn")
const ENEMY_SCENE := preload("res://enemies/enemy_3d.tscn")

# ── Enemy snapshot networking (Task E1, M3) ───────────────────────────────────
## Quantization frame for the batched enemy snapshot. Enemy XZ positions are mapped
## into [0, NET_SPAN] from NET_ORIGIN and packed as u16 — covers the playable arena
## with ~3 mm precision. MUST match on host and client (both read these consts).
const NET_ORIGIN := Vector3(-100, 0, -100)
const NET_SPAN := 200.0
## Host broadcast period (~20 Hz) and the proxy despawn threshold in snapshot ticks.
const SNAP_INTERVAL := 0.05
const PROXY_STALE_TICKS := 10
## Radius of the party spawn ring (world units). Single player ignores it (spawns at centre).
const PARTY_SPAWN_RADIUS := 3.0
const GENERIC_UPGRADE_PATHS := [
	"res://upgrades/generic/move_speed.tres",
	"res://upgrades/generic/max_hp.tres",
	"res://upgrades/generic/pickup_range.tres",
	"res://upgrades/generic/fire_rate.tres",
	"res://upgrades/generic/armor.tres",
]

## Active SkillSystem — used when char_data.skills is non-empty. Tests may inject directly.
var skill_system: SkillSystem = null
## Legacy UpgradeSystem — kept for backward-compat test injection (tests that assign this
## directly should also null out skill_system to use the old routing path).
var upgrade_system: UpgradeSystem = null

var elapsed: float = 0.0
var kills: int = 0

var _player = null  # Player3D at runtime; duck-typed so test stubs work. Primary/local ref.
var _players: Array = []  # party list gems magnet toward; filled by _on_player_spawned
var _player_spawner: MultiplayerSpawner = null  # MultiplayerSpawner covering the Players node
var _spawner = null  # Spawner3D at runtime; duck-typed so test stubs work
var _gem_scene: PackedScene = null
var _upgrade_ui: Node = null  # UpgradeUI CanvasLayer
var _pause_menu: Node = null  # PauseMenu CanvasLayer (sibling in main_3d.tscn)
## skill.id → SkillData, built from char_data.skills at start.
var _skill_by_id: Dictionary = {}

# Level-up queue — mirrors 2D GameManager exactly.
# player.add_xp() can cross several thresholds in one call, emitting
# player_leveled_up synchronously multiple times. We serialise these so each
# level-up gets its own (freshly evaluated) choice set and the tree only
# unpauses once every queued level-up has been resolved.
var _choosing: bool = false
var _pending_levelups: int = 0

# ── Enemy snapshot state ──────────────────────────────────────────────────────
## Host: accumulator + wrapping u16 tick counter driving the ~20 Hz broadcast.
var _snap_accum: float = 0.0
var _snap_tick: int = 0
## Client: net_id → proxy Enemy3D, and net_id → snapshot tick last seen (for despawn).
var _proxies: Dictionary = {}
var _last_seen: Dictionary = {}


## Assemble a run's skill list: the type-filtered shared pool only.
## The ultimate is NOT included here — it is granted into the dedicated manual
## SPACE slot via grant_ultimate(), never the upgrade pool.
## Pure (no scene access) so it is unit-testable.
static func assemble_run_skills(pool: Array, types: Array) -> Array:
	return SkillPool.filter(pool, types)


func _ready() -> void:
	_gem_scene = load(GEM_SCENE_PATH) as PackedScene
	start()


func start() -> void:
	var parent := get_parent()
	if parent == null:
		return

	_spawner = parent.get_node_or_null("Spawner3D")  # duck-typed; no cast needed
	_upgrade_ui = parent.get_node_or_null("UpgradeUI")
	_pause_menu = parent.get_node_or_null("PauseMenu")

	# Runtime-spawn one Player3D per party member (Task D2). Populates _players and
	# _player (=local player) via _on_player_spawned; each player is set up with its
	# own fighter inside the spawn callback. Solo yields exactly one player as before.
	_spawn_party()

	# The subsequent skill/ultimate wiring drives the LOCAL/primary player (_player),
	# using the character it was spawned with. Falls back to ziv_3d if somehow unset.
	var char_data: CharacterData = null
	if _player != null:
		char_data = _player.character_data as CharacterData
	if char_data == null:
		char_data = load(ZIV_3D_PATH) as CharacterData

	# Build system from character data.
	var generic_pool: Array = []
	for path in GENERIC_UPGRADE_PATHS:
		var u := load(path) as Upgrade
		if u:
			generic_pool.append(u)

	if char_data and char_data.ultimate != null and not char_data.types.is_empty():
		# Type-gated pool path: type-filtered shared pool only (no ultimate).
		# The ultimate is granted into the manual SPACE slot below — it is never
		# part of the upgrade pool and is not auto-acquired here.
		var run_skills := assemble_run_skills(SkillPool.all(), char_data.types)
		skill_system = SkillSystem.new(run_skills, generic_pool)
		_skill_by_id.clear()
		for s in run_skills:
			_skill_by_id[s.id] = s
	elif char_data and not char_data.skills.is_empty():
		# Legacy per-character roster path (still used until migration completes).
		skill_system = SkillSystem.new(char_data.skills, generic_pool)
		_skill_by_id.clear()
		for s in char_data.skills:
			_skill_by_id[s.id] = s
		if _player:
			for s in char_data.skills:
				if s.is_signature:
					_player.acquire_skill(s.id, s.weapon_scene)
					break
	elif char_data and char_data.signature_upgrade and char_data.passive_upgrade and char_data.evolution_upgrade:
		# Legacy UpgradeSystem path (skills array empty — used by 2D-compatible tests).
		upgrade_system = UpgradeSystem.new(
			char_data,
			generic_pool,
			char_data.signature_upgrade,
			char_data.passive_upgrade,
			char_data.evolution_upgrade
		)

	# Ultimate: dedicated manual slot, granted separately from the weapon pool.
	if _player and char_data and char_data.ultimate and char_data.ultimate.weapon_scene:
		_player.grant_ultimate(char_data.ultimate.weapon_scene)

	# Connect UpgradeUI chosen signal.
	if _upgrade_ui and _upgrade_ui.has_signal("chosen"):
		_upgrade_ui.chosen.connect(_on_upgrade_chosen)

	# Connect GameEvents.
	GameEvents.enemy_killed_3d.connect(_on_enemy_killed)
	GameEvents.player_leveled_up.connect(_on_player_leveled_up)
	GameEvents.player_died.connect(_on_player_died)

	# Register Player3D and GameCamera3D with the Juice3D autoload so it can
	# spawn effects and forward camera shake. Both are siblings of this node.
	if _player:
		Juice3D.register_player(_player)
	var cam: GameCamera3D = parent.get_node_or_null("GameCamera3D") as GameCamera3D
	if cam:
		Juice3D.register_camera(cam)
		# Assign the player as the camera target in code — the exported NodePath in
		# the .tscn does not resolve at runtime (Node3D export stays null).
		# This is the authoritative assignment; the .tscn value is ignored.
		if _player:
			cam.target = _player


func _process(dt: float) -> void:
	if get_tree().paused:
		return
	elapsed += dt
	# Host-only enemy snapshot broadcast (~20 Hz). No-op in solo / with zero clients:
	# get_peers() is empty, so nothing is gathered or sent and the accumulator idles.
	if not multiplayer.get_peers().is_empty() and multiplayer.is_server():
		_snap_accum += dt
		if _snap_accum >= SNAP_INTERVAL:
			_snap_accum = 0.0
			_broadcast_enemy_snapshot()


# ── Enemy snapshot: host broadcast ────────────────────────────────────────────

## Gather every enemy in group "enemies" into one quantized snapshot and send it,
## unreliably, to each connected client. Guards on empty peers so a direct call in solo
## (or a host with no clients) is a clean no-op that sends nothing and mutates no state.
func _broadcast_enemy_snapshot() -> void:
	var peers := multiplayer.get_peers()
	if peers.is_empty():
		return
	var entries: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		entries.append({
			"id": e.net_id,
			"pos": e.global_position,
			"yaw": e.rotation.y,
			"state": e.snapshot_state(),
		})
	var inv := 65535.0 / NET_SPAN
	var bytes := EnemySnapshot.pack(entries, NET_ORIGIN, inv, _snap_tick)
	_snap_tick = (_snap_tick + 1) & 0xFFFF
	for pid in peers:
		receive_enemy_snapshot.rpc_id(pid, bytes)


# ── Enemy snapshot: client receive + proxy lifecycle ──────────────────────────

## Forward tick distance accounting for u16 wraparound (0..65535). Returns how many
## ticks `now` is ahead of `then`.
static func _tick_gap(now: int, then: int) -> int:
	return (now - then) & 0xFFFF


## Runs on CLIENTS (authority = host). Unpack the snapshot and reconcile proxies:
## spawn a visual-only Enemy3D for each unseen id, retarget existing ones, and despawn
## proxies not present for PROXY_STALE_TICKS ticks. Never runs on the host (call_remote).
@rpc("authority", "call_remote", "unreliable")
func receive_enemy_snapshot(bytes: PackedByteArray) -> void:
	var scale := NET_SPAN / 65535.0
	var snap := EnemySnapshot.unpack(bytes, NET_ORIGIN, scale)
	var tick: int = snap["tick"]
	var parent := get_parent()
	for e in snap["entries"]:
		var id: int = e["id"]
		var proxy = _proxies.get(id)
		if proxy == null or not is_instance_valid(proxy):
			proxy = ENEMY_SCENE.instantiate()
			proxy.net_id = id
			if parent:
				parent.add_child(proxy)
			proxy.add_to_group("enemies")
			proxy.configure_proxy()
			proxy._net_manager = self
			proxy.global_position = e["pos"]
			_proxies[id] = proxy
		proxy.set_interp_target(e["pos"], e["yaw"])
		_last_seen[id] = tick
	# Despawn proxies not present in recent snapshots (killed on the host / out of range).
	for id in _proxies.keys():
		if not _last_seen.has(id) or _tick_gap(tick, _last_seen[id]) > PROXY_STALE_TICKS:
			if is_instance_valid(_proxies[id]):
				_proxies[id].queue_free()
			_proxies.erase(id)
			_last_seen.erase(id)


# ── Client weapon damage → host arbitration by net_id (Task E2, M3) ──────────

## Host-side lookup: the host has no proxies, so every "enemies" group member is a
## real enemy. Returns null when no enemy has a matching net_id.
func _host_enemy_by_net_id(net_id: int) -> Node:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.net_id == net_id and is_instance_valid(e):
			return e
	return null


## Called on a CLIENT by a proxy's take_damage; forwards the hit to the host authority.
func client_deal_damage(net_id: int, amount: float) -> void:
	request_damage.rpc_id(1, net_id, amount)


@rpc("any_peer", "call_remote", "reliable")
func request_damage(net_id: int, amount: float) -> void:
	if not multiplayer.is_server():
		return
	var e := _host_enemy_by_net_id(net_id)
	if e == null:
		return
	var was_valid := is_instance_valid(e)
	e.take_damage(maxf(0.0, amount))   # host applies; may emit enemy_killed_3d/XP + start dissolve
	# If the hit killed it, tell clients to drop the proxy immediately (snapshot despawn is the
	# slower fallback). e may already be _dying (still valid until dissolve frees it).
	if was_valid and (not is_instance_valid(e) or e.hp <= 0.0):
		confirm_kill.rpc(net_id)


@rpc("authority", "call_remote", "reliable")
func confirm_kill(net_id: int) -> void:
	# Runs on CLIENTS: free the dead enemy's proxy now for responsive feedback.
	var proxy = _proxies.get(net_id)
	if proxy != null and is_instance_valid(proxy):
		proxy.queue_free()
	_proxies.erase(net_id)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Never open the pause menu while the level-up card flow is running — it owns
	# the paused state and the picker UI; overlapping would conflict.
	if _choosing:
		return
	if _pause_menu == null:
		return
	if _pause_menu.is_open():
		_pause_menu.close()
	else:
		_pause_menu.open()


func get_elapsed() -> float:
	return elapsed


func get_kills() -> int:
	return kills


# ── System selector ───────────────────────────────────────────────────────────

## Returns the active upgrade system — SkillSystem if available, else UpgradeSystem.
## Used by level-up flow. Tests that need the legacy path should set skill_system = null.
func _active_system():
	return skill_system if skill_system != null else upgrade_system


# ── GameEvents handlers ───────────────────────────────────────────────────────

func _on_enemy_killed(pos: Vector3, xp: int) -> void:
	kills += 1
	if _gem_scene == null or _player == null:
		return
	var gem: XPGem3D = _gem_scene.instantiate() as XPGem3D
	gem.setup_party(xp, _players)
	var parent := get_parent()
	if parent:
		# Defer insertion: enemy_killed_3d can fire from inside a physics callback.
		# Adding an Area3D during physics query flush prevents monitoring setup,
		# so body_entered never fires. Deferring moves insertion to a safe point.
		#
		# pos is a WORLD coordinate. global_position is only valid once the node is
		# in the scene tree, so we set it via tree_entered rather than using the
		# local .position property.
		gem.tree_entered.connect(func(): gem.global_position = pos, CONNECT_ONE_SHOT)
		parent.add_child.call_deferred(gem)


func _on_player_leveled_up(_level: int) -> void:
	var sys = _active_system()
	if sys == null or _upgrade_ui == null:
		return
	# If a level-up is already being presented, queue this one and return —
	# it will be presented after the current choice resolves.
	if _choosing:
		_pending_levelups += 1
		return
	# If everything is already maxed there is nothing to pick — never pause on an
	# empty picker (that softlocks the game). Grant a small bonus and move on.
	if not sys.has_available_choices():
		_grant_max_bonus()
		return
	_choosing = true
	get_tree().paused = true
	_present_next()


## Present a fresh choice set. build_choices is re-evaluated each call so an
## evolution/synergy that becomes available across stacked level-ups is offered.
func _present_next() -> void:
	var sys = _active_system()
	# A pick earlier in this chain may have exhausted every upgrade; never show an
	# empty picker (softlock). Grant the maxed bonus and resolve the queue instead.
	if sys == null or not sys.has_available_choices():
		_grant_max_bonus()
		_resolve_next_or_unpause()
		return
	_upgrade_ui.present(sys, _player)


func _on_player_died() -> void:
	RunState.last_run = {"time": elapsed, "kills": kills}
	if is_inside_tree():
		get_tree().paused = false
		get_tree().change_scene_to_file(GAME_OVER_SCENE)


# ── Upgrade routing ───────────────────────────────────────────────────────────

## SkillSystem routing: called when skill_system is active.
## SKILL at skill_level==1 after apply → ACQUIRE (first-time); else LEVEL.
## PASSIVE → apply_skill_passive. SYNERGY → evolve_skill. GENERIC → apply_stat_upgrade.
func _route_skill_upgrade(u: Upgrade) -> void:
	if _player == null:
		return
	match u.kind:
		Upgrade.Kind.SKILL:
			var sid := u.skill_id
			if skill_system.skill_level(sid) == 1:
				# First acquisition (0→1): instantiate weapon and add to player.
				var skill_data: SkillData = _skill_by_id.get(sid)
				if skill_data and skill_data.weapon_scene:
					_player.acquire_skill(sid, skill_data.weapon_scene)
			else:
				_player.level_skill(sid)
		Upgrade.Kind.PASSIVE:
			_player.apply_skill_passive(u.skill_id, u.effect_value)
		Upgrade.Kind.SYNERGY:
			_player.evolve_skill(u.skill_id)
		Upgrade.Kind.GENERIC:
			_player.apply_stat_upgrade(u.effect_kind, u.effect_value)


## Legacy UpgradeSystem routing: used when upgrade_system is active.
## Kept for backward compatibility with existing tests and the 2D-compatible flow.
## Called AFTER upgrade_system.apply(u) — routes the effect to player/weapon.
## Separated so it can be unit-tested without a full scene.
func _apply_upgrade(u: Upgrade) -> void:
	if _player == null:
		return
	match u.kind:
		Upgrade.Kind.SIGNATURE:
			if _player.weapon:
				_player.weapon.level_up()
		Upgrade.Kind.EVOLUTION:
			if _player.weapon:
				_player.weapon.evolve()
		Upgrade.Kind.PASSIVE:
			if _player.weapon:
				_player.weapon.apply_passive(u.effect_value)
		Upgrade.Kind.GENERIC:
			_player.apply_stat_upgrade(u.effect_kind, u.effect_value)


func _on_upgrade_chosen(u: Upgrade) -> void:
	if skill_system != null:
		skill_system.apply(u)
		_route_skill_upgrade(u)
	elif upgrade_system != null:
		upgrade_system.apply(u)
		_apply_upgrade(u)
	_resolve_next_or_unpause()


## Resolve the next queued level-up (if any) before unpausing, so no level-up
## loses its reward and the tree only resumes once all are done.
## When the final level-up resolves and play resumes, the player receives
## LEVELUP_INVULN seconds of invulnerability to re-orient safely.
func _resolve_next_or_unpause() -> void:
	if _pending_levelups > 0:
		_pending_levelups -= 1
		_present_next()  # stay paused, _choosing stays true
	else:
		_choosing = false
		get_tree().paused = false
		# Grant i-frame window only on the final resolve (not per stacked level-up).
		if is_instance_valid(_player) and _player.has_method("set_invulnerable"):
			# blink=false: the level-up safety window must not flicker the model.
			_player.set_invulnerable(LEVELUP_INVULN, false)


## Courtesy bonus for a level-up gained when every upgrade is already maxed:
## a small permanent HP boost (also heals), so leveling still rewards and the
## picker is never shown empty.
func _grant_max_bonus() -> void:
	if _player and _player.has_method("apply_stat_upgrade"):
		_player.apply_stat_upgrade(&"max_hp", 5.0)


# ── Party spawning (Task D2) ──────────────────────────────────────────────────

## True only in a real networked session. The engine defaults multiplayer_peer to an
## OfflineMultiplayerPeer (never null) in solo play and headless tests, so a plain
## null check would wrongly route solo spawns through the replicating spawner.
func _is_networked() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


## Spawn one Player3D per entry in RunState.party. Solo (no multiplayer peer)
## instantiates directly and notifies via _on_player_spawned; networked play spawns
## through the MultiplayerSpawner on the host only (it replicates + runs the callback
## on every peer, firing `spawned` there). Falls back to a single default player when
## the party is empty (the legacy solo path), preserving today's behaviour exactly.
func _spawn_party() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var players_root: Node3D = parent.get_node_or_null("Players") as Node3D
	_player_spawner = parent.get_node_or_null("PlayerSpawner") as MultiplayerSpawner
	if players_root == null or _player_spawner == null:
		return
	_player_spawner.spawn_function = Callable(self, "_do_spawn_player")
	if not _player_spawner.spawned.is_connected(_on_player_spawned):
		_player_spawner.spawned.connect(_on_player_spawned)  # fires on ALL peers per spawn

	var party: Dictionary = RunState.party
	if party.is_empty():
		party = {1: _fallback_fighter_path()}
	var pids: Array = party.keys()
	pids.sort()

	for i in range(pids.size()):
		var pid := int(pids[i])
		var data := {
			"peer_id": pid,
			"fighter": String(party[pids[i]]),
			"pos": PlayerSpawn.spawn_point(i, pids.size(), PARTY_SPAWN_RADIUS),
		}
		if not _is_networked():
			# Solo / offline (incl. headless tests): instantiate directly (the spawner
			# only replicates over a real peer) and notify ourselves, since `spawned`
			# does not fire reliably without a live session.
			var node := _do_spawn_player(data)
			players_root.add_child(node, true)
			_on_player_spawned(node)
		elif multiplayer.is_server():
			_player_spawner.spawn(data)  # host only; replicates + runs callback on all peers
		# Clients: do nothing — the spawner delivers the player and fires `spawned`.


## Runs on EVERY peer with identical `data`. Builds a Player3D, assigns deterministic
## name + network authority + spawn position BEFORE _ready(), and returns it. The fighter
## path is stashed as metadata; setup() is deferred to _on_player_spawned so it runs AFTER
## the node is in the tree (Player3D.setup relies on its @onready $Model, which is only
## bound on tree entry — running setup pre-tree would silently skip model/HP-bar install).
## The caller (spawner in networked, us in solo) is responsible for add_child.
func _do_spawn_player(data: Dictionary) -> Node:
	var pid := int(data["peer_id"])
	var p: Player3D = PLAYER_SCENE.instantiate() as Player3D
	p.name = "Player_%d" % pid          # deterministic across peers
	p.peer_id = pid
	p.set_multiplayer_authority(pid)    # authority set before _ready()
	p.add_to_group("player")
	# Guard empty/invalid fighter path (latent D1 gap): fall back to the default.
	var fighter := String(data["fighter"])
	if fighter.is_empty():
		fighter = _fallback_fighter_path()
	p.set_meta("fighter_path", fighter)
	p.position = data["pos"]
	return p


## Called once per spawned player, on every peer, AFTER it is in the tree. Sets the
## player up with its fighter (now that @onready $Model is bound), tracks it, refreshes
## enemy-targeting, and focuses the camera on the LOCAL player when it arrives.
func _on_player_spawned(node: Node) -> void:
	var p := node as Player3D
	if p != null and p.character_data == null and p.has_meta("fighter_path"):
		p.setup(load(String(p.get_meta("fighter_path"))) as CharacterData)
	_players.append(node)
	_player = _players[0]                 # legacy single ref for HUD/camera/skill wiring
	if _spawner != null and _spawner.has_method("setup_party"):
		_spawner.setup_party(_players)     # refresh party targeting as players arrive
	if node == _local_player():
		_focus_camera_on(node)


## The player owned by this peer: peer_id 1 in solo, else our unique multiplayer id.
## Falls back to the first player so callers always get a valid node when any exist.
func _local_player():
	var uid := multiplayer.get_unique_id() if _is_networked() else 1
	for p in _players:
		if p.peer_id == uid:
			return p
	return _players[0] if not _players.is_empty() else null


## Point the GameCamera3D at `node` (the local player). No-op if there is no camera.
func _focus_camera_on(node) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var cam := parent.get_node_or_null("GameCamera3D") as GameCamera3D
	if cam:
		cam.target = node


## The default single-player fighter path used when the party is empty or an entry is
## blank: the character the solo flow picked (RunState.selected_character), else ziv_3d.
func _fallback_fighter_path() -> String:
	var sel: Resource = RunState.selected_character
	if sel != null and not String(sel.resource_path).is_empty():
		return sel.resource_path
	return ZIV_3D_PATH
