# upgrade-ui

`upgrades/upgrade_ui.gd` / `upgrades/upgrade_ui.tscn` — CanvasLayer

## Responsibilities

Shows a 3-button panel when the player levels up.  Buttons are populated from `UpgradeSystem.build_choices(rng, 3)`.  EVOLUTION options receive a golden tint (`Color(1.0, 0.85, 0.1)`).

**process_mode** is `PROCESS_MODE_WHEN_PAUSED` so the buttons respond while `get_tree().paused = true`.

## API

```gdscript
signal chosen(upgrade: Upgrade)

func present(system: UpgradeSystem, player: Player) -> void
```

`present()` calls `build_choices`, populates the buttons, and shows the panel.  
When a button is clicked, `_pick(index)` hides the panel and emits `chosen(upgrade)`.  
**GameManager** receives `chosen`, calls `upgrade_system.apply(u)` + `_apply_upgrade(u)` + `get_tree().paused = false`.

## Node tree (upgrade_ui.tscn)

```
UpgradeUI  [CanvasLayer, script=upgrade_ui.gd]
└── Panel  [PanelContainer, centered]
    └── VBox  [VBoxContainer]
        ├── Title  [Label]
        ├── Button0  [Button]
        ├── Button1  [Button]
        └── Button2  [Button]
```
