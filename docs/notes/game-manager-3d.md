# game-manager-3d

`GameManager3D` (`Node`) — the 3D run loop, parallel to 2D `GameManager`.

Lives as a `Node` child inside `main_3d.tscn`. Resolves siblings from parent.

## Run setup

1. Reads `RunState.selected_character` (set by `CharacterSelect3D`). Falls back to `ziv_3d.tres` if null.
2. Calls `player.setup(char_data)` — instantiates the 3D weapon.
3. Calls `spawner.setup(player)` — starts enemy waves.
4. Builds `UpgradeSystem` from `char_data` + 5 generic upgrades.

## Level-up pause flow (ported verbatim from 2D GameManager)

On `GameEvents.player_leveled_up`:
- If `_choosing` is already true (mid-pick), queue: `_pending_levelups += 1`.
- If `has_available_choices()` is false, call `_grant_max_bonus()` (+5 max_hp) and return.
- Otherwise: `_choosing = true`, `get_tree().paused = true`, call `_present_next()`.

`_present_next()` — re-checks `has_available_choices()` (evolution may unlock mid-chain),
then calls `_upgrade_ui.present(upgrade_system, player)`.

`_on_upgrade_chosen(u)` — applies upgrade, calls `_resolve_next_or_unpause()`.

`_resolve_next_or_unpause()` — if `_pending_levelups > 0`, decrement and call `_present_next()`
(stays paused); otherwise `_choosing = false`, unpause.

## Upgrade routing (_apply_upgrade)

| Kind        | Effect                                    |
|-------------|-------------------------------------------|
| SIGNATURE   | `player.weapon.level_up()`                |
| EVOLUTION   | `player.weapon.evolve()`                  |
| PASSIVE     | `player.weapon.apply_passive(effect_value)` |
| GENERIC     | `player.apply_stat_upgrade(effect_kind, effect_value)` |

## Death

On `GameEvents.player_died`: stores `RunState.last_run = {time, kills}`, unpauses,
`change_scene_to_file("res://ui/game_over.tscn")`.

## Node names resolved from parent

| Name         | Type         | Purpose                   |
|--------------|--------------|---------------------------|
| `Player`     | `Player3D`   | Player actor              |
| `Spawner3D`  | duck-typed   | Enemy spawner             |
| `UpgradeUI`  | `UpgradeUI`  | Level-up card overlay     |

## Juice

Calls `Juice.register_player(player)` if the method exists (3D Juice is Task 1.6).
