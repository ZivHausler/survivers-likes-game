# GameManager3D

`game/game_manager_3d.gd` — `class_name GameManager3D extends Node`

Minimal run controller for the 3D vertical slice. Lives as a child of `main_3d.tscn`.

## Responsibilities (Task 1.4b)

- Builds world-scaled `CharacterData` + `StatBlock` and calls `player.setup(data)`.
- Instantiates and connects `Spawner3D`.
- Listens to `GameEvents.enemy_killed_3d` → spawns `XPGem3D` at the kill position.
- Maintains `elapsed` timer and `kills` counter.

## NOT in scope (Task 1.5)

- Upgrade UI / level-up pause flow
- Game-over routing
- HUD integration

## World-scale stats

| Stat | Value | Derivation |
|---|---|---|
| `move_speed` | 7.5 | 120 px / 16 |
| `pickup_range` | 5.0 | 80 px / 16 |
| `max_hp` | 100.0 | unchanged |

Weapon: `ZivStunningLooks3D` (`res://weapons/ziv_stunning_looks_3d.tscn`).

## Scene wiring

GameManager3D finds siblings by name from its parent (Main3D):
- `"Player"` → Player3D
- `"Spawner3D"` → Spawner3D

Gems are added to `get_parent()` via `add_child.call_deferred()` (safe from physics callbacks).

## Setup flow

```
main_3d.tscn boots
  └─ GameManager3D._ready()
       └─ start()
            ├─ find Player3D + Spawner3D from parent
            ├─ build CharacterData (world-scaled stats + ziv_stunning_looks_3d weapon)
            ├─ player.setup(cd)   → instantiates weapon, starts auto-fire timer
            ├─ spawner.setup(player) → activates DifficultyTimeline-driven ring spawner
            └─ connect GameEvents.enemy_killed_3d → _on_enemy_killed
```

## See also

- [[game-manager]] — 2D original (upgrade UI, game-over in scope there)
- [[spawner-3d]] — Spawner3D
- [[xp-gem-3d]] — XPGem3D pickup
- [[player-3d]] — Player3D.setup() contract
