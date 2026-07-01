# HUD Polish Phase 6.1b Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the dark sci-fi HUD — theme BossBar + EvolveBanner, add upgrade card hover/selection feedback, add bar rounded corners/neon edges, maintain cohesion.

**Architecture:** All changes are styling-only (StyleBoxFlat values, theme overrides, signal connections). BossBar gets a PanelContainer wrapper (renamed "BossBar") with the old VBoxContainer renamed "BossContent"; BossHPBar gets magenta (enemy_secondary) fill. Upgrade cards get StyleBoxFlat hover overrides set via mouse_entered/exited + focus signals in upgrade_ui.gd. Bar StyleBoxes get corner_radius=3 and 1px neon borders.

**Tech Stack:** Godot 4.7, GDScript, GUT test framework.

## Global Constraints

- Palette: `player_primary`=`Color(0.3,0.8,1.0)` cyan, `player_secondary`=`Color(1.0,0.8,0.2)` gold, `enemy_secondary`=`Color(1.0,0.2,0.6)` magenta, `danger`=`Color(1.0,0.35,0.1)` orange-red.
- Use literals in `.tscn`/`.tres`; use `VisualPalette.role()` in `.gd` code.
- No new HUD widgets (no new gameplay indicators). No gameplay or layout logic changes.
- BossBar wrapper rename requires path updates in `test/test_hud.gd` and `ui/hud.gd`.
- Baseline: 1020/1020 tests passing. No new failures.
- Leave `IconRect` ColorRect placeholder unchanged.

---

### Task 1: Update hud.tscn — bar polish + BossBar panel + EvolveBanner styling

**Files:**
- Modify: `ui/hud.tscn`

**Key changes:**
- `load_steps` 7 → 8 (new sub_resource)
- Add `StyleBoxFlat_bossfill`: `bg_color = Color(1.0, 0.2, 0.6, 1)` with 1px magenta border + corner_radius=3
- All 4 existing StyleBoxFlat: add `corner_radius_*=3`; fill boxes add 1px border (danger orange or cyan, 70% alpha)
- EvolveBanner Label: add `theme_override_colors/font_color = Color(1.0, 0.8, 0.2, 1)`, `theme_override_constants/outline_size = 3`, `theme_override_colors/font_outline_color = Color(0.3, 0.8, 1.0, 0.8)`
- Replace BossBar VBoxContainer with PanelContainer "BossBar" + VBoxContainer "BossContent" child at same approximate position. Set `theme = ExtResource("2_theme")` on BossBar PanelContainer.
- BossHPBar: use `SubResource("StyleBoxFlat_bossfill")` for fill (no longer shares hpfill with player HPBar).

- [ ] **Step 1:** Edit `ui/hud.tscn` — all changes above.
- [ ] **Step 2:** Import: `godot47.exe --headless --import` (verify no errors)

### Task 2: Update hud.gd — fix BossContent paths

**Files:**
- Modify: `ui/hud.gd:13-16`

- [ ] **Step 1:** Update `@onready` paths:
  - `$BossBar/BossNameLabel` → `$BossBar/BossContent/BossNameLabel`
  - `$BossBar/BossHPBar` → `$BossBar/BossContent/BossHPBar`
  - `$BossBar/BossHPBar/BossHPText` → `$BossBar/BossContent/BossHPBar/BossHPText`

### Task 3: Update test_hud.gd — fix BossContent paths

**Files:**
- Modify: `test/test_hud.gd:23-35`

- [ ] **Step 1:** Update `get_node()` calls:
  - `"BossBar/BossNameLabel"` → `"BossBar/BossContent/BossNameLabel"`
  - `"BossBar/BossHPBar"` → `"BossBar/BossContent/BossHPBar"`
  - `"BossBar/BossHPBar/BossHPText"` → `"BossBar/BossContent/BossHPBar/BossHPText"`

### Task 4: Add card hover/focus feedback to upgrade_ui.gd

**Files:**
- Modify: `upgrades/upgrade_ui.gd`

- [ ] **Step 1:** Add `_style_normal` and `_style_hover` StyleBoxFlat vars. Create them in `_ready()`. Connect `mouse_entered`/`mouse_exited`/`focus_entered`/`focus_exited` on each card. Set `focus_mode = Control.FOCUS_ALL`.
- [ ] **Step 2:** Add `_on_card_hover(index: int, hovered: bool)` that calls `add_theme_stylebox_override("panel", ...)`.
- [ ] **Step 3:** Reset hover state per card in `present()` before showing.
- [ ] **Step 4:** Handle keyboard Enter/Space in `_on_card_input`.

### Task 5: Extend test_hud_theme.gd + run tests

**Files:**
- Modify: `test/test_hud_theme.gd`

- [ ] **Step 1:** Add test: `BossBar` PanelContainer has non-null `theme`.
- [ ] **Step 2:** Add test: `EvolveBanner` has `theme_override_colors/font_color` = gold.
- [ ] **Step 3:** Add test: `EvolveBanner` has `outline_size` constant override > 0.
- [ ] **Step 4:** Add test: calling `_on_card_hover(0, true)` changes Card0's panel stylebox.
- [ ] **Step 5:** Run focused: `godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gselect=test_hud_theme.gd -gexit`
- [ ] **Step 6:** Run full suite: `godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`

### Task 6: Docs + commit

- [ ] **Step 1:** Update `docs/notes/swarm-hud-theme.md` with new info.
- [ ] **Step 2:** Write `.superpowers/sdd/phase-6.1b-report.md`.
- [ ] **Step 3:** `git add` specific files and commit.
