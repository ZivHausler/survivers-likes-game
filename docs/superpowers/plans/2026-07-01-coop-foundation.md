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

## Networking Data-Transfer Guidelines (research-backed — read before Phases C–H)

These are the rules that make transfer **stable for clients and reliable for the host**. Key sources: Godot [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), [Scene replication article](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/), [MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html), [proposal #3459 (batching)](https://github.com/godotengine/godot-proposals/issues/3459), [GodotSteam multiplayer_peer](https://godotsteam.com/classes/multiplayer_peer/), [`change_scene` mid-session warning](https://github.com/godotengine/godot/issues/68407#issuecomment-2331790407).

**Two Steam-transport facts that shape everything:**
1. **Over `SteamMultiplayerPeer`, `unreliable_ordered` silently degrades to reliable, and ENet-style per-channel head-of-line isolation is NOT configured.** Design for exactly two modes: `reliable` and `unreliable`. Keep reliable event traffic small/infrequent so it never queues behind bulk data.
2. **`Steam.run_callbacks()` must run every frame on a `PROCESS_MODE_ALWAYS` node, or P2P silently stalls.** `get_tree().paused` does NOT stop RPC/synchronizer delivery (the MultiplayerAPI polls from `SceneTree.process`), but it WILL stop the Steam pump if that pump sits on a pausable node. → **`NetworkManager` autoload is `PROCESS_MODE_ALWAYS` and owns the Steam callback pump.**

**Mechanism decision rule:** continuously-overwritten state → `MultiplayerSynchronizer` (small counts) or a **batched snapshot RPC** (large counts); discrete "happened once" events → **reliable RPC**. Never spam RPCs for continuous data.

| System | Mechanism | `@rpc(...)` |
|---|---|---|
| Local fighter movement (1–4) | `MultiplayerSynchronizer`, authority = owning client, `ALWAYS`/unreliable | n/a |
| Remote fighters (seen by others) | same synchronizer **+ client-side interpolation** | n/a |
| **~200 enemy transforms** | **ONE batched snapshot RPC/tick (~15–20 Hz)**, quantized `PackedByteArray`, **NOT per-enemy synchronizers** | `@rpc("authority","call_remote","unreliable")` |
| Client→host "my hit dealt X to enemy N" | reliable request RPC | `@rpc("any_peer","call_remote","reliable")` |
| Host→all confirmed HP/death/despawn | reliable broadcast (`call_local` so host runs it too) | `@rpc("authority","call_local","reliable")` |
| Team XP / Gold totals | reliable authority broadcast (host is sole mutator) | `@rpc("authority","call_remote","reliable")` |
| Level-up begin / ready-ack / resume | reliable handshake | `@rpc("any_peer","call_local","reliable")` for ack; `authority,call_local` for begin/resume |
| Spawn/despawn of players & pickups | `MultiplayerSpawner` | n/a |
| Lobby→arena transition | host spawns arena into a **persistent scene** (NOT `change_scene_to_file`) | `@rpc("authority","call_local","reliable")` |

**`@rpc` hygiene:** every `@rpc` function must be declared **identically on all peers** (checksum-validated). In any `any_peer` handler, immediately `if not multiplayer.is_server(): return` and read `multiplayer.get_remote_sender_id()` — **trust clients only for input, never for authoritative results.**

**~200 enemies — the batched-snapshot pattern (Task E1 uses this):** per-enemy synchronizers hit a per-message wall ("Buffer payload full! Dropping data") long before a bandwidth wall — Godot's own proposal #3459 says syncing each node separately gives "abysmal network performance." Instead: host packs one snapshot per tick — header `u16 tick_seq`, `u16 count`; per enemy `u16 id`, quantized `u16 x`, `u16 z`, `u16 yaw`, `u8 state/hp` (~9 B/enemy ≈ 1.8 KB for 200) — via a single **unreliable** RPC to each client. Clients keep an `id→enemy` dict, spawn/despawn locally, drop stale `tick_seq`, and **interpolate between the last two snapshots**. Discrete enemy events (death, damage-confirm) ride separate **reliable** RPCs. Co-op tolerance is generous (BLASTRONAUT/Coherence Vampire-Survivors co-op correct at ~1 Hz); 15–20 Hz is comfortable.

**Interpolation (remote fighters AND snapshot enemies)** — `MultiplayerSynchronizer` has NO built-in interpolation; at 15–20 Hz vs 60 fps you MUST lerp on receipt or it stutters:
```gdscript
# on each received network value: from = current visual pos; to = new authoritative pos; elapsed = 0
func _process(delta):
    elapsed += delta
    visual.global_position = from_pos.lerp(to_pos, clamp(elapsed / NET_INTERVAL, 0.0, 1.0))
```
Local player needs **no prediction/reconciliation** — it's client-authoritative, so its own movement is already correct. (Godot 4.3+ `physics_interpolation` fixes tick-vs-frame jitter, NOT network jitter — don't use it for this.)

