# game-over

`ui/game_over.gd` / `ui/game_over.tscn` — Control (full-screen)

## Responsibilities

Shown when `GameEvents.player_died` fires and GameManager routes to this scene.  
Reads `RunState.last_run` (`{time: float, kills: int}`) and displays:

- Survived time (formatted mm:ss)
- Kill count

Provides two buttons:

| Button | Action |
|--------|--------|
| Retry | `change_scene_to_file("res://game/arena.tscn")` |
| Character Select | `change_scene_to_file("res://ui/character_select.tscn")` |

## Node tree (game_over.tscn)

```
GameOver  [Control, full-screen]
└── VBox  [VBoxContainer, centered]
    ├── TitleLabel   [Label]  "GAME OVER"
    ├── TimeLabel    [Label]  "Survived: M:SS"
    ├── KillsLabel   [Label]  "Kills: N"
    ├── RetryButton  [Button]
    └── SelectButton [Button]
```
