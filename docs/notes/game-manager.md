# game-manager

`game/game_manager.gd` — Node child of `arena.tscn`

## Responsibilities

- Accumulates `elapsed` (float, seconds) in `_process` while the tree is not paused.
- Tracks `kills` (int); incremented on every `GameEvents.enemy_killed`.
- Spawns an `XPGem` into the Arena root on `enemy_killed(pos, xp_value)` and calls `gem.setup(xp_value, player)`.
- On `player_leveled_up`: pauses the tree (`get_tree().paused = true`) and calls `upgrade_ui.present(upgrade_system, player)`.
- Connects to `upgrade_ui.chosen` signal; the handler calls `upgrade_system.apply(u)` then `_apply_upgrade(u)` then unpauses.
- On `player_died`: writes `RunState.last_run = {time, kills}` and changes scene to `ui/game_over.tscn`.

## Upgrade-effect router

`GameManager._apply_upgrade(u: Upgrade) -> void`

| u.kind     | Effect                                             |
|------------|----------------------------------------------------|
| SIGNATURE  | `player.weapon.level_up()`                         |
| EVOLUTION  | `player.weapon.evolve()`                           |
| PASSIVE    | `player.weapon.apply_passive(u.effect_value)`      |
| GENERIC    | `player.apply_stat_upgrade(u.effect_kind, u.effect_value)` |

`upgrade_system.apply(u)` is always called FIRST (bookkeeping / evolution signal) — then `_apply_upgrade`.

## Initialisation (in _ready)

1. Resolve `Player`, `Spawner`, `UpgradeUI` siblings via `get_parent().get_node_or_null(...)`.
2. Call `player.setup(RunState.selected_character)`.
3. Call `spawner.setup(player)`.
4. Load the five generic upgrade `.tres` files from `upgrades/generic/`.
5. Construct `UpgradeSystem.new(char_data, generic_pool, sig, pas, evo)`.
6. Connect `upgrade_ui.chosen → _on_upgrade_chosen`.
7. Connect GameEvents signals.

## Public API

| Method / Var      | Description                              |
|-------------------|------------------------------------------|
| `get_elapsed()`   | Seconds since run started (float)        |
| `get_kills()`     | Enemy kill count (int)                   |
| `player`          | Reference to Player; set in _ready or by test harness |
| `upgrade_system`  | UpgradeSystem for this run               |

## Testability

`_apply_upgrade` is callable without a scene tree — just set `gm.player` before calling it. See `test/test_apply_upgrade.gd`.