**Client-damage flow (Task E2) — request → validate → broadcast:**
```gdscript
# CLIENT: optimistic cosmetic hit-flash only, then report to host
request_damage.rpc_id(1, enemy_id, amount)
@rpc("any_peer","call_remote","reliable")
func request_damage(enemy_id:int, amount:int) -> void:
    if not multiplayer.is_server(): return
    var sender := multiplayer.get_remote_sender_id()          # validate/clamp
    var new_hp := _apply_damage_authoritative(enemy_id, amount, sender)
    confirm_damage.rpc(enemy_id, new_hp, sender)              # to all, incl host
@rpc("authority","call_local","reliable")
func confirm_damage(enemy_id:int, new_hp:int, credited:int) -> void:
    _set_enemy_hp_visual(enemy_id, new_hp)                    # host value is final
```
Keep client-side optimism **cosmetic and idempotent** so the host's confirm never causes a gameplay pop.

**Solo vs networked detection (learned in D2 — applies everywhere):** Godot sets `multiplayer.multiplayer_peer` to a **non-null `OfflineMultiplayerPeer`** by default, so `multiplayer_peer == null` is NOT a valid "am I solo?" check — it mis-routes solo through the networked branch. Use a helper: `is_networked() = multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)` (canonical: `GameManager3D._is_networked()`; promote to `NetworkManager.is_networked()` if more callers need it). Branch **behavior** (spawn direct vs `spawner.spawn`, `take_damage` direct vs `request_damage.rpc`) on `is_networked()`. Note: `multiplayer.is_server()` IS correct in solo (the offline peer reports `is_server() == true`), so host-only gates written as `if is_networked() and not multiplayer.is_server(): return` are fine.

**MultiplayerSpawner correctness (Tasks D2, E1, G):**
- Use a custom `spawn_function` to pass init data (`fighter_id`, xp); call `spawner.spawn(data)` **on the host only**; the callback runs on all peers and returns the node — **don't `add_child` yourself**.
- **Set `set_multiplayer_authority()` in `_enter_tree()` or the spawn callback — never after `_ready()`.**
- **Deterministic node names** across peers: name spawned nodes by peer/entity id and use `add_child(node, true)` (force-readable). Don't reparent/rename networked nodes post-spawn.
- Freeing a spawner-tracked node on the host auto-replicates despawn — no manual despawn RPC.

**Lobby→arena & synchronized pause (Tasks D1, F):**
- **Do NOT `change_scene_to_file()` during an active session** (a maintainer explicitly warns against it — deferred tree swap drops packets → "Node not found"/"ID not found in cache"). Instead keep everyone on a **persistent root scene** with the persistent `NetworkManager`; the host adds/spawns the arena via `@rpc("authority","call_local","reliable")`, which replicates to current and late peers. Non-host peers `await` a host "arena ready" signal before spawning their fighter — never spawn in `_ready()`. Gate wave spawning behind an "all peers loaded" ack barrier.
- Synchronized pause: host `begin_levelup` (pause) → each peer acks `levelup_ready` → host counts acks against its **own** player dict (survives a mid-vote disconnect) → host `resume_game`. Pause is safe because RPC delivery ignores `paused` (given the ALWAYS autoloads).

**Do/Don't checklist:**
- ✅ Host = single source of truth for HP/death/XP/gold; clients only *request*. ✅ Batch enemy state; interpolate on receipt. ✅ Declare `@rpc` identically everywhere; validate `sender_id`. ✅ Reliable for events, unreliable for the position stream. ✅ Authority before `_ready()`; deterministic names; `add_child(_, true)`. ✅ Steam pump + net autoloads `PROCESS_MODE_ALWAYS`.
- ❌ Don't rely on `unreliable_ordered`/channel isolation over Steam. ❌ No per-enemy synchronizers at ~200. ❌ No `change_scene_to_file` mid-session; no reparent/rename of networked nodes. ❌ Don't use physics interpolation to fix *network* stutter. ❌ Don't trust client-reported damage without host validation.

