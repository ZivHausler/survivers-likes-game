# hud

`ui/hud.gd` / `ui/hud.tscn` — CanvasLayer (top-left overlay)

## Responsibilities

Displays live run stats.  **process_mode = PROCESS_MODE_ALWAYS** so it stays active both during normal play and while the upgrade overlay pauses the tree.

| Element       | Source                                              |
|---------------|-----------------------------------------------------|
| Timer         | Polls `GameManager.get_elapsed()` each frame        |
| Kills         | Polls `GameManager.get_kills()` each frame          |
| HP bar        | `GameEvents.player_hp_changed(current, max_hp)`     |
| XP bar        | Polls `player.xp` / `player.xp_to_next(level)`     |
| Level         | `GameEvents.player_leveled_up(level)` signal        |
| EVOLVE banner | `GameEvents.evolution_unlocked(weapon_id)` signal   |

GameManager and Player refs are resolved via `call_deferred("_find_siblings")` in `_ready` so the full arena tree is loaded first.

## Node tree (hud.tscn)

```
HUD  [CanvasLayer, process_mode=ALWAYS]
├── VBox  [VBoxContainer, top-left corner]
│   ├── TimerLabel   [Label]
│   ├── KillsLabel   [Label]
│   ├── LevelLabel   [Label, font_size=22 — prominent level display]
│   ├── HPBar        [ProgressBar — red fill, dark red background]
│   └── XPBar        [ProgressBar — cyan fill, dark blue background]
└── EvolveBanner  [Label — centered, font_size=48, hidden by default]
```

## Styled bars (Task D1)

HPBar and XPBar both use `StyleBoxFlat` theme overrides set directly in hud.tscn:

- `theme_override_styles/background` — dark contrasting track so the bar is readable when near-empty
- `theme_override_styles/fill` — solid colour fill (red for HP, cyan for XP)

| Bar   | Fill colour         | Background colour    |
|-------|---------------------|----------------------|
| HPBar | `#d91a1a` (red)     | `#260a0a` (dark red) |
| XPBar | `#00e5e5` (cyan)    | `#0a1f2e` (dark blue)|

## EVOLVE banner (Task D1)

`EvolveBanner` is a centered Label that starts hidden (`visible = false`).  
When `GameEvents.evolution_unlocked` fires, `hud.gd` sets it visible and runs a 2-second fade-out tween (0.5 s hold then fade), hiding it again on completion.
