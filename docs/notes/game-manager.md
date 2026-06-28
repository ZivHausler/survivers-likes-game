# game-manager

`game/game_manager.gd` — Node child of `arena.tscn`

## Responsibilities

- Accumulates `elapsed` (float, seconds) in `_process` while the tree is not paused.
- Tracks `kills` (int); incremented on every `GameEvents.enemy_killed`.
- Spawns an `XPGem` into the Arena root on `enemy_killed(pos, xp_value)` and calls `gem.setup(xp_value, player)`.
- On `player_leveled_up`: pauses the tree (`get_tree().paused = true`) and presents the upgrade choice — see "Pending level-up queue" below.
- Connects to `upgrade_ui.chosen` signal; the handler calls `upgrade_system.apply(u)` then `_apply_upgrade(u)`, then resolves the next queued level-up or unpauses.
- On `player_died`: writes `RunState.last_run = {time, kills}` and changes scene to `ui/game_over.tscn`.

## Pending level-up queue

`player.add_xp()` emits `player_leveled_up` **synchronously inside a while-loop**, so a single XP pickup can cross several thresholds and fire the signal multiple times re-entrantly. Without serialisation the second `present()` would overwrite the first choice set and a reward would be lost. The queue prevents this:

State:
- `_choosing: bool` — true while a choice is currently on screen.
- `_pending_levelups: int` — count of level-ups received while a choice was already open.

Flow:
1. `_on_player_leveled_up`: if `_choosing`, increment `_pending_levelups` and return. Otherwise set `_choosing = true`, pause the tree, and call `_present_next()`.
2. `_present_next()`: calls `upgrade_ui.present(upgrade_system, player)`. `build_choices` is re-evaluated each call, so an evolution that becomes available across stacked level-ups is offered correctly.
3. `_on_upgrade_chosen`: applies the upgrade (`upgrade_system.apply` + `_apply_upgrade`); then if `_pending_levelups > 0`, decrement it and call `_present_next()` again (tree stays paused, `_choosing` stays true); else set `_choosing = false` and unpause.

Net effect: each level-up gets its own freshly evaluated choice, every reward is applied in sequence, and the tree unpauses exactly once — after the last queued level-up is resolved.

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