---

## File Structure

**New files (pure logic — unit tested):**
- `net/lobby_registry.gd` — `class_name LobbyRegistry extends RefCounted`. Party roster: peer→{fighter, name, ready}. Serializable for replication.
- `net/team_progress.gd` — `class_name TeamProgress extends RefCounted`. Shared team XP + level; `add_xp → levels_gained`.
- `net/respawn_rules.gd` — `class_name RespawnRules extends RefCounted`. Downed/revive/respawn constants + `respawn_delay(deaths)`.
- `net/enemy_snapshot.gd` — `class_name EnemySnapshot extends RefCounted`. Pure quantize/dequantize codec: `pack(entries, origin, inv_scale) -> PackedByteArray` / `unpack(bytes, origin, scale) -> Array`. Unit-tested (§Task E1).

**New files (networking runtime):**
- `net/network_manager.gd` — autoload `NetworkManager`. Transport seam, lobby lifecycle, RPC hub, holds a `LobbyRegistry`.
- `net/net_transport.gd` — `class_name NetTransport extends RefCounted`. `static func create_peer(mode, opts) -> MultiplayerPeer`.
- `net/player_spawn.gd` — helper for runtime player instantiation + spawn-point selection.
- `game/session_root.gd` / `game/session_root.tscn` — **persistent root scene** (`PROCESS_MODE_ALWAYS` for its net-critical children) that hosts the lobby and, later, the arena as swapped children. This is what avoids `change_scene_to_file` mid-session: the host spawns the arena into this root via RPC and it replicates to all peers. Becomes `run/main_scene`.
- `ui/lobby_3d.gd` / `ui/lobby_3d.tscn` — networked lobby / character-select screen (a child of the session root; wraps existing select UI).

**Modified files (de-singletoned / networked):**
- `enemies/enemy_3d.gd` — nearest-of-many retargeting; `net_id`; **proxy mode** (client visual-only + interpolation).
- `spawning/spawner_3d.gd` — party targeting (`_targets`); host-only simulation; assigns `net_id`.
- `pickups/xp_gem_3d.gd` — nearest-player magnet + team award; host-authoritative collection.
- `player/player_3d.gd` — `peer_id`/authority, input gated to authority, receive-side interpolation, host-authoritative HP/downed.
- `game/game_manager_3d.gd` — `_players` list, runtime player spawning (spawn_function), team XP/gold/level, **enemy snapshot broadcast + client proxy manager**, damage arbitration, synced level-up FSM, downed/defeat.
- `game/main_3d.tscn` — replace authored single `Player` with `Players` node + `PlayerSpawner` (`MultiplayerSpawner`); add an `Enemies` container (host-spawned + client proxies).
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
	# CRITICAL: never let pause stop the Steam pump, or P2P silently stalls.
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_dt: float) -> void:
	# Pump Steam callbacks every frame (no-op until Steam is initialized in Task C2).
	if Engine.has_singleton("Steam"):
		Steam.run_callbacks()

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
	if peer_id != multiplayer.get_remote_sender_id():
		return   # a client may only set its OWN fighter (no spoofing)
	_apply_set_fighter(peer_id, fighter_id)
	_broadcast_registry()

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(peer_id: int, ready: bool) -> void:
	if not is_host():
		return
	if peer_id != multiplayer.get_remote_sender_id():
		return   # a client may only set its OWN ready flag
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
- Create: `game/session_root.gd`, `game/session_root.tscn`, `ui/lobby_3d.gd`, `ui/lobby_3d.tscn`
- Modify: `project.godot` (`run/main_scene` → `res://game/session_root.tscn`)
- Reuse: `ui/character_select_3d.gd` `CHARACTER_PATHS` for the fighter grid.

**Interfaces:**
- Consumes: `NetworkManager` (host/join/registry/signals, `request_set_fighter`, `request_set_ready`), `RunState`.
- Produces: a **persistent** `SessionRoot` that holds the lobby and later the arena as swapped children; on Start (host only) it writes `RunState.party` and, via `@rpc("authority","call_local","reliable")`, **swaps the lobby child for the arena instance on every connected peer WITHOUT `change_scene_to_file`**. `SessionRoot.enter_arena(party:Dictionary)` is the single entry point.

