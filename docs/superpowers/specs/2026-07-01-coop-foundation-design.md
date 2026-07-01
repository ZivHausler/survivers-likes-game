# Co-op Foundation — Design Spec

**Date:** 2026-07-01
**Status:** Approved (design); pending implementation plan
**Slice:** #1 of the "Swarm-like transformation" roadmap (see below)

---

## 1. Context & goal

Friends Swarm is already a fully working 3D bullet-heaven (WASD, auto-fire weapons,
10 friend-characters with 4 skills each, enemy waves + mini/big bosses, XP orbs,
level-up 1-of-3 card picker, passives, synergies/evolutions, ultimates, HUD, arena,
1000+ green GUT tests). We are transforming its **game systems** to match Riot's
*Swarm / Operation: Anima Squad* bullet-heaven, while **keeping our own friends
roster, art, and naming** (IP-safe "Swarm-*like*").

The full transformation is decomposed into 9 sub-projects. **This spec covers only
Slice #1: the Co-op Foundation** — adding 1–4 player co-op to the *current* game
without yet changing combat content or the run's win condition.

### The 9-slice roadmap (context only — not this spec)

| # | Sub-project | Depends on |
|---|---|---|
| **1** | **Co-op Foundation** ← *this spec* | — |
| 2 | Match Loop & Win Condition (15:00 → boss → win/lose, difficulty modes) | 1 |
| 3 | Combat Reorg: Passives / Weapons / Abilities (+ aim toggle C, evolutions) | 2 |
| 4 | Weapon Roster & Evolutions (~20 named weapons) | 3 |
| 5 | Mid-run Objectives: Spires (Boons / Augments / Trials) | 2 |
| 6 | World Objects (Pods, Access Cards, Megastructures, BB01 helper) | 2 |
| 7 | Enemy Tiers & Bosses (Normals/Elites/Mini-bosses/4 map Bosses) | 2 |
| 8 | Meta-progression (Gold shop, Upgrades, Anima Power, unlock chain) | most |
| 9 | Swarm HUD overhaul + 4 Maps | 3,5,6,7 |

---

## 2. Pillars (decided during brainstorming)

1. **Friends theme, faithful systems** — clone Swarm's *mechanics*; keep our roster/art/names.
2. **Full co-op now** — 1–4 players from the start (not solo-first).
3. **Steam P2P** — GodotSteam addon; Steam invites/lobbies/NAT punch-through.
4. **Host-authoritative world, client-owned avatar** — host (listen-server) simulates all
   shared state; each client owns and moves its own fighter.
5. **Team XP & Team Gold** — shared pools; the whole team levels together (a change from
   today's per-player XP, and core to Swarm's feel). Solo play is a team of one.

---

## 3. Scope

### In scope (Slice 1)
- Steam lobby: host/create, invite (overlay/friends list), join, leave; 1–4 players; solo = lobby of one.
- Networked character select (reuses existing `character_select_3d` UI); duplicate fighters allowed.
- Replicated match in the current single arena: host-authoritative enemies/spawns/pickups; client-owned fighter movement.
- **Team XP pool** → whole team levels together; **Team Gold** shared.
- **Synced level-up**: global pause → per-player 1-of-3 offering → ready bubbles → resume when all ready (30s auto-pick timeout).
- **Downed → revival → respawn** (2+ players); all-downed = defeat. Solo keeps today's death→game-over.
- **Transport seam**: swappable Steam / ENet-loopback backends for dev & tests.

### Out of scope (later slices)
15:00 timer / boss-win, difficulty modes, spires/augments/boons, pods, access cards,
megastructures, meta-progression, HUD overhaul, extra maps, host migration, mid-match
join, reconnection. **Combat content (weapons, enemies, level-up card pool) is unchanged
— we add the co-op layer, not new content.**

---

## 4. Network architecture

