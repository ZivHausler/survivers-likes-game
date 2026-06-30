# swarm-hud-theme

**Phase 6.1b — HUD polish: themed boss/evolve bars + upgrade card hover/selection feedback** (LoL Swarm visual remake)
*(Phase 6.1 established the base dark sci-fi theme; 6.1b closes the gaps.)*

## What it is

`res://ui/theme/swarm_hud_theme.tres` — a Godot `Theme` resource that gives the
in-game HUD and level-up card UI a cohesive dark sci-fi look: semi-transparent dark
panels with a thin neon edge, bright readable text, and palette-driven bar fills.

## Design rationale

| Concern | Choice |
|---------|--------|
| Panel background | `Color(0.05, 0.06, 0.10, 0.85)` — deep navy, 85 % opaque so busy background scenery doesn't bleed through; panels recede visually |
| Panel border | 1 px solid `Color(0.3, 0.8, 1.0)` (cyan = `player_primary`) — subtle neon edge without a neon explosion |
| Corner radius | 4 px on panels/cards, 3 px on bars and buttons — just enough to feel cyber-rounded |
| Label font color | `Color(0.9, 0.95, 1.0)` — near-white with a very slight cool tint; maximally legible on dark panels |
| Button normal | Dark navy bg, 60 % cyan border |
| Button hover | Brighter bg, full-opacity cyan border (clear rollover feedback) |
| Button pressed | Bright blue bg, gold (`player_secondary`) border — satisfying confirm feel |
| HP bar fill | `Color(1.0, 0.35, 0.1)` (`danger`) — orange-red urgency; 1 px orange neon border |
| XP bar fill | `Color(0.3, 0.8, 1.0)` (`player_primary`) cyan — matches player identity; 1 px cyan border |
| Boss HP fill | `Color(1.0, 0.2, 0.6)` (`enemy_secondary` magenta) — visually distinct threat; 1 px magenta border |
| EvolveBanner | Gold `Color(1.0, 0.8, 0.2)` text, 3 px cyan `Color(0.3, 0.8, 1.0, 0.8)` outline — celebratory neon callout |
| Upgrade card normal | `Color(0.05, 0.06, 0.10, 0.85)` bg, 1 px 60%-cyan border — matches panel theme |
| Upgrade card hover | `Color(0.08, 0.14, 0.22, 0.95)` bg, 2 px full-opacity cyan border — clear interactive feedback |
| Enemy HP fill | Same `danger` color via `VisualPalette.role()` in `health_bar_3d.gd` — consistent vocabulary |

## Scenes that consume this theme

| Scene | Node receiving `theme=` | Propagates to |
|-------|------------------------|---------------|
| `ui/hud.tscn` | `VBox` (VBoxContainer) | TimerLabel, KillsLabel, LevelLabel, HP/XP bars |
| `ui/hud.tscn` | `BossBar` (PanelContainer) | BossContent VBox, BossNameLabel, BossHPBar text |
| `upgrades/upgrade_ui.tscn` | `Panel` (PanelContainer) | Title label, card PanelContainers, all text within |

> Root nodes of both scenes are `CanvasLayer` (not `Control`), so `theme` is
> applied to their first `Control` child. Phase 6.1b added `BossBar` (now a
> `PanelContainer`) to the theme. `EvolveBanner` is a free-floating Label with
> explicit `theme_override_*` properties set in-scene for gold + cyan neon callout.

## BossBar panel (phase 6.1b)

`BossBar` was converted from a `VBoxContainer` to a `PanelContainer` so it can draw
a dark sci-fi background. Its original VBox content is now `BossContent` (child of
`BossBar`). `theme = ExtResource("2_theme")` is set on the PanelContainer so Labels
inside inherit the correct neon-white font color and the dark panel background draws.

Paths updated in `ui/hud.gd` (@onready vars) and `test/test_hud.gd` (get_node calls)
to reflect the new `BossBar/BossContent/…` hierarchy.

## Boss HP fill (phase 6.1b)