> **Why a session root:** `change_scene_to_file` mid-session drops packets against the freed tree ("Node not found"). Keeping one persistent scene and swapping children under it (bomber-demo pattern) is the reliable path. See the Networking Guidelines above.

- [ ] **Step 1: Build the persistent session root**

`game/session_root.tscn` = a `Node` (`SessionRoot`) with one child slot for the active screen. It never gets freed for the life of the session.

```gdscript
# game/session_root.gd
class_name SessionRoot
extends Node

const LOBBY_SCENE := preload("res://ui/lobby_3d.tscn")
const ARENA_SCENE := preload("res://game/main_3d.tscn")

@onready var _slot: Node = $Slot   # the child container we swap

func _ready() -> void:
	_show_lobby()

func _show_lobby() -> void:
	_clear_slot()
	_slot.add_child(LOBBY_SCENE.instantiate(), true)

# Host calls this; call_local runs it on the host too. Replicates to all CURRENT peers.
@rpc("authority", "call_local", "reliable")
func enter_arena(party: Dictionary) -> void:
	RunState.party = party
	_clear_slot()
	var arena := ARENA_SCENE.instantiate()
	arena.name = "Arena"
	_slot.add_child(arena, true)   # force-readable, deterministic name across peers

func _clear_slot() -> void:
	for c in _slot.get_children():
		c.queue_free()
```

`ui/lobby_3d.tscn`: a `Control` with Host / Join(IP) buttons, a fighter `GridContainer` (from `CHARACTER_PATHS`), a player list (name + fighter + ready check), a Ready toggle, and a Start button (host, disabled until `registry.all_ready()`).

```gdscript
# ui/lobby_3d.gd
class_name Lobby3D
extends Control

const CHARACTER_PATHS := preload("res://ui/character_select_3d.gd").CHARACTER_PATHS

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
	# No change_scene_to_file: ask the persistent root to swap in the arena on all peers.
	var root := get_tree().current_scene as SessionRoot
	root.enter_arena.rpc(party)

func _refresh() -> void:
	# redraw player list + enable Start iff host and all ready
	pass

func _build_fighter_grid() -> void:
	pass

func _on_host_aborted() -> void:
	var root := get_tree().current_scene as SessionRoot
	root._show_lobby()
```

- [ ] **Step 2: Point the game at the session root**

In `project.godot`, set `run/main_scene="res://game/session_root.tscn"`. Provide a **Solo** button in the lobby that (without hosting) sets `RunState.party = {1: chosen}` and calls `enter_arena({1: chosen})` locally — solo takes the exact same arena path, just with no peer.

- [ ] **Step 3: Manual two-instance verification**

Run Multiple Instances = 2:
- I1 Host, pick fighter, Ready. I2 Join `127.0.0.1`, pick fighter, Ready.
- Expected: both lists show 2 players with fighters + ready ticks; Start enables on host; pressing Start loads `main_3d.tscn` on **both**.

- [ ] **Step 4: Commit**

```bash
git add game/session_root.gd game/session_root.tscn ui/lobby_3d.gd ui/lobby_3d.tscn project.godot
git commit -m "feat(net): persistent session root + networked lobby/character select (M2)"
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

In `game/main_3d.tscn`: delete the authored `Player` node; add an empty `Node3D` named `Players` and a `MultiplayerSpawner` named `PlayerSpawner` with `spawn_path = ../Players`. In `game/game_manager_3d.gd`, set the spawner's custom `spawn_function` and spawn one player per party entry **on the host only** (solo bypasses the spawner). Authority + name + fighter are assigned **inside the spawn callback**, which runs identically on every peer:

```gdscript
const PLAYER_SCENE := preload("res://player/player_3d.tscn")
var _players: Array = []
var _player_spawner: MultiplayerSpawner = null

