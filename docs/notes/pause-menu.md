# Pause Menu

`ui/pause_menu.tscn` / `ui/pause_menu.gd`

A CanvasLayer overlay shown when Escape is pressed during a 3D run.

## Nodes
- **PauseMenu** (CanvasLayer, `process_mode = PROCESS_MODE_WHEN_PAUSED`) — hidden by default.
  - **Panel** (Panel, centered)
    - **VBox** (VBoxContainer)
      - **PausedLabel** (Label, "PAUSED")
      - **ContinueButton** (Button)
      - **RetryButton** (Button)
      - **CharacterSelectButton** (Button)
      - **QuitButton** (Button)

## API
- `open()` — shows the overlay and pauses the scene tree.
- `close()` — hides the overlay and unpauses the scene tree.
- `is_open()` — returns whether the overlay is currently visible.

## Wiring
`GameManager3D` handles `_unhandled_input` for the `ui_cancel` action (Escape).
It guards against toggling the menu while the level-up upgrade-card flow is active (`_choosing`).
The PauseMenu is added to `main_3d.tscn` as a sibling of GameManager3D.
