# game-manager-3d

`GameManager3D` (`Node`) — the 3D run loop, parallel to 2D `GameManager`.

Lives as a `Node` child inside `main_3d.tscn`. Resolves siblings from parent.

## Run setup

1. Reads `RunState.selected_character` (set by `CharacterSelect3D`). Falls back to `ziv_3d.tres` if null.
2. Calls `player.setup(char_data)` — installs stats + model.
3. Calls `spawner.setup(player)` — starts enemy waves.
4. Builds the active upgrade system (see below) from `char_data` + 5 generic upgrades.
5. Acquires the signature skill immediately (`player.acquire_skill(sig.id, sig.weapon_scene)`).

## Active upgrade system

`GameManager3D` uses **one of two systems**, chosen at `start()`:

| Path | Condition | System built |
|---|---|---|
| **3D SkillSystem** | `char_data.skills` is non-empty | `SkillSystem.new(char_data.skills, generic_pool)` |
| **Legacy UpgradeSystem** | `skills` is empty, old fields set | `UpgradeSystem.new(char_data, pool, sig, pas, evo)` |

`_active_system()` returns `skill_system ?? upgrade_system`. Tests that need the legacy path
should set `manager.skill_system = null` before injecting `manager.upgrade_system`.

## Level-up pause flow (ported verbatim from 2D GameManager)

On `GameEvents.player_leveled_up`:
- If `_choosing` is already true (mid-pick), queue: `_pending_levelups += 1`.
- If `_active_system().has_available_choices()` is false, call `_grant_max_bonus()` (+5 max_hp) and return.
- Otherwise: `_choosing = true`, `get_tree().paused = true`, call `_present_next()`.

`_present_next()` — re-checks `has_available_choices()` (synergy may unlock mid-chain),
then calls `_upgrade_ui.present(active_system, player)`.

`_on_upgrade_chosen(u)` — applies to active system, routes to player, calls `_resolve_next_or_unpause()`.

`_resolve_next_or_unpause()` — if `_pending_levelups > 0`, decrement and call `_present_next()`
(stays paused); otherwise `_choosing = false`, unpause, then call `player.set_invulnerable(LEVELUP_INVULN)`
(2.0 s). Invulnerability is granted exactly once per level-up chain, only on the final resolution.

## Upgrade routing

### SkillSystem path (`_route_skill_upgrade`)

| Kind    | Condition                               | Effect |
|---------|-----------------------------------------|--------|
| SKILL   | `skill_level(sid) == 1` after apply     | `player.acquire_skill(sid, weapon_scene)` (first acquisition) |
| SKILL   | `skill_level(sid) > 1` after apply      | `player.level_skill(sid)` |
| PASSIVE | —                                       | `player.apply_skill_passive(skill_id, effect_value)` |
| SYNERGY | —                                       | `player.evolve_skill(skill_id)` |
| GENERIC | —                                       | `player.apply_stat_upgrade(effect_kind, effect_value)` |

### Legacy UpgradeSystem path (`_apply_upgrade`)

| Kind      | Effect |
|-----------|--------|
| SIGNATURE | `player.weapon.level_up()` |
| EVOLUTION | `player.weapon.evolve()` |
| PASSIVE   | `player.weapon.apply_passive(effect_value)` |
| GENERIC   | `player.apply_stat_upgrade(effect_kind, effect_value)` |

## Death

On `GameEvents.player_died`: stores `RunState.last_run = {time, kills}`, unpauses,
`change_scene_to_file("res://ui/game_over.tscn")`.

## Node names resolved from parent

| Name         | Type         | Purpose                   |
|--------------|--------------|---------------------------|
| `Player`     | duck-typed   | Player actor              |
| `Spawner3D`  | duck-typed   | Enemy spawner             |
| `UpgradeUI`  | duck-typed   | Level-up card overlay     |

## Juice

Calls `Juice3D.register_player(player)` and `Juice3D.register_camera(cam)` at start.