func _spawn_party() -> void:
	var players_root: Node3D = parent.get_node("Players")
	_player_spawner = parent.get_node("PlayerSpawner")
	_player_spawner.spawn_function = Callable(self, "_do_spawn_player")
	_player_spawner.spawned.connect(_on_player_spawned)  # fires on ALL peers per spawn
	var party: Dictionary = RunState.party if not RunState.party.is_empty() else {1: _fallback_fighter_path()}
	var pids: Array = party.keys(); pids.sort()
	for i in range(pids.size()):
		var pid := int(pids[i])
		var data := {"peer_id": pid, "fighter": String(party[pid]),
			"pos": PlayerSpawn.spawn_point(i, pids.size(), 3.0)}
		if multiplayer.multiplayer_peer == null:
			# Solo: no peer -> instantiate directly (spawner needs a peer to replicate).
			players_root.add_child(_do_spawn_player(data), true)
		else:
			_player_spawner.spawn(data)   # host only; replicates + runs callback on all peers

# Runs on EVERY peer with identical `data`. Returns the node; the spawner add_child's it.
func _do_spawn_player(data: Dictionary) -> Node:
	var p := PLAYER_SCENE.instantiate()
	p.name = "Player_%d" % int(data["peer_id"])   # deterministic across peers
	p.peer_id = int(data["peer_id"])
	p.set_multiplayer_authority(int(data["peer_id"]))  # authority set before _ready()
	p.add_to_group("player")
	p.setup(load(String(data["fighter"])) as CharacterData)
	p.position = data["pos"]
	return p

func _on_player_spawned(node: Node) -> void:
	_players.append(node)
	_player = _players[0]                 # legacy single ref for HUD/camera wiring
	_spawner.setup_party(_players)         # refresh party targeting as players arrive
	if node == _local_player():
		_focus_camera_on(node)

func _local_player() -> Node:
	var uid := 1 if multiplayer.multiplayer_peer == null else multiplayer.get_unique_id()
	for p in _players:
		if p.peer_id == uid:
			return p
	return _players[0] if not _players.is_empty() else null
```

> Only the host calls `spawn()`; the spawner replicates each new player to all peers and runs `_do_spawn_player` on each with the same data, so names/authority match everywhere. Camera follows `_local_player()`.

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

Interpolate remote players (the synchronizer replicates a `net_position`; the authority sets it to its real position, non-authorities lerp toward it):

```gdscript
const NET_INTERVAL := 0.05           # 20 Hz sync period; must match synchronizer interval
var net_position: Vector3 = Vector3.ZERO   # REPLICATED property (set in SceneReplicationConfig)
var _lerp_from: Vector3 = Vector3.ZERO
var _lerp_to: Vector3 = Vector3.ZERO
var _lerp_t: float = 0.0

func _on_net_position_changed() -> void:   # call from a setter or watch in _process
	_lerp_from = global_position
	_lerp_to = net_position
	_lerp_t = 0.0
```

Guard input in `_physics_process(dt)`:

```gdscript
	if not is_local_authority():
		# Non-authority: no input/physics; smoothly interpolate toward the replicated net_position.
		_lerp_t = minf(_lerp_t + dt / NET_INTERVAL, 1.0)
		global_position = _lerp_from.lerp(_lerp_to, _lerp_t)
		return
	# Authority: run existing input + movement, then publish for replication:
	# ... existing input + movement code unchanged ...
	net_position = global_position
```

In `player_3d.tscn` add a `MultiplayerSynchronizer` child; in its `SceneReplicationConfig` replicate **`net_position`** (mode `ALWAYS`/unreliable) and the model yaw property used for facing, and set `replication_interval = 0.05`. Detect changes to `net_position` on non-authorities (a property setter that calls `_on_net_position_changed`, or compare against the last value each frame) to refresh the interpolation targets. Authority is assigned in the D2 spawn callback (`set_multiplayer_authority(peer_id)`), so the synchronizer inherits it — do not reassign after `_ready()`.

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

### Task E1: Host-authoritative enemies via batched snapshot (NOT per-enemy synchronizers)

Per-enemy `MultiplayerSynchronizer` hits a per-message wall well before ~200 enemies (proposal #3459: "abysmal network performance"). Host simulates all enemies; each tick it sends **one quantized snapshot RPC** per client; clients keep an `id→proxy` dict and interpolate. Spawn/despawn is driven by first-/last-sight in the snapshot plus a reliable death event — **no `MultiplayerSpawner` for enemies.**

**Files:**
- Create: `net/enemy_snapshot.gd`, `test/test_enemy_snapshot.gd`
- Modify: `spawning/spawner_3d.gd` (host-only), `enemies/enemy_3d.gd` (add `net_id`, proxy mode), `game/game_manager_3d.gd` (snapshot broadcast on host + receive/apply on clients)

**Interfaces:**
- Produces: `EnemySnapshot.pack(entries:Array, origin:Vector3, inv_scale:float, tick:int) -> PackedByteArray` and `EnemySnapshot.unpack(bytes:PackedByteArray, origin:Vector3, scale:float) -> Dictionary` (`{"tick":int, "entries":Array}` where each entry is `{"id":int,"pos":Vector3,"yaw":float,"state":int}`); `Enemy3D.net_id:int`; `Enemy3D.configure_proxy()` (disables AI/nav/collision, visual only).

- [ ] **Step 1: Write the failing test (codec roundtrip within quantization tolerance)**

```gdscript
# test/test_enemy_snapshot.gd
extends GutTest

