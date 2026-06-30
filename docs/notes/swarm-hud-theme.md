# swarm-hud-theme

**Phase 6.1 — Dark sci-fi HUD theme** (LoL Swarm visual remake)

## What it is

`res://ui/theme/swarm_hud_theme.tres` — a Godot `Theme` resource that gives the
in-game HUD and level-up card UI a cohesive dark sci-fi look: semi-transparent dark
panels with a thin neon edge, bright readable text, and palette-driven bar fills.

## Design rationale

| Concern | Choice |
|---------|--------|
| Panel background | `Color(0.05, 0.06, 0.10, 0.85)` — deep navy, 85 % opaque so busy background scenery doesn't bleed through; panels recede visually |
| Panel border | 1 px solid `Color(0.3, 0.8, 1.0)` (cyan = `player_primary`) — subtle neon edge without a neon explosion |
| Corner radius | 4 px on panels, 3 px on buttons — just enough to feel cyber-rounded |
| Label font color | `Color(0.9, 0.95, 1.0)` — near-white with a very slight cool tint; maximally legible on dark panels |
| Button normal | Dark navy bg, 60 % cyan border |
| Button hover | Brighter bg, full-opacity cyan border (clear rollover feedback) |
| Button pressed | Bright blue bg, gold (`player_secondary`) border — satisfying confirm feel |
| HP bar fill | `VisualPalette.role(&"danger")` = `Color(1.0, 0.35, 0.1)` — orange-red urgency |
| XP bar fill | `VisualPalette.role(&"player_primary")` = `Color(0.3, 0.8, 1.0)` cyan — matches player identity |
| Enemy HP fill | Same `danger` color via `VisualPalette.role()` in `health_bar_3d.gd` — consistent vocabulary |

## Scenes that consume this theme

| Scene | Node receiving `theme=` | Propagates to |
|-------|------------------------|---------------|
| `ui/hud.tscn` | `VBox` (VBoxContainer) | TimerLabel, KillsLabel, LevelLabel, HP/XP bars |
| `upgrades/upgrade_ui.tscn` | `Panel` (PanelContainer) | Title label, card PanelContainers, all text within |

> The root nodes of both scenes are `CanvasLayer` (not `Control`), so `theme` is
> applied to their first `Control` child. `BossBar` and `EvolveBanner` in the HUD
> are siblings of `VBox` and therefore **not** covered — they use Godot defaults
> for now and can be wrapped or individually themed in a future pass.

## HP/XP bar fills

The bars in `hud.tscn` keep their in-scene `theme_override_styles/fill` and
`theme_override_styles/background` overrides (required by `test_hud_visual.gd`).
Colors were updated to palette values:

- `StyleBoxFlat_hpfill`: `Color(1.0, 0.35, 0.1, 1)` (danger)
- `StyleBoxFlat_hpbg`: `Color(0.05, 0.05, 0.07, 1)` (deep dark)
- `StyleBoxFlat_xpfill`: `Color(0.3, 0.8, 1.0, 1)` (player_primary cyan)
- `StyleBoxFlat_xpbg`: `Color(0.04, 0.12, 0.18, 1)` (kept, dark navy)

`BossHPBar` shares the same sub-resources (hpbg/hpfill), so it inherits the same
danger orange fill and dark bg automatically.

## Enemy health bar (`ui/health_bar_3d.gd`)

`COLOR_FILL` was replaced with a runtime call to `VisualPalette.role(&"danger")` in
`_ready()` (with a literal fallback constant for headless/static contexts).
`COLOR_BG` was adjusted from brownish `(0.07,0.05,0.05)` to neutral dark navy
`(0.05,0.05,0.07)`.

## How to extend

- **Add more styled types**: open `swarm_hud_theme.tres`, add new `[sub_resource]`
  StyleBoxFlat entries and new `TypeName/styles/…` properties in `[resource]`.
- **Apply to new scenes**: set `theme = ExtResource("2_theme")` on any root Control
  node after adding the `[ext_resource]` header line.
- **Palette shifts**: change a role in `visual_palette.gd`; bar fills in GDScript
  pick it up at next `_ready()`. The `.tres` uses literal `Color(…)` values and
  must be updated separately if the palette changes.
