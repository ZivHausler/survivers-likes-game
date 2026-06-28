# upgrade-ui

`upgrades/upgrade_ui.gd` / `upgrades/upgrade_ui.tscn` — CanvasLayer

## Responsibilities

Shows up to 3 upgrade choice **cards** side-by-side when the player levels up.
Cards are populated from `UpgradeSystem.build_choices(rng, 3)`.
EVOLUTION cards receive a golden tint (`Color(1.0, 0.85, 0.1)`) and show an "EVOLVE" badge.

**process_mode** is `PROCESS_MODE_WHEN_PAUSED` so the cards respond while `get_tree().paused = true`.

## API

```gdscript
signal chosen(upgrade: Upgrade)

func present(system: UpgradeSystem, player: Player) -> void
```

`present()` calls `build_choices`, populates all three cards, and shows the panel.
Unused cards (when fewer than 3 choices are available) are hidden.
Clicking a card (via `gui_input` on the PanelContainer) calls `_pick(index)`, which hides
the panel and emits `chosen(upgrade)`.
**GameManager** receives `chosen`, calls `upgrade_system.apply(u)` + `_apply_upgrade(u)` + `get_tree().paused = false`.

## Card layout (per card)

Each card shows, top to bottom:
1. **Name** — `u.display_name` (centred)
2. **Icon** — `ColorRect` placeholder badge tinted by kind (see below). PLACEHOLDER: real icons pending art direction.
3. **Description** — `u.description` (word-wrapped)
4. **Stat line** — `u.stat_text` (e.g. "+12 Move Speed")
5. **Level badge** — `"NEW"` if level 0; `"Lv X / max"` if owned; `"EVOLVE"` for EVOLUTION kind

### Placeholder badge colours

| Kind      | Colour                          |
|-----------|----------------------------------|
| SIGNATURE | Red   `(0.75, 0.20, 0.20)`      |
| PASSIVE   | Blue  `(0.20, 0.45, 0.80)`      |
| GENERIC   | Green `(0.30, 0.55, 0.30)`      |
| EVOLUTION | Gold  `(1.00, 0.85, 0.10)`      |

Real icon art will replace these ColorRects with TextureRects once the art direction is decided.

## Upgrade resource fields (upgrade.gd)

Two new optional fields (backward compatible — default to empty string):
- `@export var description: String = ""`  — short flavour text for the card
- `@export var stat_text: String = ""`    — one-line improvement summary (e.g. "+20 Pickup Range")
- `@export var icon: Texture2D`           — optional icon; when null the placeholder badge is used

## Node tree (upgrade_ui.tscn)

```
UpgradeUI  [CanvasLayer, script=upgrade_ui.gd]
└── Panel  [PanelContainer, centered 960×560]
    └── PanelVBox  [VBoxContainer]
        ├── Title  [Label]
        └── CardRow  [HBoxContainer]
            ├── Card0  [PanelContainer, mouse_filter=STOP]
            │   └── CardContent  [VBoxContainer]
            │       ├── NameLabel   [Label]
            │       ├── IconRect    [ColorRect, min_height=72]
            │       ├── DescLabel   [Label, autowrap]
            │       ├── StatLabel   [Label]
            │       └── LevelLabel  [Label]
            ├── Card1  [PanelContainer …]
            │   └── CardContent …
            └── Card2  [PanelContainer …]
                └── CardContent …
```