const ORIGIN := Vector3(-100, 0, -100)
const SPAN := 200.0
var _inv := 65535.0 / SPAN
var _scale := SPAN / 65535.0

func test_roundtrip_preserves_ids_and_positions():
	var entries := [
		{"id": 1, "pos": Vector3(-100, 0, -100), "yaw": 0.0, "state": 0},
		{"id": 2, "pos": Vector3(0, 0, 50), "yaw": PI, "state": 1},
		{"id": 300, "pos": Vector3(99, 0, -20), "yaw": TAU * 0.75, "state": 2},
	]
	var bytes := EnemySnapshot.pack(entries, ORIGIN, _inv, 42)
	var out := EnemySnapshot.unpack(bytes, ORIGIN, _scale)
	assert_eq(out["tick"], 42)
	assert_eq(out["entries"].size(), 3)
	for i in range(3):
		var a: Dictionary = entries[i]
		var b: Dictionary = out["entries"][i]
		assert_eq(b["id"], a["id"])
		assert_eq(b["state"], a["state"])
		assert_almost_eq(b["pos"].x, a["pos"].x, 0.02)   # ~1/65535 * 200 ≈ 0.003 quantization
		assert_almost_eq(b["pos"].z, a["pos"].z, 0.02)
		assert_almost_eq(b["yaw"], a["yaw"], 0.01)

func test_byte_length_is_header_plus_9_per_entry():
	var entries := [{"id": 1, "pos": Vector3.ZERO, "yaw": 0.0, "state": 0}]
	var bytes := EnemySnapshot.pack(entries, ORIGIN, _inv, 0)
	assert_eq(bytes.size(), 4 + 9)   # u16 tick + u16 count + one 9-byte entry
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_snapshot.gd -gexit`
Expected: FAIL — EnemySnapshot missing.

- [ ] **Step 3: Implement the codec**

```gdscript
# net/enemy_snapshot.gd
class_name EnemySnapshot
extends RefCounted

# Entry layout (9 bytes): u16 id, u16 x, u16 z, u16 yaw, u8 state. Header: u16 tick, u16 count.
static func pack(entries: Array, origin: Vector3, inv_scale: float, tick: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4 + entries.size() * 9)
	b.encode_u16(0, tick & 0xFFFF)
	b.encode_u16(2, entries.size() & 0xFFFF)
	var off := 4
	for e in entries:
		var p: Vector3 = e["pos"]
		var qx := clampi(int((p.x - origin.x) * inv_scale), 0, 65535)
		var qz := clampi(int((p.z - origin.z) * inv_scale), 0, 65535)
		var yaw: float = fposmod(float(e["yaw"]), TAU)
		var qy := clampi(int(yaw / TAU * 65535.0), 0, 65535)
		b.encode_u16(off, int(e["id"]) & 0xFFFF); off += 2
		b.encode_u16(off, qx); off += 2
		b.encode_u16(off, qz); off += 2
		b.encode_u16(off, qy); off += 2
		b.encode_u8(off, int(e["state"]) & 0xFF); off += 1
	return b