`BossHPBar` now uses a dedicated `StyleBoxFlat_bossfill` (magenta `enemy_secondary`
= `Color(1.0, 0.2, 0.6)`) instead of sharing `hpfill` with the player HP bar. This
makes the boss bar visually distinct as a threat indicator rather than the same
orange-red as the player's own HP.

## EvolveBanner styling (phase 6.1b)

`EvolveBanner` (Label) has explicit in-scene `theme_override_*` properties:
- `font_color = Color(1.0, 0.8, 0.2)` — gold (`player_secondary`) for a celebratory feel
- `outline_size = 3` — medium neon halo
- `font_outline_color = Color(0.3, 0.8, 1.0, 0.8)` — cyan glow around gold text

No wrapper node needed — the fade tween in `hud.gd` (on `modulate:a`) still works
unchanged.

## HP/XP bar fills (with phase 6.1b polish)

All four bar StyleBoxes now have `corner_radius = 3` for rounded ends. Fill boxes
additionally have a 1 px neon border at 70% opacity:

- `StyleBoxFlat_hpbg`: `Color(0.05, 0.05, 0.07, 1)` (deep dark), corner_radius=3
- `StyleBoxFlat_hpfill`: `Color(1.0, 0.35, 0.1, 1)` (danger), 1 px `Color(1.0, 0.55, 0.2, 0.7)` border, corner_radius=3
- `StyleBoxFlat_xpbg`: `Color(0.04, 0.12, 0.18, 1)` (dark navy), corner_radius=3
- `StyleBoxFlat_xpfill`: `Color(0.3, 0.8, 1.0, 1)` (player_primary cyan), 1 px `Color(0.5, 0.9, 1.0, 0.7)` border, corner_radius=3
- `StyleBoxFlat_bossfill` (new): `Color(1.0, 0.2, 0.6, 1)` (enemy_secondary magenta), 1 px `Color(1.0, 0.4, 0.7, 0.7)` border, corner_radius=3

## Enemy health bar (`ui/health_bar_3d.gd`)

`COLOR_FILL` was replaced with a runtime call to `VisualPalette.role(&"danger")` in
`_ready()` (with a literal fallback constant for headless/static contexts).
`COLOR_BG` was adjusted from brownish `(0.07,0.05,0.05)` to neutral dark navy
`(0.05,0.05,0.07)`.

## Upgrade card hover/focus feedback (phase 6.1b)

Cards in `upgrades/upgrade_ui.tscn` are `PanelContainer` nodes (not `Button`), so
Button hover styles don't apply. Phase 6.1b adds programmatic feedback in
`upgrade_ui.gd`:

- In `_ready()`, two `StyleBoxFlat` objects are created: `_style_card_normal` (dark
  panel + 60%-cyan 1 px border) and `_style_card_hover` (brighter bg + full-opacity
  2 px cyan border).
- `add_theme_stylebox_override("panel", _style_card_normal)` is applied to each card
  in `_ready()`.
- `mouse_entered` / `mouse_exited` and `focus_entered` / `focus_exited` signals swap
  the override between normal and hover styles via `_on_card_hover(index, hovered)`.
- `focus_mode = Control.FOCUS_ALL` enables keyboard navigation; `_on_card_input` now
  also handles `KEY_ENTER` / `KEY_SPACE` so keyboard/controller users can select a card.
- `present()` resets all cards to normal style before showing, clearing any lingering
  hover state from the previous presentation.

The existing selection logic (`gui_input` → `_pick()` → emit `chosen`) is unchanged.

## How to extend

- **Add more styled types**: open `swarm_hud_theme.tres`, add new `[sub_resource]`
  StyleBoxFlat entries and new `TypeName/styles/…` properties in `[resource]`.
- **Apply to new scenes**: set `theme = ExtResource("2_theme")` on any root Control
  node after adding the `[ext_resource]` header line.
- **Palette shifts**: change a role in `visual_palette.gd`; bar fills in GDScript
  pick it up at next `_ready()`. The `.tres` uses literal `Color(…)` values and
  must be updated separately if the palette changes.
