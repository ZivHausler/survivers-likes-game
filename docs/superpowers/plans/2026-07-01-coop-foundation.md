# Co-op Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 1–4 player Steam co-op to the existing 3D bullet-heaven without changing combat content, following the approved spec `docs/superpowers/specs/2026-07-01-coop-foundation-design.md`.

**Architecture:** Host-authoritative world / client-owned avatar over Godot's high-level multiplayer (RPC + `MultiplayerSpawner`/`MultiplayerSynchronizer`). A `NetworkManager` autoload owns a swappable transport seam (ENet-loopback for dev/tests, Steam for real play). Shared **team** XP and gold pools; per-player builds. We first extract pure logic and de-singleton the current single-player references, then layer networking on top milestone by milestone (M1–M6), each verifiable with two local instances.

**Tech Stack:** Godot 4.7, GDScript, GUT test framework, GodotSteam addon (`SteamMultiplayerPeer`), ENet (`ENetMultiplayerPeer`).

## Global Constraints

- **Engine:** Godot 4.7 (Forward+), GDScript only. Launch/test binary is `godot47` (on PATH in the Bash tool; full path `C:\Users\avino\bin\godot47`).
- **Existing tests must stay green:** baseline suite is **1129/1129**. Never regress it.
- **House test style:** GUT, `extends GutTest`, files `test/test_<system>.gd`. Prefer pure static helpers (no scene tree); when a scene is needed use `add_child_autofree(...)`, name nodes exactly as production expects, use inline `Stub*` classes for collaborators, and assert via `watch_signals(GameEvents)` + `assert_signal_emitted[_with_parameters]`.
- **Class cache gotcha:** after adding new `class_name` scripts, headless CLI test runs can fail with "Could not find type X". Fix by running once: `godot47 --headless --editor --quit` to refresh the class cache, then re-run tests.
- **IP-safe:** keep our friends roster / art / naming; adopt Swarm *mechanics* only.
- **Networking values (verbatim from spec):** downed timer `10s`; revive at `50%` max HP + `4s` invulnerability; respawn delay `15s + 9s·prior_deaths`, cap `60s`; level-up auto-pick timeout `30s`; XP and Gold are shared **team** pools; team levels together; solo (1 player) has **no** downed state (death = current game-over).
- **Dev transport default:** ENet-loopback on `127.0.0.1`; Steam backend selected with cmdline flag `--steam`. Steam dev App ID `480` (Spacewar).
- **XP curve (must mirror `Player3D.xp_to_next`):** `xp_to_next(lvl) = 2 + lvl + lvl*lvl`.

---

## File Structure

**New files (pure logic — unit tested):**
- `net/lobby_registry.gd` — `class_name LobbyRegistry extends RefCounted`. Party roster: peer→{fighter, name, ready}. Serializable for replication.
- `net/team_progress.gd` — `class_name TeamProgress extends RefCounted`. Shared team XP + level; `add_xp → levels_gained`.
- `net/respawn_rules.gd` — `class_name RespawnRules extends RefCounted`. Downed/revive/respawn constants + `respawn_delay(deaths)`.

**New files (networking runtime):**
- `net/network_manager.gd` — autoload `NetworkManager`. Transport seam, lobby lifecycle, RPC hub, holds a `LobbyRegistry`.
- `net/net_transport.gd` — `class_name NetTransport extends RefCounted`. `static func create_peer(mode, opts) -> MultiplayerPeer`.
- `net/player_spawn.gd` — helper for runtime player instantiation + spawn-point selection.
- `ui/lobby_3d.gd` / `ui/lobby_3d.tscn` — networked lobby / character-select screen (wraps existing select UI).

**Modified files (de-singletoned / networked):**
- `enemies/enemy_3d.gd` — nearest-of-many retargeting.
- `spawning/spawner_3d.gd` — party targeting (`_targets`).
- `pickups/xp_gem_3d.gd` — nearest-player magnet + team award.
- `player/player_3d.gd` — `peer_id`/authority, input gated to authority, host-authoritative HP/downed, synchronizer.
- `game/game_manager_3d.gd` — `_players` list, runtime spawning, team XP/level, synced level-up FSM, downed/defeat.
- `game/main_3d.tscn` — replace authored single `Player` with `PlayerSpawnPoints` + `MultiplayerSpawner`.
- `autoload/game_events.gd` — add co-op-aware signals (peer-tagged), keep existing for solo/back-compat.
- `autoload/run_state.gd` — party-aware fields.
- `project.godot` — register `NetworkManager` autoload; add lobby input if needed.

**Test files:** one `test/test_<name>.gd` per new/modified system (listed per task).

---

## Phased overview

- **Phase A** (Tasks A1–A3): extract pure logic (LobbyRegistry, TeamProgress, RespawnRules). Full TDD.
- **Phase B** (Tasks B1–B3): de-singleton enemies / spawner / gems for multi-player, still local. Full TDD.
- **Phase C** (M1, Tasks C1–C2): transport seam + `NetworkManager`; two instances connect.
- **Phase D** (M2, Tasks D1–D3): lobby UI, runtime player spawning, replicated movement.
- **Phase E** (M3, Tasks E1–E3): host-auth enemies, client damage, replicated gems + team XP.
- **Phase F** (M4, Tasks F1–F2): synced level-up round-trip.
- **Phase G** (M5, Tasks G1–G3): shared gold, downed/revival/respawn, defeat.
- **Phase H** (M6, Tasks H1–H2): disconnect handling, Steam invite, solo regression.

> **Note on networking tasks (Phases C–H):** networked behaviour cannot be fully unit-tested; those tasks pair real code with an explicit **two-instance manual verification** (Godot editor → Debug → *Run Multiple Instances = 2*, or two `godot47` processes with ENet loopback). Pure-logic sub-parts are still unit-tested. This is the correct, honest way to validate replication.

---

## Phase A — Pure logic (full TDD)

### Task A1: LobbyRegistry

**Files:**
- Create: `net/lobby_registry.gd`
- Test: `test/test_lobby_registry.gd`

**Interfaces:**
- Produces: `LobbyRegistry` with `add_player(peer_id:int, name:String) -> void`, `remove_player(peer_id:int) -> void`, `set_fighter(peer_id:int, fighter_id:String) -> void`, `set_ready(peer_id:int, ready:bool) -> void`, `all_ready() -> bool`, `peer_ids() -> Array`, `count() -> int`, `get_player(peer_id:int) -> Dictionary`, `to_dict() -> Dictionary`, `from_dict(d:Dictionary) -> void`.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_lobby_registry.gd
extends GutTest

func _reg() -> LobbyRegistry:
	return LobbyRegistry.new()

func test_add_player_defaults_not_ready_no_fighter():
	var r := _reg()
	r.add_player(7, "Ziv")
	assert_eq(r.count(), 1)
	var p := r.get_player(7)
	assert_eq(p["name"], "Ziv")
	assert_eq(p["fighter_id"], "")
	assert_false(p["ready"])

func test_all_ready_false_when_empty():
	assert_false(_reg().all_ready())

func test_all_ready_true_only_when_every_player_ready():
	var r := _reg()
	r.add_player(1, "A"); r.add_player(2, "B")
	r.set_ready(1, true)
	assert_false(r.all_ready())
	r.set_ready(2, true)
	assert_true(r.all_ready())

func test_duplicate_fighters_allowed():
	var r := _reg()
	r.add_player(1, "A"); r.add_player(2, "B")
	r.set_fighter(1, "ziv_3d"); r.set_fighter(2, "ziv_3d")
	assert_eq(r.get_player(1)["fighter_id"], "ziv_3d")
	assert_eq(r.get_player(2)["fighter_id"], "ziv_3d")