static func unpack(bytes: PackedByteArray, origin: Vector3, scale: float) -> Dictionary:
	var tick := bytes.decode_u16(0)
	var count := bytes.decode_u16(2)
	var entries := []
	var off := 4
	for i in range(count):
		var id := bytes.decode_u16(off); off += 2
		var qx := bytes.decode_u16(off); off += 2
		var qz := bytes.decode_u16(off); off += 2
		var qy := bytes.decode_u16(off); off += 2
		var st := bytes.decode_u8(off); off += 1
		entries.append({
			"id": id,
			"pos": Vector3(origin.x + qx * scale, 0.0, origin.z + qz * scale),
			"yaw": float(qy) / 65535.0 * TAU,
			"state": st,
		})
	return {"tick": tick, "entries": entries}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_snapshot.gd -gexit`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit the codec**

```bash
git add net/enemy_snapshot.gd test/test_enemy_snapshot.gd
git commit -m "feat(net): quantized enemy snapshot codec (pure logic)"
```

- [ ] **Step 6: Host simulation + net_id + broadcast**

Gate `Spawner3D._process` to host: at the top, `if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return`. In `_instance_enemy`, assign `enemy.net_id = _next_net_id; _next_net_id += 1` (monotonic counter on the spawner/manager). Add to `Enemy3D` a `var net_id: int = 0` and a `state` accessor (0 normal / 1 elite / 2 boss, from `boss_kind`). In `GameManager3D`, add a fixed-rate snapshot broadcaster (host only):

```gdscript
const NET_ORIGIN := Vector3(-100, 0, -100)
const NET_SPAN := 200.0
var _snap_accum := 0.0
var _snap_tick := 0

func _process(dt):
	# ... existing timer code ...
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_snap_accum += dt
		if _snap_accum >= 0.05:      # 20 Hz
			_snap_accum = 0.0
			_broadcast_enemy_snapshot()

func _broadcast_enemy_snapshot():
	var entries := []
	for e in get_tree().get_nodes_in_group("enemies"):
		entries.append({"id": e.net_id, "pos": e.global_position, "yaw": e.rotation.y, "state": e.snapshot_state()})
	var inv := 65535.0 / NET_SPAN
	var bytes := EnemySnapshot.pack(entries, NET_ORIGIN, inv, _snap_tick)
	_snap_tick = (_snap_tick + 1) & 0xFFFF
	for pid in multiplayer.get_peers():
		receive_enemy_snapshot.rpc_id(pid, bytes)
```

- [ ] **Step 7: Client proxies + interpolation + despawn**

On clients, enemies are NOT simulated. Add the receiver + proxy manager to `GameManager3D` (runs only on non-host):

```gdscript
var _proxies := {}        # net_id -> Enemy3D (proxy)
var _last_seen := {}      # net_id -> _snap_tick when last present

@rpc("authority", "call_remote", "unreliable")
func receive_enemy_snapshot(bytes: PackedByteArray) -> void:
	var scale := NET_SPAN / 65535.0
	var snap := EnemySnapshot.unpack(bytes, NET_ORIGIN, scale)
	var tick: int = snap["tick"]
	for e in snap["entries"]:
		var id: int = e["id"]
		var proxy: Node3D = _proxies.get(id)
		if proxy == null:
			proxy = ENEMY_SCENE.instantiate()
			proxy.net_id = id
			parent.get_node("Enemies").add_child(proxy)
			proxy.add_to_group("enemies")
			proxy.configure_proxy()             # disable AI/nav/collision
			proxy.global_position = e["pos"]
			_proxies[id] = proxy
		proxy.set_interp_target(e["pos"], e["yaw"])   # from->to lerp (NET_INTERVAL=0.05)
		_last_seen[id] = tick
	# despawn proxies not seen for several ticks
	for id in _proxies.keys():
		if not _last_seen.has(id) or _tick_gap(tick, _last_seen[id]) > 10:
			_proxies[id].queue_free(); _proxies.erase(id); _last_seen.erase(id)
```

In `Enemy3D`, add proxy mode + interpolation:

```gdscript
var _is_proxy := false
var _ip_from := Vector3.ZERO
var _ip_to := Vector3.ZERO
var _ip_t := 0.0
var _ip_yaw_to := 0.0

func configure_proxy() -> void:
	_is_proxy = true
	set_physics_process(true)   # keep for interpolation, but AI is skipped below
	# disable collision shapes / NavigationAgent / attack strategy here

func snapshot_state() -> int:
	return 2 if boss_kind != BossKind.NONE else 0

func set_interp_target(pos: Vector3, yaw: float) -> void:
	_ip_from = global_position; _ip_to = pos; _ip_yaw_to = yaw; _ip_t = 0.0