### 4.1 `NetworkManager` (new autoload singleton)
The single owner of all transport concerns; the rest of the game never touches Steam directly.
- **Steam init** (dev App ID `480` / Spacewar until a real App ID exists).
- **Lobby lifecycle**: create / invite / join / leave.
- **Transport seam**: `create_peer()` returns a `MultiplayerPeer` chosen by a dev flag/env:
  - `steam` → `SteamMultiplayerPeer` (ship/real play).
  - `enet_loopback` → `ENetMultiplayerPeer` on `127.0.0.1` (dev + CI, no Steam needed).
  - Same Godot high-level API (RPC / `MultiplayerSpawner` / `MultiplayerSynchronizer`) on top → gameplay code is transport-agnostic.
- **Player registry**: `peer_id → { fighter_id, display_name, ready, alive_state, deaths }`.
- **Signals** consumed by lobby UI + `GameManager3D`: `player_joined`, `player_left`,
  `registry_changed`, `all_ready`, `host_aborted`.

### 4.2 Authority map

| Thing | Authority | Replication |
|---|---|---|
| Own fighter **movement** (position/facing) | owning client | `MultiplayerSynchronizer` (client-auth) |
| Fighter **HP / downed / respawn / deaths** | **host** | host-owned sync + RPC |
| **Enemies** (spawn, AI, HP, death) | **host** | `MultiplayerSpawner` + `MultiplayerSynchronizer` |
| **XP gems** + **team XP pool / team level** | **host** | host spawns gems; level broadcast by RPC |
| **Team Gold** | **host** | RPC broadcast |
| **Level-up pause & ready-up** | host orchestrates | RPC round-trip (§6.1) |
| Own **weapons/abilities firing + projectiles** | owning client | local sim + cosmetic broadcast + damage RPC (§4.4) |

### 4.3 Fitting the current code
- `Spawner3D`, `GameManager3D` → become **host-only** authorities. Clients don't run them;
  they receive replicated results (enemies, run-state, team XP/gold/level via RPC).
- `Player3D` → split synced properties by authority: **transform = owning client**,
  **hp/downed/respawn = host**. Movement input stays local for responsiveness.
- `GameEvents` autoload → stays the **in-process** signal bus on each peer. Cross-peer
  events travel by RPC through `NetworkManager` / `GameManager3D`, which then re-emit the
  local `GameEvents` signal so existing listeners (VFX, HUD, juice) work unchanged.

### 4.4 Weapon damage authority (decided)
Client-owns-avatar extends to its weapons:
- Each **client simulates its own weapons/abilities locally** (instant, responsive) and
  renders its own projectiles.