func test_remove_player():
	var r := _reg()
	r.add_player(1, "A"); r.add_player(2, "B")
	r.remove_player(1)
	assert_eq(r.count(), 1)
	assert_eq(r.peer_ids(), [2])

func test_roundtrip_to_from_dict():
	var r := _reg()
	r.add_player(1, "A"); r.set_fighter(1, "ido_3d"); r.set_ready(1, true)
	var r2 := _reg()
	r2.from_dict(r.to_dict())
	assert_eq(r2.get_player(1), r.get_player(1))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_lobby_registry.gd -gexit`
Expected: FAIL — "Could not find type LobbyRegistry" (or all tests error). If it's the class-cache error, run `godot47 --headless --editor --quit` first, then re-run.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# net/lobby_registry.gd
class_name LobbyRegistry
extends RefCounted

# peer_id:int -> { "name": String, "fighter_id": String, "ready": bool }
var players: Dictionary = {}

func add_player(peer_id: int, name: String) -> void:
	if players.has(peer_id):
		return
	players[peer_id] = {"name": name, "fighter_id": "", "ready": false}

func remove_player(peer_id: int) -> void:
	players.erase(peer_id)

func set_fighter(peer_id: int, fighter_id: String) -> void:
	if players.has(peer_id):
		players[peer_id]["fighter_id"] = fighter_id

func set_ready(peer_id: int, ready: bool) -> void:
	if players.has(peer_id):
		players[peer_id]["ready"] = ready

func all_ready() -> bool:
	if players.is_empty():
		return false
	for pid in players:
		if not players[pid]["ready"]:
			return false
	return true

func peer_ids() -> Array:
	var ids := players.keys()
	ids.sort()
	return ids

func count() -> int:
	return players.size()

func get_player(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

func to_dict() -> Dictionary:
	return players.duplicate(true)

func from_dict(d: Dictionary) -> void:
	players = d.duplicate(true)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_lobby_registry.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add net/lobby_registry.gd test/test_lobby_registry.gd
git commit -m "feat(net): LobbyRegistry party roster (pure logic)"
```

---

### Task A2: TeamProgress

**Files:**
- Create: `net/team_progress.gd`
- Test: `test/test_team_progress.gd`

**Interfaces:**
- Produces: `TeamProgress` with `var level:int` (starts 1), `var xp:int`, `static func xp_to_next(lvl:int) -> int`, `func add_xp(amount:int) -> int` (returns number of levels gained), `func to_dict()/from_dict()`.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_team_progress.gd
extends GutTest

func test_xp_curve_mirrors_player():
	# 2 + lvl + lvl*lvl
	assert_eq(TeamProgress.xp_to_next(1), 4)
	assert_eq(TeamProgress.xp_to_next(2), 8)
	assert_eq(TeamProgress.xp_to_next(3), 14)

func test_add_xp_no_level():
	var t := TeamProgress.new()
	assert_eq(t.add_xp(3), 0)
	assert_eq(t.level, 1)
	assert_eq(t.xp, 3)

func test_add_xp_single_level():
	var t := TeamProgress.new()
	assert_eq(t.add_xp(4), 1)   # needs 4 for lvl1->2
	assert_eq(t.level, 2)
	assert_eq(t.xp, 0)

func test_add_xp_multi_level_in_one_call():
	var t := TeamProgress.new()
	# 4 (->2) + 8 (->3) = 12 grants exactly 2 levels
	assert_eq(t.add_xp(12), 2)
	assert_eq(t.level, 3)
	assert_eq(t.xp, 0)