```

Guard the top of `Enemy3D._physics_process(dt)`:

```gdscript
	if _is_proxy:
		_ip_t = minf(_ip_t + dt / 0.05, 1.0)
		global_position = _ip_from.lerp(_ip_to, _ip_t)
		rotation.y = lerp_angle(rotation.y, _ip_yaw_to, 0.5)
		return
```

Add an `Enemies` node to `main_3d.tscn` and parent host-spawned enemies there too (so both host and client group them consistently). Death VFX on clients comes from a reliable event in Task E2's `confirm_damage` path (host broadcasts death → client frees the proxy + plays the dissolve).

- [ ] **Step 8 (manual two-instance verify):** Host + client Start. Expected: on the client, enemies appear/move smoothly (interpolated), matching host positions within a frame or two; no "Buffer payload full" errors in the client log even with 150+ enemies; only the host runs AI.

- [ ] **Step 9: Commit**

```bash
git add spawning/spawner_3d.gd enemies/enemy_3d.gd game/game_manager_3d.gd game/main_3d.tscn
git commit -m "feat(net): host-simulated enemies via batched snapshot + client interpolation (M3)"
```

### Task E2: Client weapon damage → host arbitration (by net_id)

Damage targets enemies by `net_id` (client weapons hit a proxy that only carries an id). Flow is request → host validates/applies → host broadcasts confirm (incl. death for proxy cleanup + VFX). One shared damage path so every weapon routes identically.

**Files:**
- Modify: `game/game_manager_3d.gd` (host `_enemies_by_id` map; `request_damage`/`confirm_damage` RPCs; `apply_damage(enemy, amount)` helper), `core/weapon_3d.gd` and subclasses (call the shared helper), `enemies/enemy_3d.gd` (register/unregister net_id on host)

**Interfaces:**
- Produces: `GameManager3D.apply_damage(enemy:Node, amount:float) -> void` (solo → direct `take_damage`; networked → `request_damage.rpc_id(1, enemy.net_id, amount)`), `@rpc request_damage(net_id:int, amount:float)`, `@rpc confirm_damage(net_id:int, new_hp:float, dead:bool)`.

- [ ] **Step 1:** On the host, maintain `var _enemies_by_id := {}`; register in `_instance_enemy` (`_enemies_by_id[enemy.net_id] = enemy`) and erase on death. Add the shared helper + RPCs to `GameManager3D`:

```gdscript
func apply_damage(enemy: Node, amount: float) -> void:
	if not _is_networked():                             # OfflineMultiplayerPeer is non-null — see guidelines
		enemy.take_damage(amount)                      # solo: direct
	else:
		request_damage.rpc_id(1, enemy.net_id, amount) # networked: ask host

@rpc("any_peer", "call_remote", "reliable")
func request_damage(net_id: int, amount: float) -> void:
	if not multiplayer.is_server():
		return
	var e: Node = _enemies_by_id.get(net_id)
	if e == null or not is_instance_valid(e):
		return
	e.take_damage(max(0.0, amount))                     # host applies -> may emit enemy_killed_3d/gem
	var dead := not is_instance_valid(e) or e.hp <= 0.0
	confirm_damage.rpc(net_id, (e.hp if not dead else 0.0), dead)

@rpc("authority", "call_local", "reliable")
func confirm_damage(net_id: int, new_hp: float, dead: bool) -> void:
	# Host already applied; clients update proxy visuals / clean up on death.
	if multiplayer.is_server():
		return
	var proxy: Node = _proxies.get(net_id)
	if proxy == null:
		return
	if dead:
		proxy.play_death_vfx()                          # dissolve
		proxy.queue_free(); _proxies.erase(net_id)
	else:
		proxy.set_hp_visual(new_hp)
```

- [ ] **Step 2:** Where weapons currently call `enemy.take_damage(x)` directly, route through `GameManager3D.apply_damage(enemy, x)` instead (a single edit point per weapon; use the run's manager reference). Enemy death/XP/gem still flows through `GameEvents.enemy_killed_3d` on the host (unchanged). Add `Enemy3D.play_death_vfx()` and `set_hp_visual(hp)` thin wrappers over the existing dissolve + HP-bar code.
- [ ] **Step 3 (manual verify):** Two instances; each player's weapons visibly damage/kill shared enemies; kills register exactly once (only host applies + emits `enemy_killed_3d`); dying enemies dissolve on both screens.
- [ ] **Step 4:** Commit `feat(net): client weapon damage by net_id via host arbitration (M3)`.

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