- Spawning a projectile broadcasts a **lightweight cosmetic RPC** ("projectile spawned at
  pos/dir with skill_id") so other peers *see* it. Cosmetic only — no per-projectile synchronizer.
- On hit, the client sends **`deal_damage(enemy_id, amount, source_peer)`** to the host,
  which applies it to host-authoritative enemy HP and arbitrates death → XP drop → team XP.
- Trusts clients on their own damage — acceptable for friendly PvE, and keeps each player's
  build/upgrades entirely client-side.

---

## 5. Lobby, connection & character-select flow

1. **Title** → **Host** or **Join**.
2. **Host** → `NetworkManager.create_lobby()`; host is peer 1. **Join** → Steam invite/overlay
   or friends list → `join_lobby(id)`.
3. **Lobby / character-select** (networked; reuses `character_select_3d` UI): shows each
   player, their chosen fighter, and a **ready** flag. Selecting a fighter is local → RPC to
   host → host updates registry → broadcast → all UIs refresh. **Duplicates allowed.**
4. **Host presses Start** (when all ready) → all peers load `main_3d.tscn`; a host-owned
   `MultiplayerSpawner` spawns one `Player3D` per registry entry (with `fighter_id`) at
   distinct spawn points.
5. **In match.**

### Edge cases (minimal for Slice 1)
- **No mid-match join** — lobby only.
- **Client disconnect mid-match** → despawn their fighter; run continues.
- **Host disconnect** → run aborts to title for all (no host migration).
- **Reconnection** — out of scope.

---

## 6. Runtime flows

### 6.1 Synced level-up round-trip (host-orchestrated)
1. Host's **team-XP** pool crosses a threshold → host sets paused state and RPCs
   `begin_levelup(new_level)` to all peers. The whole match freezes (enemies, timer,
   projectiles) via `get_tree().paused` on every peer.
2. Each **client** generates its **own** 1-of-3 offering from its **own** build
   (skills/passives/synergies) — no host involvement (builds are client-side).
3. Player picks → applies locally → RPCs `player_ready(peer_id)` to host. Host marks the
   registry and broadcasts ready-state → **portrait ready-bubbles** update on all peers.
4. When **all alive players** are ready (or a **30s** timeout auto-picks the first offering),
   host RPCs `resume()` → all unpause; existing ~1s resume ramp stays.

*Downed players during level-up:* still get the pause and may pick (Swarm allows it); the
pick applies on revival/respawn.

### 6.2 Downed / revival / respawn state machine (host-authoritative)
Values from the Swarm spec:
- Lethal damage → host flips fighter to **DOWNED** (not dead); starts **10s** downed timer;
  replicates state (others see downed ring + countdown).
- Teammate stands in the downed circle → **revive** → host flips to ALIVE at **50% max HP**
  + **4s invulnerability**.
- Downed timer expires unrescued → **RESPAWN** timer: base **15s**, **+9s per prior death**,
  cap **60s** → auto-respawn at 50% HP at a safe point.
- **All alive players downed simultaneously → defeat** → game-over for all.
- **Solo (1 player):** no downed state — death = today's game-over screen, unchanged.

---

## 7. Testing strategy

**Design rule:** keep RPC/replication as thin adapters over pure logic, so the hard logic is
unit-testable without networking.

1. **GUT unit tests** on extracted `RefCounted` logic classes:
   - Respawn-timer math (`15 + 9·deaths`, cap `60`); downed→revive→respawn transitions.
   - Team-XP accumulation → level-threshold detection.
   - Lobby registry (join/leave/ready; `all_ready` only when all *alive* players ready; duplicate fighters).
2. **Integration**: two local instances via **Run Multiple Instances = 2** (or headless
   ENet-loopback) to verify replication, the level-up round-trip, and revival end-to-end.

---

## 8. Rollout milestones (each independently verifiable with two local instances)

- **M1** — `NetworkManager` + transport seam; two instances connect; registry syncs. *(no gameplay)*
- **M2** — Networked lobby + character select → both load arena with replicated, client-owned avatars moving.
- **M3** — Host-authoritative enemies replicate; client weapons deal damage to host enemies; deaths + XP gems replicate.
- **M4** — Shared team XP + synced level-up round-trip (pause → per-player pick → ready bubbles → resume).
- **M5** — Shared gold; downed/revival/respawn; all-downed defeat.
- **M6** — Polish: disconnect handling, Steam invite flow, confirm solo path unchanged.

---

## 9. Success criteria

- Two+ players (via Steam invite, and via ENet-loopback in dev) can lobby up, each pick a
  fighter, and start into the shared arena.
- All players see each other move, fight, and kill host-authoritative enemies; damage from
  any client resolves on the host.
- One shared XP pool levels the whole team together; each player picks their own card; the
  match pauses and resumes correctly with ready-bubbles.
- Gold is shared. Downed/revival/respawn behave per §6.2; all-downed ends the run.
- Solo play is unchanged from today.
- Extracted-logic GUT tests are green; the existing 1000+ tests remain green.

---

## 10. Assumptions & open questions

- **Assumption:** GodotSteam integrates cleanly with Godot 4.7's high-level multiplayer via
  `SteamMultiplayerPeer` (validate early in M1). If not, ENet direct-IP is the fallback peer
  while Steam integration is sorted.
- **Assumption:** a placeholder "safe spawn point" picker (e.g. nearest low-density arena
  cell) is acceptable for respawns in Slice 1.
- **Open:** exact UI for the lobby/ready screen and portrait ready-bubbles — treated as minor
  additions here; the full HUD overhaul is Slice 9. (Logged to the living graphic UI spec.)

---

## Change log
- **2026-07-01** — Initial design. Decomposed the Swarm transformation into 9 slices;
  fully designed Slice #1 (Co-op Foundation): Steam P2P + ENet-loopback transport seam,
  host-authoritative world / client-owned avatar, team XP & gold, synced level-up round-trip,
  downed/revival/respawn, lobby & character-select flow, testing & rollout milestones.