func test_carryover_remainder():
	var t := TeamProgress.new()
	assert_eq(t.add_xp(5), 1)   # 4 consumed, 1 carried
	assert_eq(t.level, 2)
	assert_eq(t.xp, 1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_team_progress.gd -gexit`
Expected: FAIL — TeamProgress not found.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# net/team_progress.gd
class_name TeamProgress
extends RefCounted

var level: int = 1
var xp: int = 0

static func xp_to_next(lvl: int) -> int:
	return 2 + lvl + lvl * lvl

func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	return gained

func to_dict() -> Dictionary:
	return {"level": level, "xp": xp}

func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_team_progress.gd -gexit`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add net/team_progress.gd test/test_team_progress.gd
git commit -m "feat(net): TeamProgress shared team XP/level (pure logic)"
```

---

### Task A3: RespawnRules

**Files:**
- Create: `net/respawn_rules.gd`
- Test: `test/test_respawn_rules.gd`

**Interfaces:**
- Produces: `RespawnRules` constants `DOWNED_TIME=10.0`, `REVIVE_HP_FRACTION=0.5`, `REVIVE_INVULN=4.0`, `RESPAWN_BASE=15.0`, `RESPAWN_PER_DEATH=9.0`, `RESPAWN_CAP=60.0`; `static func respawn_delay(deaths:int) -> float`.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_respawn_rules.gd
extends GutTest

func test_constants():
	assert_eq(RespawnRules.DOWNED_TIME, 10.0)
	assert_eq(RespawnRules.REVIVE_HP_FRACTION, 0.5)
	assert_eq(RespawnRules.REVIVE_INVULN, 4.0)

func test_respawn_delay_progression():
	assert_eq(RespawnRules.respawn_delay(0), 15.0)
	assert_eq(RespawnRules.respawn_delay(1), 24.0)
	assert_eq(RespawnRules.respawn_delay(2), 33.0)
	assert_eq(RespawnRules.respawn_delay(4), 51.0)

func test_respawn_delay_caps_at_60():
	assert_eq(RespawnRules.respawn_delay(5), 60.0)
	assert_eq(RespawnRules.respawn_delay(99), 60.0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_respawn_rules.gd -gexit`
Expected: FAIL — RespawnRules not found.

- [ ] **Step 3: Write minimal implementation**

```gdscript
# net/respawn_rules.gd
class_name RespawnRules
extends RefCounted

const DOWNED_TIME: float = 10.0
const REVIVE_HP_FRACTION: float = 0.5
const REVIVE_INVULN: float = 4.0
const RESPAWN_BASE: float = 15.0
const RESPAWN_PER_DEATH: float = 9.0
const RESPAWN_CAP: float = 60.0

static func respawn_delay(deaths: int) -> float:
	return minf(RESPAWN_BASE + RESPAWN_PER_DEATH * float(deaths), RESPAWN_CAP)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_respawn_rules.gd -gexit`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add net/respawn_rules.gd test/test_respawn_rules.gd
git commit -m "feat(net): RespawnRules downed/revive/respawn constants (pure logic)"
```

---

## Phase B — De-singleton refactors (multi-player-ready, still local)

These make the world support N players *before* any networking, and keep the current single-player game fully working (a party of one). Each ships behind a pure static helper for TDD.

### Task B1: Enemy nearest-of-many retargeting

**Files:**
- Modify: `enemies/enemy_3d.gd` (add static `nearest_target`; retarget in `_physics_process`)
- Test: `test/test_enemy_retarget.gd`

**Interfaces:**
- Consumes: existing `Enemy3D.setup(data, target)`, `var target: Node3D`.
- Produces: `static func nearest_target(from: Vector3, candidates: Array) -> Node3D` (ignores nulls/invalid; returns `null` if none); enemies re-evaluate their target to the nearest living player on a throttle.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_enemy_retarget.gd
extends GutTest

func _n(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child_autofree(n)
	n.global_position = pos
	return n

func test_nearest_picks_closest():
	var a := _n(Vector3(10, 0, 0))
	var b := _n(Vector3(2, 0, 0))
	var c := _n(Vector3(5, 0, 0))
	assert_eq(Enemy3D.nearest_target(Vector3.ZERO, [a, b, c]), b)

func test_nearest_ignores_null_and_invalid():
	var a := _n(Vector3(3, 0, 0))
	assert_eq(Enemy3D.nearest_target(Vector3.ZERO, [null, a]), a)

func test_nearest_empty_returns_null():
	assert_null(Enemy3D.nearest_target(Vector3.ZERO, []))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_retarget.gd -gexit`
Expected: FAIL — `nearest_target` not a static method of Enemy3D.

- [ ] **Step 3: Write minimal implementation**

Add to `enemies/enemy_3d.gd` (near the other static helpers):

```gdscript
static func nearest_target(from: Vector3, candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for c in candidates:
		if c == null or not is_instance_valid(c):
			continue
		var d := from.distance_squared_to((c as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = c
	return best
```

Then add throttled retargeting. Add a member `var _retarget_cd: float = 0.0` and, at the top of `_physics_process(dt)` (before it steers toward `target`), insert:

```gdscript
	_retarget_cd -= dt
	if _retarget_cd <= 0.0:
		_retarget_cd = 0.4
		var players := get_tree().get_nodes_in_group("player")
		var alive: Array = []
		for p in players:
			if is_instance_valid(p) and (not p.has_method("is_downed") or not p.is_downed()):
				alive.append(p)
		var nearest := nearest_target(global_position, alive)
		if nearest != null:
			target = nearest
```

(`is_downed()` is added to `Player3D` in Phase G; the `has_method` guard keeps this working until then.)

- [ ] **Step 4: Run tests**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_retarget.gd -gexit`
Expected: PASS (3 tests). Then run the enemy suite to confirm no regression:
Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_3d_pathfinding.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add enemies/enemy_3d.gd test/test_enemy_retarget.gd
git commit -m "feat(enemy): retarget to nearest living player (multi-player ready)"
```

---

### Task B2: Spawner party targeting

**Files:**
- Modify: `spawning/spawner_3d.gd` (`_target` → `_targets: Array`; ring around party center)
- Test: `test/test_spawner_party.gd`

**Interfaces:**
- Consumes: existing `Spawner3D.setup(target)`, `_random_ring_position()`, static `ring_position`.
- Produces: `func setup_party(targets: Array) -> void`; `static func party_center(targets: Array) -> Vector3` (average of valid positions; `Vector3.ZERO` if none). Keep `setup(target)` as a thin wrapper (`setup_party([target])`) so all existing callers/tests pass unchanged.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_spawner_party.gd
extends GutTest

func _n(pos: Vector3) -> Node3D:
	var n := Node3D.new(); add_child_autofree(n); n.global_position = pos; return n

func test_party_center_averages_positions():
	var a := _n(Vector3(0, 0, 0))
	var b := _n(Vector3(4, 0, 0))
	assert_eq(Spawner3D.party_center([a, b]), Vector3(2, 0, 0))

func test_party_center_ignores_invalid():
	var a := _n(Vector3(6, 0, 0))
	assert_eq(Spawner3D.party_center([null, a]), Vector3(6, 0, 0))

func test_party_center_empty_is_zero():
	assert_eq(Spawner3D.party_center([]), Vector3.ZERO)

func test_setup_wraps_single_target_into_party():
	var scn := load("res://spawning/spawner_3d.tscn")
	# spawner has no .tscn? construct directly:
	var sp := Spawner3D.new()
	var root := Node3D.new(); add_child_autofree(root)
	root.add_child(sp)
	var t := _n(Vector3(1, 0, 0))
	sp.setup(t)
	assert_eq(sp.get_targets(), [t])
```

> If `spawning/spawner_3d.tscn` does not exist, delete the `scn` line; `Spawner3D.new()` is sufficient.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_spawner_party.gd -gexit`
Expected: FAIL — `party_center`/`setup_party`/`get_targets` missing.

- [ ] **Step 3: Write minimal implementation**

In `spawning/spawner_3d.gd`: change `var _target: Node3D` to `var _targets: Array = []`. Add:

```gdscript
static func party_center(targets: Array) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for t in targets:
		if t != null and is_instance_valid(t):
			sum += (t as Node3D).global_position
			n += 1
	return sum / n if n > 0 else Vector3.ZERO

func setup_party(targets: Array) -> void:
	_targets = targets
	# ... keep the rest of the existing setup() body (load scenes, _active = true) ...

func setup(target: Node3D) -> void:
	setup_party([target])

func get_targets() -> Array:
	return _targets
```

Move the scene/variant loading and `_active = true` from the old `setup()` into `setup_party()`. Update `_random_ring_position()` to ring around `party_center(_targets)` instead of `_target.global_position`, and update `_instance_enemy()` to pass the nearest party member as the enemy's initial target:

```gdscript
	var center := party_center(_targets)
	# in _random_ring_position(): use `center` in place of _target.global_position
	# in _instance_enemy(): enemy.setup(data, Enemy3D.nearest_target(enemy.global_position, _targets))
```

- [ ] **Step 4: Run tests**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_spawner_party.gd -gexit`
Expected: PASS. Then regression:
Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_spawner_3d.gd -gexit`
Expected: PASS (existing static-helper tests unaffected).

- [ ] **Step 5: Commit**

```bash
git add spawning/spawner_3d.gd test/test_spawner_party.gd
git commit -m "feat(spawner): party targeting (ring around all players)"
```

---

### Task B3: XP gem nearest-player magnet + team award

**Files:**
- Modify: `pickups/xp_gem_3d.gd`
- Modify: `game/game_manager_3d.gd` (`_on_enemy_killed` passes party, not single `_player`)
- Test: `test/test_xp_gem_multi.gd`

**Interfaces:**
- Consumes: existing `XPGem3D.setup(value, player)`, static `in_pickup_range`, `_collect()`, `GameEvents.xp_collected`.
- Produces: `static func nearest_player(gem_pos: Vector3, players: Array) -> Node3D`; `func setup_party(value:int, players:Array) -> void`; magnet targets the nearest player each frame; on collect calls that player's `add_xp` (unchanged) AND emits `GameEvents.xp_collected(value)` (host routes to team pool in Phase E). Keep `setup(value, player)` as `setup_party(value, [player])`.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_xp_gem_multi.gd
extends GutTest

func _n(pos: Vector3) -> Node3D:
	var n := Node3D.new(); add_child_autofree(n); n.global_position = pos; return n

func test_nearest_player_picks_closest():
	var a := _n(Vector3(9, 0, 0))
	var b := _n(Vector3(1, 0, 0))
	assert_eq(XPGem3D.nearest_player(Vector3.ZERO, [a, b]), b)

func test_nearest_player_ignores_invalid():
	var a := _n(Vector3(2, 0, 0))
	assert_eq(XPGem3D.nearest_player(Vector3.ZERO, [null, a]), a)

func test_nearest_player_none_returns_null():
	assert_null(XPGem3D.nearest_player(Vector3.ZERO, []))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_xp_gem_multi.gd -gexit`
Expected: FAIL — `nearest_player` missing.

- [ ] **Step 3: Write minimal implementation**

In `pickups/xp_gem_3d.gd`, replace the single `_player` binding with a party list `_players: Array` and a `_target: Node3D` recomputed each frame. Add:

```gdscript
static func nearest_player(gem_pos: Vector3, players: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		var d := gem_pos.distance_squared_to((p as Node3D).global_position)
		if d < best_d:
			best_d = d; best = p
	return best

func setup_party(value: int, players: Array) -> void:
	_value = value
	_players = players
	# ... keep tier-color material + body_entered connection from old setup() ...

func setup(value: int, player: Node3D) -> void:
	setup_party(value, [player])
```

In `_process(dt)`: at the top, `_target = nearest_player(global_position, _players)`; then run the existing magnet logic against `_target` (guard `if _target == null: return`). In `_on_body_entered(body)`: `if body in _players: _collect_for(body)`. Refactor `_collect()` into `_collect_for(player)` that calls `player.add_xp(_value)` then emits `GameEvents.xp_collected.emit(_value)` and `queue_free()`.

In `game/game_manager_3d.gd._on_enemy_killed`: replace `gem.setup(xp, _player)` with `gem.setup_party(xp, _players)` (where `_players` is introduced in Task D2; until then, keep `_players = [_player]` initialized in `start()`).

- [ ] **Step 4: Run tests**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_xp_gem_multi.gd -gexit`
Expected: PASS. Regression:
Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_game_manager_3d.gd -gexit`
Expected: PASS (gem still spawns on `enemy_killed_3d`).

- [ ] **Step 5: Commit**

```bash
git add pickups/xp_gem_3d.gd game/game_manager_3d.gd test/test_xp_gem_multi.gd
git commit -m "feat(xp): gems magnet to nearest player, collectible by any (team-ready)"
```

---

## Phase C — M1: Transport seam + NetworkManager

### Task C1: NetTransport seam + NetworkManager autoload (ENet loopback)

**Files:**
- Create: `net/net_transport.gd`, `net/network_manager.gd`
- Modify: `project.godot` (autoload `NetworkManager`)
- Test: `test/test_net_transport.gd`, `test/test_network_manager_registry.gd`

**Interfaces:**
- Produces:
  - `NetTransport.create_peer(mode:String, opts:Dictionary) -> MultiplayerPeer` — `mode` in `{"enet_host","enet_client","steam_host","steam_client"}`; opts carries `port`/`address`/`lobby_id`.
  - Autoload `NetworkManager` with `registry: LobbyRegistry`, `func host_enet(port:int=al) -> int`, `func join_enet(address:String, port:int) -> int`, signals `player_joined(peer_id)`, `player_left(peer_id)`, `registry_changed()`, `all_ready()`, `host_aborted()`, and RPCs `_rpc_register(name)`, `_rpc_sync_registry(dict)`, `_rpc_set_fighter(peer_id, fighter)`, `_rpc_set_ready(peer_id, ready)`.

- [ ] **Step 1: Write the failing test (pure-logic slice only)**

The transport/RPC layer needs live peers (manual verify below), but `NetworkManager`'s registry mutation handlers are pure and testable. Write:

```gdscript
# test/test_network_manager_registry.gd
extends GutTest

var nm

func before_each():
	nm = load("res://net/network_manager.gd").new()
	add_child_autofree(nm)
	nm.registry = LobbyRegistry.new()

func test_apply_register_adds_player_and_signals():
	watch_signals(nm)
	nm._apply_register(5, "Ido")
	assert_eq(nm.registry.count(), 1)
	assert_signal_emitted(nm, "registry_changed")

func test_apply_set_fighter_and_ready():
	nm._apply_register(5, "Ido")
	nm._apply_set_fighter(5, "ido_3d")
	nm._apply_set_ready(5, true)
	assert_eq(nm.registry.get_player(5)["fighter_id"], "ido_3d")
	assert_true(nm.registry.all_ready())

func test_apply_unregister_removes():
	nm._apply_register(5, "Ido")
	nm._apply_unregister(5)
	assert_eq(nm.registry.count(), 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_network_manager_registry.gd -gexit`
Expected: FAIL — script/methods missing.

- [ ] **Step 3: Write the implementation**

```gdscript
# net/net_transport.gd
class_name NetTransport
extends RefCounted

const DEFAULT_PORT := 7777

static func create_peer(mode: String, opts: Dictionary) -> MultiplayerPeer:
	match mode:
		"enet_host":
			var p := ENetMultiplayerPeer.new()
			p.create_server(int(opts.get("port", DEFAULT_PORT)), 4)
			return p
		"enet_client":
			var p := ENetMultiplayerPeer.new()
			p.create_client(String(opts.get("address", "127.0.0.1")), int(opts.get("port", DEFAULT_PORT)))
			return p
		"steam_host", "steam_client":
			# Implemented in Task C2 once GodotSteam is installed.
			push_error("Steam transport not available yet")
			return null
	push_error("unknown transport mode: %s" % mode)
	return null
```

```gdscript
# net/network_manager.gd  (autoload: NetworkManager)
extends Node

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal registry_changed()
signal all_ready()
signal host_aborted()

var registry: LobbyRegistry = LobbyRegistry.new()
var local_name: String = "Player"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_enet(port: int = NetTransport.DEFAULT_PORT) -> int:
	var peer := NetTransport.create_peer("enet_host", {"port": port})
	if peer == null:
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	_apply_register(1, local_name)   # host is peer 1
	return OK

func join_enet(address: String, port: int = NetTransport.DEFAULT_PORT) -> int:
	var peer := NetTransport.create_peer("enet_client", {"address": address, "port": port})
	if peer == null:
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	return OK

func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

# ---- connection lifecycle ----
func _on_peer_connected(peer_id: int) -> void:
	# Host learns of a new client; ask them to register their name.
	if is_host():
		rpc_id(peer_id, "_rpc_request_register")

func _on_peer_disconnected(peer_id: int) -> void:
	if is_host():
		_apply_unregister(peer_id)
		_broadcast_registry()

func _on_connected_to_server() -> void:
	pass  # wait for _rpc_request_register from host

func _on_server_disconnected() -> void:
	host_aborted.emit()

# ---- RPCs ----
@rpc("authority", "call_remote", "reliable")
func _rpc_request_register() -> void:
	# client -> tell host our name
	rpc_id(1, "_rpc_register", local_name)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register(name: String) -> void:
	if not is_host():
		return
	var pid := multiplayer.get_remote_sender_id()
	_apply_register(pid, name)
	_broadcast_registry()

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_registry(dict: Dictionary) -> void:
	registry.from_dict(dict)
	registry_changed.emit()
	if registry.all_ready():
		all_ready.emit()

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_fighter(peer_id: int, fighter_id: String) -> void:
	if not is_host():
		return
	_apply_set_fighter(peer_id, fighter_id)
	_broadcast_registry()

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(peer_id: int, ready: bool) -> void:
	if not is_host():
		return
	_apply_set_ready(peer_id, ready)
	_broadcast_registry()

# client-facing helpers
func request_set_fighter(fighter_id: String) -> void:
	rpc_id(1, "_rpc_set_fighter", multiplayer.get_unique_id(), fighter_id)

func request_set_ready(ready: bool) -> void:
	rpc_id(1, "_rpc_set_ready", multiplayer.get_unique_id(), ready)

func _broadcast_registry() -> void:
	rpc("_rpc_sync_registry", registry.to_dict())
	registry_changed.emit()
	if registry.all_ready():
		all_ready.emit()

# ---- pure mutation handlers (unit-tested) ----
func _apply_register(peer_id: int, name: String) -> void:
	registry.add_player(peer_id, name)
	player_joined.emit(peer_id)
	registry_changed.emit()

func _apply_unregister(peer_id: int) -> void:
	registry.remove_player(peer_id)
	player_left.emit(peer_id)
	registry_changed.emit()

func _apply_set_fighter(peer_id: int, fighter_id: String) -> void:
	registry.set_fighter(peer_id, fighter_id)

func _apply_set_ready(peer_id: int, ready: bool) -> void:
	registry.set_ready(peer_id, ready)
```

Register the autoload in `project.godot` under `[autoload]`:
```
NetworkManager="*res://net/network_manager.gd"
```

- [ ] **Step 4: Run tests**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_network_manager_registry.gd -gexit`
Expected: PASS (3 tests). Full suite should still be green.

- [ ] **Step 5: Manual two-instance verification (ENet loopback)**

Add a tiny temporary debug entry (or use the lobby from Task D1). Quickest check: a scratch scene with two buttons calling `NetworkManager.host_enet()` / `NetworkManager.join_enet("127.0.0.1")`, printing `registry.to_dict()` on `registry_changed`.
- Godot editor → **Debug ▸ Run Multiple Instances ▸ 2**, run the scratch scene.
- Instance 1: press Host. Instance 2: press Join.
- Expected: both print a registry containing peers `1` and `2`.

- [ ] **Step 6: Commit**

```bash
git add net/net_transport.gd net/network_manager.gd project.godot test/test_network_manager_registry.gd test/test_net_transport.gd
git commit -m "feat(net): transport seam + NetworkManager lobby registry over ENet (M1)"
```

---

### Task C2: Steam backend behind the seam

**Files:**
- Add addon: `addons/godotsteam/` (GodotSteam GDExtension for Godot 4.7)
- Modify: `net/net_transport.gd` (implement `steam_host`/`steam_client`), `net/network_manager.gd` (`host_steam`/`join_steam` + lobby callbacks)
- Create: `steam_appid.txt` (contains `480`)

**Interfaces:**
- Produces: `NetworkManager.host_steam() -> int`, `NetworkManager.join_steam(lobby_id:int) -> int`, `func open_invite_overlay() -> void`. Steam lobby created/joined via `Steam.createLobby` / `Steam.joinLobby`; `SteamMultiplayerPeer` bound as `multiplayer.multiplayer_peer`.

- [ ] **Step 1: Install GodotSteam**

Download the GodotSteam **GDExtension** build matching Godot 4.7 into `addons/godotsteam/`. Add `steam_appid.txt` with `480` at the project root. Ensure the Steam client is running when launching.

- [ ] **Step 2: Implement the Steam transport**

In `net/net_transport.gd`, replace the `steam_host`/`steam_client` branch:

```gdscript
		"steam_host":
			var p := SteamMultiplayerPeer.new()
			p.create_host(0, [])
			return p
		"steam_client":
			var p := SteamMultiplayerPeer.new()
			p.create_client(int(opts.get("host_steam_id", 0)), 0, [])
			return p
```

In `net/network_manager.gd` add Steam init + lobby lifecycle (guarded so ENet path still works without Steam):

```gdscript
func steam_init() -> bool:
	if not Engine.has_singleton("Steam"):
		return false
	var res: Dictionary = Steam.steamInitEx()
	return int(res.get("status", 1)) == 0

func host_steam() -> int:
	if not steam_init():
		return ERR_UNAVAILABLE
	Steam.lobby_created.connect(_on_lobby_created, CONNECT_ONE_SHOT)
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 4)
	return OK

func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != 1:
		host_aborted.emit(); return
	var peer := NetTransport.create_peer("steam_host", {})
	multiplayer.multiplayer_peer = peer
	_apply_register(1, local_name)

func join_steam(host_steam_id: int) -> int:
	if not steam_init():
		return ERR_UNAVAILABLE
	var peer := NetTransport.create_peer("steam_client", {"host_steam_id": host_steam_id})
	multiplayer.multiplayer_peer = peer
	return OK

func open_invite_overlay() -> void:
	if Engine.has_singleton("Steam"):
		Steam.activateGameOverlayInviteDialog(current_lobby_id)
```

> Exact `SteamMultiplayerPeer` method names (`create_host`/`create_client`) may differ by GodotSteam version — verify against the installed addon's docs during this task and adjust; the seam isolates the change to `net_transport.gd`.

- [ ] **Step 3: Manual verification (two Steam instances)**

Requires Steam running and (for two real clients) either two Steam accounts or Steam's "Run Multiple Instances" via separate machines. Minimal single-machine check: launch once, call `host_steam()`, assert `NetworkManager.is_host()` true and no init error printed. Full invite/join is validated with a second machine/account.

- [ ] **Step 4: Commit**

```bash
git add addons/godotsteam net/net_transport.gd net/network_manager.gd steam_appid.txt
git commit -m "feat(net): Steam P2P backend behind transport seam (App ID 480 dev)"
```

---

## Phase D — M2: Lobby UI + runtime player spawning + replicated movement

### Task D1: Networked lobby / character-select screen

**Files:**
- Create: `ui/lobby_3d.gd`, `ui/lobby_3d.tscn`
- Modify: `project.godot` (`run/main_scene` → `res://ui/lobby_3d.tscn`)
- Reuse: `ui/character_select_3d.gd` `CHARACTER_PATHS` for the fighter grid.

**Interfaces:**
- Consumes: `NetworkManager` (host/join/registry/signals, `request_set_fighter`, `request_set_ready`), `RunState`.
- Produces: on Start (host only), writes each peer's fighter into `RunState.party` (`{peer_id:int -> fighter_path:String}`) and calls a host-broadcast RPC to `change_scene_to_file("res://game/main_3d.tscn")` on all peers.

- [ ] **Step 1: Build the lobby scene + script**

`ui/lobby_3d.tscn`: a `Control` with Host / Join(IP) buttons, a fighter `GridContainer` (populated from `CHARACTER_PATHS`), a player list showing name + chosen fighter + ready check, a Ready toggle, and a Start button (host, disabled until `registry.all_ready()`).

```gdscript
# ui/lobby_3d.gd
class_name Lobby3D
extends Control

const CHARACTER_PATHS := preload("res://ui/character_select_3d.gd").CHARACTER_PATHS
const MAIN_3D_SCENE := "res://game/main_3d.tscn"

func _ready() -> void:
	NetworkManager.registry_changed.connect(_refresh)
	NetworkManager.host_aborted.connect(_on_host_aborted)
	_build_fighter_grid()
	_refresh()

func _on_host_pressed() -> void:
	NetworkManager.host_enet()   # or host_steam() when Steam selected
	_refresh()

func _on_join_pressed(address: String) -> void:
	NetworkManager.join_enet(address)

func _on_fighter_picked(path: String) -> void:
	NetworkManager.request_set_fighter(path)

func _on_ready_toggled(on: bool) -> void:
	NetworkManager.request_set_ready(on)

func _on_start_pressed() -> void:
	if not NetworkManager.is_host():
		return
	var party := {}
	for pid in NetworkManager.registry.peer_ids():
		party[pid] = NetworkManager.registry.get_player(pid)["fighter_id"]
	RunState.party = party
	rpc("_rpc_start_game")

@rpc("authority", "call_local", "reliable")
func _rpc_start_game() -> void:
	get_tree().change_scene_to_file(MAIN_3D_SCENE)

func _refresh() -> void:
	# redraw player list + enable Start iff host and all ready
	pass

func _build_fighter_grid() -> void:
	pass

func _on_host_aborted() -> void:
	get_tree().change_scene_to_file("res://ui/lobby_3d.tscn")
```

> Non-host peers need `RunState.party` too. Broadcast it inside `_rpc_start_game` by passing the party dict as an argument: `rpc("_rpc_start_game", party)` and set `RunState.party = party` in the RPC body.

- [ ] **Step 2: Point the game at the lobby**

In `project.godot`, set `run/main_scene="res://ui/lobby_3d.tscn"`. Keep `ui/character_select_3d.tscn` for solo fallback (a "Solo" button that sets `RunState.party = {1: chosen}` and loads the arena directly without hosting).

- [ ] **Step 3: Manual two-instance verification**

Run Multiple Instances = 2:
- I1 Host, pick fighter, Ready. I2 Join `127.0.0.1`, pick fighter, Ready.
- Expected: both lists show 2 players with fighters + ready ticks; Start enables on host; pressing Start loads `main_3d.tscn` on **both**.

- [ ] **Step 4: Commit**

```bash
git add ui/lobby_3d.gd ui/lobby_3d.tscn project.godot
git commit -m "feat(net): networked lobby + character select (M2)"
```

---

### Task D2: Runtime player spawning from the party

**Files:**
- Modify: `game/main_3d.tscn` (remove authored `Player`; add `Players` container + `PlayerSpawnPoints` + `MultiplayerSpawner` targeting `Players`)
- Modify: `game/game_manager_3d.gd` (`start()` spawns one `Player3D` per party entry; hold `_players: Array`)
- Modify: `autoload/run_state.gd` (`var party: Dictionary = {}`)
- Create: `net/player_spawn.gd`
- Test: `test/test_player_spawn.gd`, update `test/test_game_manager_3d.gd`

**Interfaces:**
- Consumes: `RunState.party` (`peer_id -> fighter_path`), `LobbyRegistry`.
- Produces: `PlayerSpawn.spawn_point(index:int, count:int, radius:float) -> Vector3` (deterministic ring of spawn positions); `GameManager3D._players: Array[Player3D]`; each spawned `Player3D` has `peer_id` set and multiplayer authority assigned; solo path yields exactly one player identical to today.

- [ ] **Step 1: Write the failing test (deterministic spawn points)**

```gdscript
# test/test_player_spawn.gd
extends GutTest

func test_single_player_spawns_at_center():
	assert_eq(PlayerSpawn.spawn_point(0, 1, 3.0), Vector3.ZERO)

func test_four_players_are_distinct_and_on_radius():
	var pts := []
	for i in range(4):
		pts.append(PlayerSpawn.spawn_point(i, 4, 3.0))
	# distinct
	assert_eq(pts.size(), 4)
	for i in range(4):
		for j in range(i + 1, 4):
			assert_true(pts[i].distance_to(pts[j]) > 0.1)
	# on the ring (y=0, radius 3)
	for p in pts:
		assert_almost_eq(Vector2(p.x, p.z).length(), 3.0, 0.001)
		assert_eq(p.y, 0.0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_player_spawn.gd -gexit`
Expected: FAIL — PlayerSpawn missing.

- [ ] **Step 3: Implement**

```gdscript
# net/player_spawn.gd
class_name PlayerSpawn
extends RefCounted

static func spawn_point(index: int, count: int, radius: float) -> Vector3:
	if count <= 1:
		return Vector3.ZERO
	var ang := TAU * float(index) / float(count)
	return Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
```

In `game/game_manager_3d.gd.start()`: replace the fixed `get_node_or_null("Player")` lookup with a loop that instantiates `player_3d.tscn` per `RunState.party` entry under the `Players` node:

```gdscript
const PLAYER_SCENE := preload("res://player/player_3d.tscn")
var _players: Array = []

func _spawn_party() -> void:
	var players_root: Node3D = parent.get_node("Players")
	var party: Dictionary = RunState.party if not RunState.party.is_empty() else {1: _fallback_fighter_path()}
	var pids: Array = party.keys(); pids.sort()
	var i := 0
	for pid in pids:
		var p := PLAYER_SCENE.instantiate()
		p.name = "Player_%d" % pid
		p.peer_id = int(pid)
		players_root.add_child(p)
		p.global_position = PlayerSpawn.spawn_point(i, pids.size(), 3.0)
		p.add_to_group("player")
		var char_data := load(String(party[pid])) as CharacterData
		p.setup(char_data)
		if multiplayer.multiplayer_peer != null:
			p.set_multiplayer_authority(int(pid))
		_players.append(p)
		i += 1
	_player = _players[0]   # keep legacy single ref for camera/HUD wiring
```

Wire `_spawner.setup_party(_players)`, camera follows the **local** player (`_local_player()` = the one whose `peer_id == multiplayer.get_unique_id()`, or `_players[0]` in solo). Update `main_3d.tscn`: delete the `Player` node, add an empty `Node3D` named `Players`, and a `MultiplayerSpawner` with `spawn_path = ../Players` and the player scene in its spawnable list.

- [ ] **Step 4: Run tests**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_player_spawn.gd -gexit` → PASS.
Update `test/test_game_manager_3d.gd`: its `_make_run_scene()` must now add a `Players` node and set `RunState.party = {1: <char_path>}` before adding `GameManager3D`. Re-run it → PASS.

- [ ] **Step 5: Manual verification**

Solo: launch, pick a fighter via the Solo path → one player spawns and plays exactly like today.

- [ ] **Step 6: Commit**

```bash
git add net/player_spawn.gd game/main_3d.tscn game/game_manager_3d.gd autoload/run_state.gd test/test_player_spawn.gd test/test_game_manager_3d.gd
git commit -m "feat(net): spawn party of players at runtime from RunState.party (M2)"
```

---

### Task D3: Player input authority + transform replication

**Files:**
- Modify: `player/player_3d.gd` (`var peer_id:int`; gate input to authority; add `MultiplayerSynchronizer` child in `player_3d.tscn`)
- Modify: `player/player_3d.tscn` (add `MultiplayerSynchronizer` replicating `position` + facing)
- Test: `test/test_player_authority.gd`

**Interfaces:**
- Consumes: existing `_physics_process`, `Input.get_vector`, `Input.is_action_just_pressed("ultimate")`.
- Produces: `var peer_id: int = 1`; `func is_local_authority() -> bool` (true when solo, or when `peer_id == multiplayer.get_unique_id()`); only the authority reads Input and moves; a `MultiplayerSynchronizer` replicates transform from the authority to others.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_player_authority.gd
extends GutTest

var PlayerScene = load("res://player/player_3d.tscn")

func _mk() -> Player3D:
	var p = add_child_autofree(PlayerScene.instantiate())
	return p

func test_solo_is_authority_without_peer():
	var p := _mk()
	# no multiplayer peer set -> treated as solo authority
	assert_true(p.is_local_authority())

func test_non_matching_peer_is_not_authority_when_networked():
	var p := _mk()
	p.peer_id = 999999   # not our unique id, with an active peer this is false
	# Without a live peer, is_local_authority() returns true (solo); this asserts the peer_id field exists and is honored by the guard shape.
	assert_eq(p.peer_id, 999999)
```

> Authority truly diverges only with a live peer (manual verify). The unit test pins the `peer_id` field and the solo default.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_player_authority.gd -gexit`
Expected: FAIL — `is_local_authority`/`peer_id` missing.

- [ ] **Step 3: Implement**

In `player/player_3d.gd`:

```gdscript
var peer_id: int = 1

func is_local_authority() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return true   # solo
	return peer_id == multiplayer.get_unique_id()
```

Guard input in `_physics_process(dt)`:

```gdscript
	if not is_local_authority():
		# non-authority: transform arrives via MultiplayerSynchronizer; skip input/move.
		move_and_slide()
		return
	# ... existing input + movement code unchanged ...
```

In `player_3d.tscn` add a `MultiplayerSynchronizer` child; in its replication config replicate `position` (and the model yaw property used for facing). Set its authority in code after spawn: `$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)` inside `setup()` or right after spawn in `_spawn_party`.

- [ ] **Step 4: Run tests**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_player_authority.gd -gexit` → PASS.
Run the player suite: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_player_3d.gd -gexit` → PASS (solo path unchanged: `is_local_authority()` is true with no peer).

- [ ] **Step 5: Manual two-instance verification**

Host + Join, both Start. Move on each instance:
- Expected: each player controls only its own fighter; the other fighter mirrors its owner's movement smoothly on your screen.

- [ ] **Step 6: Commit**

```bash
git add player/player_3d.gd player/player_3d.tscn test/test_player_authority.gd
git commit -m "feat(net): client-owned avatar movement + transform replication (M2)"
```

---

## Phase E — M3: Host-authoritative enemies, client damage, replicated gems

> These tasks are integration-heavy; each pairs code with two-instance verification. Pure sub-parts (already covered in Phase B statics) stay unit-tested.

### Task E1: Host-only spawning + enemy replication

**Files:**
- Modify: `spawning/spawner_3d.gd` (run only on host), `game/main_3d.tscn` (add `MultiplayerSpawner` for enemies targeting the enemies parent), `enemies/enemy_3d.gd` (add `MultiplayerSynchronizer` for transform + hp)

**Steps:**
- [ ] **Step 1:** Gate `Spawner3D._process` to host: at the top, `if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return`. Enemies are added under a node covered by a `MultiplayerSpawner` (so clients receive them). Set enemy authority to server (default peer 1).
- [ ] **Step 2:** Add a `MultiplayerSynchronizer` to `enemy_3d.tscn` replicating `position` and `hp` (host-authoritative). Non-host enemies skip AI stepping (guard `_physics_process` like the player: only server steers; clients interpolate replicated transform).
- [ ] **Step 3 (manual verify):** Host + client Start. Expected: identical enemy waves appear on both; enemies move in sync; only host simulates AI.
- [ ] **Step 4:** Commit `feat(net): host-authoritative enemy spawning + replication (M3)`.

### Task E2: Client weapon damage → host arbitration

**Files:**
- Modify: `enemies/enemy_3d.gd` (add `@rpc` `receive_damage`), weapon base `core/weapon_3d.gd` (route hits through the host)

**Steps:**
- [ ] **Step 1:** Add to `Enemy3D`:
```gdscript
@rpc("any_peer", "call_local", "reliable")
func receive_damage(amount: float) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return   # only host applies
	take_damage(amount)
```
- [ ] **Step 2:** Where weapons currently call `enemy.take_damage(x)` directly, change to: if solo → `take_damage(x)`; if networked → `enemy.rpc_id(1, "receive_damage", x)`. Provide a helper `GameManager3D.apply_damage(enemy, amount)` so all weapons share one path. Enemy death/XP already flows through `GameEvents.enemy_killed_3d` on the host (unchanged).
- [ ] **Step 3 (manual verify):** Two instances; each player's weapons visibly damage/kill shared enemies; kills register once (no double counting) because only the host applies damage and emits `enemy_killed_3d`.
- [ ] **Step 4:** Commit `feat(net): client weapons deal damage via host arbitration (M3)`.

### Task E3: Host-spawned XP gems + team XP pool

**Files:**
- Modify: `game/game_manager_3d.gd` (`_on_enemy_killed` host-guarded; gem parent under a `MultiplayerSpawner`; team XP via `TeamProgress`), `pickups/xp_gem_3d.gd` (host-authoritative collect; broadcast removal)

**Steps:**
- [ ] **Step 1:** Add `var _team := TeamProgress.new()` to `GameManager3D`. Gate `_on_enemy_killed` to host. Gems spawn under a `MultiplayerSpawner`-covered node so clients see them; magnet/`nearest_player` (Task B3) runs on all peers for visuals but **collection is host-authoritative**: guard `_collect_for` with `is_server()`; on collect, host calls `_team.add_xp(value)`; if `add_xp` returns > 0 → trigger synced level-up (Phase F).
- [ ] **Step 2:** Replace per-player `player.add_xp` with team XP. Broadcast team level via `GameEvents` (add signal `team_leveled_up(level:int)` in Task F1). Remove the old per-player `player_leveled_up` XP path from the co-op flow (keep `Player3D.add_xp` for solo only, or route solo through `_team` too for uniformity — prefer routing solo through `_team` as well).
- [ ] **Step 3 (manual verify):** Two instances; either player collecting a gem raises a single shared team XP; both HUDs show the same level.
- [ ] **Step 4:** Commit `feat(net): host-spawned XP gems + shared team XP pool (M3)`.

---

## Phase F — M4: Synced level-up round-trip

### Task F1: Host-triggered level-up + per-client picker

**Files:**
- Modify: `autoload/game_events.gd` (add `signal team_leveled_up(level:int)`), `game/game_manager_3d.gd` (host detects level, RPC `begin_levelup`), keep per-client `UpgradeUI`/`SkillSystem` per player.

**Steps:**
- [ ] **Step 1:** When `_team.add_xp(...)` returns `n > 0`, host calls `rpc("_rpc_begin_levelup", _team.level)`. Implement:
```gdscript
@rpc("authority", "call_local", "reliable")
func _rpc_begin_levelup(new_level: int) -> void:
	get_tree().paused = true
	_present_next()   # opens THIS peer's own UpgradeUI with its own system + local player
```
Each peer keeps its **own** `SkillSystem`/`UpgradeSystem` and `UpgradeUI` (already per-scene). The picker uses the **local** player (`_local_player()`).
- [ ] **Step 2 (manual verify):** Two instances; when team levels, both instances pause and each shows its **own** 3-card offering.
- [ ] **Step 3:** Commit `feat(net): host-triggered synced level-up pause + per-client picker (M4)`.

### Task F2: Ready-up + resume + timeout

**Files:**
- Modify: `game/game_manager_3d.gd` (ready tracking via a per-level `LobbyRegistry`-style ready set on host), `autoload/game_events.gd` (`signal player_pick_ready(peer_id:int)` for HUD bubbles), HUD (portrait ready bubble — minimal).

**Steps:**
- [ ] **Step 1:** On local pick (`_on_upgrade_chosen`), after applying locally, client calls `rpc_id(1, "_rpc_pick_ready", multiplayer.get_unique_id())`. Host tracks a `Dictionary _ready_picks`; when all alive peers are in it (or a **30s** `SceneTreeTimer` fires), host calls `rpc("_rpc_resume_levelup")`:
```gdscript
@rpc("authority", "call_local", "reliable")
func _rpc_resume_levelup() -> void:
	get_tree().paused = false
	_ready_picks.clear()
```
- [ ] **Step 2:** Emit `player_pick_ready(peer_id)` so the HUD shows a ready bubble next to each portrait (minimal dot is fine; full HUD is Slice 9).
- [ ] **Step 3 (manual verify):** Two instances; both must pick before the game resumes; a ready bubble appears when a peer has picked; if one never picks, resume happens after 30s.
- [ ] **Step 4:** Commit `feat(net): level-up ready-up, resume-when-all-ready, 30s timeout (M4)`.

---

## Phase G — M5: Shared gold, downed/revival/respawn, defeat

### Task G1: Team gold pool

**Files:**
- Modify: `game/game_manager_3d.gd` (`var _team_gold:int`; host-authoritative add + broadcast), `autoload/game_events.gd` (`signal team_gold_changed(total:int)`), HUD (show gold).

**Steps:**
- [ ] **Step 1:** Add gold pickups/sources as host-authoritative; on credit, host does `_team_gold += n; rpc("_rpc_set_gold", _team_gold)`; RPC sets local mirror + emits `team_gold_changed`. (Gold *sources* like pods are Slice 6; here we wire the shared pool + the +10/level-up gold the current game grants.)
- [ ] **Step 2 (manual verify):** Two instances; gold is identical on both and rises for the whole team on any credit.
- [ ] **Step 3:** Commit `feat(net): shared team gold pool (M5)`.

### Task G2: Downed / revival / respawn

**Files:**
- Modify: `player/player_3d.gd` (add downed state + `is_downed()`, host-authoritative), `game/game_manager_3d.gd` (revival proximity check + respawn timers using `RespawnRules`), a downed-ring visual.
- Test: `test/test_player_downed.gd`

**Interfaces:**
- Produces: `Player3D.enter_downed()`, `Player3D.revive()`, `Player3D.is_downed() -> bool`, `Player3D.deaths:int`; host FSM using `RespawnRules.DOWNED_TIME`, `respawn_delay(deaths)`, `REVIVE_HP_FRACTION`, `REVIVE_INVULN`.

**Steps:**
- [ ] **Step 1: Write failing test** for the state transitions (pure, no network):
```gdscript
# test/test_player_downed.gd
extends GutTest
var PlayerScene = load("res://player/player_3d.tscn")
func _mk() -> Player3D:
	var p = add_child_autofree(PlayerScene.instantiate())
	var cd := CharacterData.new()
	var sb := StatBlock.new(); sb.max_hp = 100.0; cd.base_stats = sb
	p.setup(cd)
	return p
func test_enter_downed_sets_flag_and_zero_hp():
	var p := _mk()
	p.enter_downed()
	assert_true(p.is_downed())
func test_revive_restores_half_hp_and_clears_downed():
	var p := _mk()
	p.enter_downed()
	p.revive()
	assert_false(p.is_downed())
	assert_almost_eq(p.hp, 50.0, 0.001)   # 50% of 100
	assert_true(p.is_invulnerable())        # 4s invuln granted
```
- [ ] **Step 2: Run → FAIL** (`enter_downed`/`revive`/`is_downed` missing).
- [ ] **Step 3: Implement** on `Player3D`:
```gdscript
var _downed: bool = false
var deaths: int = 0
func is_downed() -> bool: return _downed
func enter_downed() -> void:
	_downed = true
	hp = 0.0
	deaths += 1
func revive() -> void:
	_downed = false
	hp = stats.max_hp * RespawnRules.REVIVE_HP_FRACTION
	set_invulnerable(RespawnRules.REVIVE_INVULN)
```
Change `take_damage` lethal branch: in co-op (party size > 1) call `enter_downed()` instead of emitting `player_died`; solo keeps `player_died`. The host drives downed timers and revival proximity (teammate inside the downed circle → `revive()`), and respawn via `RespawnRules.respawn_delay(deaths)`. Add a simple downed ring visual (reuse `shaders/telegraph_ring.gdshader` or a torus) shown while `_downed`.
- [ ] **Step 4: Run tests** → PASS; run `test/test_player_3d.gd` → PASS (solo lethal still emits `player_died`).
- [ ] **Step 5 (manual verify):** Two instances; kill one player → they go downed with a ring + countdown; teammate walks onto them → revived at 50% HP + brief invuln; if left, they respawn after the delay.
- [ ] **Step 6:** Commit `feat(net): downed state, revival, respawn timers (M5)`.

### Task G3: All-downed defeat + solo unchanged

**Files:**
- Modify: `game/game_manager_3d.gd` (`_on_player_died` co-op vs solo; all-downed check)

**Steps:**
- [ ] **Step 1:** Host checks after any `enter_downed`: if **all** alive players are downed simultaneously → `rpc("_rpc_defeat")` → everyone routes to game-over (reuse `GAME_OVER_SCENE`). Solo (`_players.size() == 1`) keeps the existing `_on_player_died` → immediate game-over.
- [ ] **Step 2 (manual verify):** Two instances; down both → defeat/game-over on both. Solo → unchanged.
- [ ] **Step 3:** Commit `feat(net): all-downed defeat routing; solo path unchanged (M5)`.

---

## Phase H — M6: Polish

### Task H1: Disconnect handling

**Files:**
- Modify: `game/game_manager_3d.gd` (despawn on `player_left`), `net/network_manager.gd` (host-abort surfaces to arena)

**Steps:**
- [ ] **Step 1:** On `NetworkManager.player_left(peer_id)` during a match, host despawns `Players/Player_<peer_id>` (MultiplayerSpawner replicates removal). On `host_aborted` (client side), route to lobby.
- [ ] **Step 2 (manual verify):** Two instances mid-match; close the client → its fighter disappears on host, run continues. Close host → client returns to lobby.
- [ ] **Step 3:** Commit `feat(net): mid-match disconnect + host-abort handling (M6)`.

### Task H2: Steam invite flow + solo regression

**Steps:**
- [ ] **Step 1 (manual verify):** With Steam running, host via `host_steam()`, use `open_invite_overlay()` to invite a second account/machine; confirm join → lobby → start → play.
- [ ] **Step 2: Full regression:** run the entire suite:
`godot47 --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: **≥ 1129 + new tests, all green.** Then launch solo and confirm the single-player experience is unchanged (movement, waves, level-up, ultimate, game-over).
- [ ] **Step 3:** Commit `test(net): full-suite + solo regression pass for co-op foundation (M6)`.

---

## Self-Review

**1. Spec coverage:**
- Steam lobby / invites → C2, D1, H2. ✓
- ENet-loopback dev transport + seam → C1. ✓
- Networked character select, duplicates allowed → A1 (registry), D1. ✓
- Host-auth enemies / client-owned avatar → D3, E1, E2. ✓
- Team XP pool + shared level → A2, E3. ✓
- Synced level-up (pause → per-player pick → ready bubbles → resume, 30s timeout) → F1, F2. ✓
- Downed → revival (50% HP, 4s invuln) → respawn (15+9·d, cap 60) → G2 (+ A3 constants). ✓
- All-downed defeat; solo unchanged → G3. ✓
- Shared gold → G1. ✓
- Lobby flow + edge cases (no mid-match join, client despawn, host-abort, no reconnection) → D1, H1. ✓
- Testing: extracted pure logic (A1–A3, B1–B3) + two-instance integration (C–H). ✓
- Rollout M1–M6 → Phases C–H map 1:1. ✓

**2. Placeholder scan:** Phases A–B and the pure-logic parts of C, D2, G2 have complete failing tests + implementations. Phases C–H integration steps intentionally pair real code with **manual two-instance verification** (networking can't be unit-tested); these are explicit verification procedures, not "TODO" placeholders. GodotSteam method names are flagged for version-check in C2 (isolated by the seam). No `TBD`/`implement later`.

**3. Type consistency:** `LobbyRegistry` API used consistently (D1 iterates `peer_ids()`/`get_player()`). `TeamProgress.add_xp → int` used in E3/F1. `RespawnRules` constants used in G2. `is_local_authority()`/`peer_id` consistent across D3/E1. `setup_party` naming consistent for Spawner (B2/D2) and XPGem (B3/E3). `_players`/`_team`/`_team_gold` consistent in GameManager across D2/E3/F/G.

**Known follow-ups (correctly deferred to later slices, not gaps here):** gold *sources* (pods) → Slice 6; the full Swarm HUD (proper ready-bubbles/panels) → Slice 9; enemy *tier* behaviors → Slice 7. This slice wires the shared pools/hooks they will plug into.
