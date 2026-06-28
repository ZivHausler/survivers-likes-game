# hud

`ui/hud.gd` / `ui/hud.tscn` — CanvasLayer (top-left overlay)

## Responsibilities

Displays live run stats.  **process_mode = PROCESS_MODE_WHEN_PAUSED** so it stays visible during the upgrade overlay.

| Element    | Source                                         |
|------------|------------------------------------------------|
| Timer      | Polls `GameManager.get_elapsed()` each frame   |
| Kills      | Polls `GameManager.get_kills()` each frame     |
| HP bar     | `GameEvents.player_hp_changed(current, max_hp)` |
| XP bar     | Polls `player.xp` / `player.xp_to_next(level)` |
| Level      | `GameEvents.player_leveled_up(level)` signal    |

GameManager and Player refs are resolved via `call_deferred("_find_siblings")` in `_ready` so the full arena tree is loaded first.

## Node tree (hud.tscn)

```
HUD  [CanvasLayer]
└── VBox  [VBoxContainer, top-left corner]
    ├── TimerLabel   [Label]
    ├── KillsLabel   [Label]
    ├── LevelLabel   [Label]
    ├── HPBar        [ProgressBar]
    └── XPBar        [ProgressBar]
```
