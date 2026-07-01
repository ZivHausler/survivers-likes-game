# HUD Remake — Command Bar Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `ui/hud.tscn` and `ui/hud.gd` into a polished full-screen "command bar" HUD (dark neon sci-fi, Battlerite/LoL-Swarm vibe) while preserving every data binding and keeping the 1063-test GUT suite green.

**Architecture:** The CanvasLayer stays intact. All static structural nodes move from GDScript `_ready()` construction into the `.tscn` scene file. `hud.gd` switches from dynamically-creating its root zones to `@onready` references. A new `ui/hud_icon.gd` (HUDIcon class) provides all five crisp drawn icons via `_draw()`. Tests are repointed to the new node paths; no assertions are deleted.

**Tech Stack:** Godot 4.7 GDScript, GUT test addon, `ui/radial_cooldown.gd` (reused), `ui/theme/swarm_hud_theme.tres` (reused).

## Global Constraints

- Engine: Godot 4.7. Headless boot must stay clean. Baseline: 1063/1063 tests passing.
- Branch: `feature/lol-swarm-visual-remake`. Stage only: `ui/hud.tscn`, `ui/hud.gd`, `ui/hud_icon.gd`, `test/test_hud.gd`, `test/test_hud_visual.gd`, `test/test_hud_theme.gd`. Never `git add -A`.
- `process_mode = PROCESS_MODE_ALWAYS` must stay set.
- `collect_cooldowns(player)` and `collect_passives(player)` signatures and behavior must not change.
- `_find_siblings()` resolution logic must not change.
- BossBar node path `BossBar/BossContent/BossNameLabel`, `BossBar/BossContent/BossHPBar`, `BossBar/BossContent/BossHPBar/BossHPText` must be preserved (tests rely on them).
- EvolveBanner node name must stay `EvolveBanner` at the HUD root level.
- Godot import command: `/c/Users/avino/tools/godot47/godot47.exe --headless --import`
- Test run command: `/c/Users/avino/tools/godot47/godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`

---

## File Structure

**Created:**
- `ui/hud_icon.gd` — HUDIcon class; five icon types drawn in `_draw()` (clock, skull, heart, chevron, ultimate).

**Fully rewritten:**
- `ui/hud.tscn` — New node tree (TopStrip + XPBar, CommandBar with Passives/HP/Weapons/Ult, BossBar unchanged, EvolveBanner unchanged).
- `ui/hud.gd` — `@onready` repoint for all moved nodes; `_ready()` stripped of zone-construction code; `_hp_text` added; kills display simplified; weapon slot creation updated with TextureRect placeholder.

**Updated (repoint only):**
- `test/test_hud_visual.gd` — 4 node paths updated for HP/XP bars; 3 new layout-existence assertions added.
- `test/test_hud_theme.gd` — `test_hud_vbox_theme_is_set` updated to check `TopStrip` instead of `VBox`; comment updated.

**Not changed:**
- `test/test_hud.gd` — BossBar paths unchanged; no edits needed.
- `ui/radial_cooldown.gd` — Reused as-is.
- `ui/theme/swarm_hud_theme.tres` — Reused as-is.

---

## New Node Tree (complete)

```
HUD (CanvasLayer, process_mode=3)
├── TopStrip (PanelContainer)          anchor 0,0→1,0  h=52px  theme=swarm
│   └── StripVBox (VBoxContainer)
│       ├── StripRow (HBoxContainer)
│       │   ├── ClockIcon  (Control + HUDIcon, CLOCK)
│       │   ├── TimerLabel (Label, "0:00")
│       │   ├── HSpacer    (Control, h_size_flags=EXPAND)
│       │   ├── SkullIcon  (Control + HUDIcon, SKULL)
│       │   ├── KillsLabel (Label, "0")
│       │   └── LevelBadge (PanelContainer)
│       │       └── LevelLabel (Label, "LV 1")
│       └── XPBar (ProgressBar, 10px tall, full-width, cyan fill)
│
├── CommandBar (PanelContainer)        anchor 0.05,1→0.95,1  h=76px  theme=swarm
│   └── CBContent (HBoxContainer)
│       ├── PassivesBox (HBoxContainer)          [populated dynamically]
│       ├── HPZone (HBoxContainer, EXPAND)
│       │   ├── HeartIcon (Control + HUDIcon, HEART, danger-orange)
│       │   └── HPBarContainer (Control, EXPAND)
│       │       └── HPBar (ProgressBar, FULL_RECT, danger fill)
│       │           └── HPText (Label, FULL_RECT, "100 / 100", centered)
│       └── RightZone (HBoxContainer)
│           ├── WeaponsBox (HBoxContainer)       [populated dynamically]
│           └── UltSlot (PanelContainer, gold border)
│               └── UltSlotContent (VBoxContainer)
│                   ├── UltRadial (Control + RadialCooldown, 50×50, hidden)
│                   └── SpaceLabel (Label, "SPACE", 9pt)
│
├── BossBar (PanelContainer)           UNCHANGED — anchor center-top
│   └── BossContent (VBoxContainer)   UNCHANGED
│       ├── BossNameLabel (Label)      UNCHANGED
│       └── BossHPBar (ProgressBar)   UNCHANGED
│           └── BossHPText (Label)    UNCHANGED
│
└── EvolveBanner (Label)               UNCHANGED — anchor center 0.3
```

---

## Task 1: Create `ui/hud_icon.gd`

**Files:**
- Create: `ui/hud_icon.gd`

**Interfaces:**
- Produces: `class_name HUDIcon extends Control` with `@export var icon_type: Type` (enum CLOCK=0, SKULL=1, HEART=2, CHEVRON=3, ULTIMATE=4) and `@export var icon_color: Color`. `_draw()` dispatches per type. Referenced in `hud.tscn` as `script` on five Control nodes.

- [ ] **Step 1: Write `ui/hud_icon.gd`**

```gdscript
# See docs/notes/hud.md
class_name HUDIcon extends Control
## Crisp in-engine icons for the command-bar HUD. Drawn via polygons/arcs; sharp at 1440p.

enum Type { CLOCK = 0, SKULL = 1, HEART = 2, CHEVRON = 3, ULTIMATE = 4 }

@export var icon_type: Type = Type.CLOCK
@export var icon_color: Color = Color(0.9, 0.95, 1.0)

func _draw() -> void:
	match icon_type:
		Type.CLOCK:    _draw_clock()
		Type.SKULL:    _draw_skull()
		Type.HEART:    _draw_heart()
		Type.CHEVRON:  _draw_chevron()
		Type.ULTIMATE: _draw_ultimate()

func _draw_clock() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	draw_arc(c, r, 0.0, TAU, 32, icon_color, 2.0)
	for i in 4:
		var angle := i * TAU / 4.0 - PI / 2.0
		draw_line(c + Vector2(cos(angle), sin(angle)) * r * 0.70,
		          c + Vector2(cos(angle), sin(angle)) * r * 0.90, icon_color, 2.0)
	draw_line(c, c + Vector2(-r * 0.35, -r * 0.45), icon_color, 2.5)
	draw_line(c, c + Vector2(0.0, -r * 0.65), icon_color, 1.5)

func _draw_skull() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.38
	draw_circle(c + Vector2(0.0, -r * 0.10), r * 0.62, icon_color)
	draw_circle(c + Vector2(-r * 0.23, -r * 0.18), r * 0.16, Color.BLACK)
	draw_circle(c + Vector2( r * 0.23, -r * 0.18), r * 0.16, Color.BLACK)
	draw_line(c + Vector2(-r * 0.42, r * 0.22), c + Vector2(r * 0.42, r * 0.22), icon_color, 2.0)
	for i in 3:
		var x := c.x + (i - 1) * r * 0.30
		draw_line(Vector2(x, c.y + r * 0.22), Vector2(x, c.y + r * 0.50), icon_color, 2.0)

func _draw_heart() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) / 32.0
	var pts := PackedVector2Array()
	for i in 40:
		var t := i / 40.0 * TAU
		var x :=  16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * s)
	draw_polygon(pts, PackedColorArray([icon_color]))

func _draw_chevron() -> void:
	var c := size * 0.5
	var w := size.x * 0.65
	var h := size.y * 0.40
	draw_polyline(PackedVector2Array([
		c + Vector2(-w * 0.5,  h * 0.25),
		c + Vector2(0.0,      -h * 0.50),
		c + Vector2( w * 0.5,  h * 0.25),
	]), icon_color, 3.0)

func _draw_ultimate() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.40
	var pts := PackedVector2Array()
	for i in 8:
		var outer_a := i / 8.0 * TAU - PI / 2.0
		var inner_a := (i + 0.5) / 8.0 * TAU - PI / 2.0
		pts.append(c + Vector2(cos(outer_a), sin(outer_a)) * r)
		pts.append(c + Vector2(cos(inner_a), sin(inner_a)) * r * 0.45)
	draw_polygon(pts, PackedColorArray([icon_color]))
```

- [ ] **Step 2: Run headless import to register the new script**

```
/c/Users/avino/tools/godot47/godot47.exe --headless --import
```
Expected: exits cleanly (possibly prints warnings about null materials — that's benign).

---

## Task 2: Rebuild `ui/hud.tscn`

**Files:**
- Modify: `ui/hud.tscn` (full rewrite)

**Interfaces:**
- Consumes: `ui/hud.gd` (uid://dg51ebxxt1vyo), `ui/theme/swarm_hud_theme.tres`, `ui/hud_icon.gd` (no uid yet — assigned on import), `ui/radial_cooldown.gd` (uid://jrfkswbgsu2j).
- Produces: node paths `TopStrip/StripVBox/StripRow/TimerLabel`, `TopStrip/StripVBox/XPBar`, `CommandBar/CBContent/HPZone/HPBarContainer/HPBar`, `CommandBar/CBContent/HPZone/HPBarContainer/HPBar/HPText`, `CommandBar/CBContent/PassivesBox`, `CommandBar/CBContent/RightZone/WeaponsBox`, `CommandBar/CBContent/RightZone/UltSlot/UltSlotContent/UltRadial`, `BossBar`, `BossBar/BossContent/BossNameLabel`, `BossBar/BossContent/BossHPBar`, `BossBar/BossContent/BossHPBar/BossHPText`, `EvolveBanner`.

- [ ] **Step 1: Write `ui/hud.tscn`**

```
[gd_scene load_steps=14 format=3]

[ext_resource type="Script" uid="uid://dg51ebxxt1vyo" path="res://ui/hud.gd" id="1_hud"]
[ext_resource type="Theme" path="res://ui/theme/swarm_hud_theme.tres" id="2_theme"]
[ext_resource type="Script" path="res://ui/hud_icon.gd" id="3_icon"]
[ext_resource type="Script" uid="uid://jrfkswbgsu2j" path="res://ui/radial_cooldown.gd" id="4_radial"]

[sub_resource type="StyleBoxFlat" id="SB_strip"]
bg_color = Color(0.04, 0.05, 0.09, 0.93)
border_width_bottom = 2
border_color = Color(0.3, 0.8, 1.0, 0.70)
content_margin_left = 8.0
content_margin_top = 4.0
content_margin_right = 8.0
content_margin_bottom = 3.0

[sub_resource type="StyleBoxFlat" id="SB_cmdbar"]
bg_color = Color(0.05, 0.06, 0.10, 0.92)
border_width_left = 1
border_width_top = 2
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.8, 1.0, 0.70)
corner_radius_top_left = 6
corner_radius_top_right = 6
content_margin_left = 8.0
content_margin_top = 6.0
content_margin_right = 8.0
content_margin_bottom = 6.0

[sub_resource type="StyleBoxFlat" id="SB_lvlbadge"]
bg_color = Color(0.10, 0.20, 0.35, 0.90)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.8, 1.0, 0.60)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3
content_margin_left = 4.0
content_margin_top = 1.0
content_margin_right = 4.0
content_margin_bottom = 1.0

[sub_resource type="StyleBoxFlat" id="SB_ultslot"]
bg_color = Color(0.10, 0.08, 0.04, 0.92)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(1.0, 0.8, 0.2, 0.60)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4
content_margin_left = 4.0
content_margin_top = 4.0
content_margin_right = 4.0
content_margin_bottom = 2.0

[sub_resource type="StyleBoxFlat" id="SB_hpbg"]
bg_color = Color(0.05, 0.05, 0.07, 1)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4

[sub_resource type="StyleBoxFlat" id="SB_hpfill"]
bg_color = Color(1.0, 0.35, 0.1, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(1.0, 0.55, 0.2, 0.70)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4

[sub_resource type="StyleBoxFlat" id="SB_xpbg"]
bg_color = Color(0.04, 0.12, 0.18, 1)
corner_radius_top_left = 2
corner_radius_top_right = 2
corner_radius_bottom_right = 2
corner_radius_bottom_left = 2

[sub_resource type="StyleBoxFlat" id="SB_xpfill"]
bg_color = Color(0.3, 0.8, 1.0, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.5, 0.9, 1.0, 0.70)
corner_radius_top_left = 2
corner_radius_top_right = 2
corner_radius_bottom_right = 2
corner_radius_bottom_left = 2

[sub_resource type="StyleBoxFlat" id="SB_bossbg"]
bg_color = Color(0.05, 0.05, 0.07, 1)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3

[sub_resource type="StyleBoxFlat" id="SB_bossfill"]
bg_color = Color(1.0, 0.2, 0.6, 1)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(1.0, 0.4, 0.7, 0.70)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3

[node name="HUD" type="CanvasLayer"]
process_mode = 3
script = ExtResource("1_hud")

[node name="TopStrip" type="PanelContainer" parent="."]
theme = ExtResource("2_theme")
anchor_right = 1.0
offset_bottom = 52.0
theme_override_styles/panel = SubResource("SB_strip")

[node name="StripVBox" type="VBoxContainer" parent="TopStrip"]
theme_override_constants/separation = 2

[node name="StripRow" type="HBoxContainer" parent="TopStrip/StripVBox"]
theme_override_constants/separation = 6

[node name="ClockIcon" type="Control" parent="TopStrip/StripVBox/StripRow"]
script = ExtResource("3_icon")
custom_minimum_size = Vector2(20, 20)
icon_type = 0
icon_color = Color(0.6, 0.85, 1.0, 1.0)

[node name="TimerLabel" type="Label" parent="TopStrip/StripVBox/StripRow"]
text = "0:00"

[node name="HSpacer" type="Control" parent="TopStrip/StripVBox/StripRow"]
size_flags_horizontal = 3

[node name="SkullIcon" type="Control" parent="TopStrip/StripVBox/StripRow"]
script = ExtResource("3_icon")
custom_minimum_size = Vector2(20, 20)
icon_type = 1
icon_color = Color(0.9, 0.95, 1.0, 1.0)

[node name="KillsLabel" type="Label" parent="TopStrip/StripVBox/StripRow"]
text = "0"

[node name="LevelBadge" type="PanelContainer" parent="TopStrip/StripVBox/StripRow"]
theme_override_styles/panel = SubResource("SB_lvlbadge")

[node name="LevelLabel" type="Label" parent="TopStrip/StripVBox/StripRow/LevelBadge"]
text = "LV 1"
theme_override_font_sizes/font_size = 11

[node name="XPBar" type="ProgressBar" parent="TopStrip/StripVBox"]
custom_minimum_size = Vector2(0, 10)
size_flags_horizontal = 3
max_value = 10.0
value = 0.0
show_percentage = false
theme_override_styles/background = SubResource("SB_xpbg")
theme_override_styles/fill = SubResource("SB_xpfill")

[node name="CommandBar" type="PanelContainer" parent="."]
theme = ExtResource("2_theme")
anchor_left = 0.05
anchor_right = 0.95
anchor_top = 1.0
anchor_bottom = 1.0
offset_top = -80.0
offset_bottom = -4.0
grow_vertical = 0
theme_override_styles/panel = SubResource("SB_cmdbar")

[node name="CBContent" type="HBoxContainer" parent="CommandBar"]
theme_override_constants/separation = 8

[node name="PassivesBox" type="HBoxContainer" parent="CommandBar/CBContent"]
theme_override_constants/separation = 4

[node name="HPZone" type="HBoxContainer" parent="CommandBar/CBContent"]
size_flags_horizontal = 3

[node name="HeartIcon" type="Control" parent="CommandBar/CBContent/HPZone"]
script = ExtResource("3_icon")
custom_minimum_size = Vector2(24, 24)
icon_type = 2
icon_color = Color(1.0, 0.35, 0.1, 1.0)

[node name="HPBarContainer" type="Control" parent="CommandBar/CBContent/HPZone"]
size_flags_horizontal = 3
size_flags_vertical = 3
custom_minimum_size = Vector2(80, 36)

[node name="HPBar" type="ProgressBar" parent="CommandBar/CBContent/HPZone/HPBarContainer"]
anchor_right = 1.0
anchor_bottom = 1.0
max_value = 100.0
value = 100.0
show_percentage = false
theme_override_styles/background = SubResource("SB_hpbg")
theme_override_styles/fill = SubResource("SB_hpfill")

[node name="HPText" type="Label" parent="CommandBar/CBContent/HPZone/HPBarContainer/HPBar"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
text = "100 / 100"
horizontal_alignment = 1
vertical_alignment = 1
theme_override_font_sizes/font_size = 12

[node name="RightZone" type="HBoxContainer" parent="CommandBar/CBContent"]
theme_override_constants/separation = 6

[node name="WeaponsBox" type="HBoxContainer" parent="CommandBar/CBContent/RightZone"]
theme_override_constants/separation = 6

[node name="UltSlot" type="PanelContainer" parent="CommandBar/CBContent/RightZone"]
custom_minimum_size = Vector2(60, 60)
theme_override_styles/panel = SubResource("SB_ultslot")

[node name="UltSlotContent" type="VBoxContainer" parent="CommandBar/CBContent/RightZone/UltSlot"]
theme_override_constants/separation = 2

[node name="UltRadial" type="Control" parent="CommandBar/CBContent/RightZone/UltSlot/UltSlotContent"]
script = ExtResource("4_radial")
custom_minimum_size = Vector2(50, 50)
visible = false

[node name="SpaceLabel" type="Label" parent="CommandBar/CBContent/RightZone/UltSlot/UltSlotContent"]
text = "SPACE"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 9

[node name="BossBar" type="PanelContainer" parent="."]
visible = false
anchor_left = 0.5
anchor_right = 0.5
offset_left = -330.0
offset_top = 4.0
offset_right = 330.0
offset_bottom = 76.0
grow_horizontal = 2
theme = ExtResource("2_theme")

[node name="BossContent" type="VBoxContainer" parent="BossBar"]
theme_override_constants/separation = 2
alignment = 1

[node name="BossNameLabel" type="Label" parent="BossBar/BossContent"]
text = "Boss"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 20

[node name="BossHPBar" type="ProgressBar" parent="BossBar/BossContent"]
custom_minimum_size = Vector2(640, 26)
max_value = 100.0
value = 100.0
show_percentage = false
theme_override_styles/background = SubResource("SB_bossbg")
theme_override_styles/fill = SubResource("SB_bossfill")

[node name="BossHPText" type="Label" parent="BossBar/BossContent/BossHPBar"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
text = "0 / 0"
horizontal_alignment = 1
vertical_alignment = 1

[node name="EvolveBanner" type="Label" parent="."]
visible = false
mouse_filter = 2
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 0.3
anchor_bottom = 0.3
offset_left = -200.0
offset_right = 200.0
offset_top = -40.0
offset_bottom = 40.0
text = "EVOLVE!"
horizontal_alignment = 1
theme_override_colors/font_color = Color(1.0, 0.8, 0.2, 1)
theme_override_colors/font_outline_color = Color(0.3, 0.8, 1.0, 0.8)
theme_override_constants/outline_size = 3
theme_override_font_sizes/font_size = 48
```

- [ ] **Step 2: Run headless import to validate scene loads**

```
/c/Users/avino/tools/godot47/godot47.exe --headless --import
```
Expected: exits cleanly, no scene parse errors for hud.tscn.

---

## Task 3: Update `ui/hud.gd`

**Files:**
- Modify: `ui/hud.gd` (full rewrite — same behavior, updated paths)

**Interfaces:**
- Consumes: scene nodes at paths listed in the new tscn.
- Produces: same public methods: `collect_cooldowns(player)->Array`, `collect_passives(player)->Array`, same signal handlers.

- [ ] **Step 1: Write the updated `ui/hud.gd`**

```gdscript
# See docs/notes/hud.md
class_name HUD extends CanvasLayer
## In-run heads-up display: top status strip (timer/kills/level/XP) and bottom command bar
## (HP, weapon cooldown slots, ultimate slot, passives).
## process_mode = PROCESS_MODE_ALWAYS so _process runs BOTH during normal play
## (live timer/kills/XP) and while the level-up overlay pauses the tree.

@onready var _timer_label:   Label          = $TopStrip/StripVBox/StripRow/TimerLabel
@onready var _kills_label:   Label          = $TopStrip/StripVBox/StripRow/KillsLabel
@onready var _level_label:   Label          = $TopStrip/StripVBox/StripRow/LevelBadge/LevelLabel
@onready var _hp_bar:        ProgressBar    = $CommandBar/CBContent/HPZone/HPBarContainer/HPBar
@onready var _hp_text:       Label          = $CommandBar/CBContent/HPZone/HPBarContainer/HPBar/HPText
@onready var _xp_bar:        ProgressBar    = $TopStrip/StripVBox/XPBar
@onready var _evolve_banner: Label          = $EvolveBanner
@onready var _boss_bar:      Control        = $BossBar
@onready var _boss_name:     Label          = $BossBar/BossContent/BossNameLabel
@onready var _boss_hp_bar:   ProgressBar    = $BossBar/BossContent/BossHPBar
@onready var _boss_hp_text:  Label          = $BossBar/BossContent/BossHPBar/BossHPText
@onready var _passives_box:  HBoxContainer  = $CommandBar/CBContent/PassivesBox
@onready var _weapons_box:   HBoxContainer  = $CommandBar/CBContent/RightZone/WeaponsBox
@onready var _ult_radial:    RadialCooldown = $CommandBar/CBContent/RightZone/UltSlot/UltSlotContent/UltRadial

var _game_manager: Node = null  # duck-typed: GameManager (2D) or GameManager3D
var _player: Node = null        # duck-typed: Player (2D) or Player3D
var _evolve_tween: Tween = null
var _passive_panels: Array = []
var _passive_last_count: int = 0
var _cd_bars: Array[ProgressBar] = []
var _cd_last_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameEvents.player_hp_changed.connect(_on_hp_changed)
	GameEvents.player_leveled_up.connect(_on_leveled_up)
	GameEvents.evolution_unlocked.connect(_on_evolution_unlocked)
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_hp_changed.connect(_on_boss_hp_changed)
	GameEvents.boss_died.connect(_on_boss_died)
	call_deferred("_find_siblings")

func _find_siblings() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# GameManager: try 2D name, then 3D name, then any sibling with get_elapsed().
	_game_manager = parent.get_node_or_null("GameManager")
	if _game_manager == null:
		_game_manager = parent.get_node_or_null("GameManager3D")
	if _game_manager == null:
		for child in parent.get_children():
			if child.has_method("get_elapsed"):
				_game_manager = child
				break
	# Player: prefer the "player" group (both Player and Player3D are in it),
	# fall back to a sibling named "Player".
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = parent.get_node_or_null("Player")

func _process(_dt: float) -> void:
	if _game_manager and is_instance_valid(_game_manager):
		if _game_manager.has_method("get_elapsed"):
			var secs := int(_game_manager.get_elapsed())
			_timer_label.text = "%d:%02d" % [int(secs / 60.0), secs % 60]
		if _game_manager.has_method("get_kills"):
			_kills_label.text = "%d" % _game_manager.get_kills()
	if _player and is_instance_valid(_player):
		if _player.has_method("xp_to_next") and "level" in _player:
			_xp_bar.max_value = _player.xp_to_next(_player.get("level"))
		if "xp" in _player:
			_xp_bar.value = _player.get("xp")
	_update_cooldown_bars()

func _on_hp_changed(current: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value     = current
	_hp_text.text = "%d / %d" % [int(max(current, 0.0)), int(max_hp)]

func _on_leveled_up(level: int) -> void:
	_level_label.text = "LV %d" % level

func _on_evolution_unlocked(_weapon_id: StringName) -> void:
	# Kill any in-flight fade so a rapid second evolution doesn't leave the old
	# tween's hide-callback to blink the banner off mid-fade.
	if _evolve_tween and _evolve_tween.is_valid():
		_evolve_tween.kill()
	_evolve_banner.modulate = Color.WHITE
	_evolve_banner.visible = true
	_evolve_tween = create_tween()
	_evolve_tween.tween_property(_evolve_banner, "modulate:a", 0.0, 2.0).set_delay(0.5)
	_evolve_tween.tween_callback(func(): _evolve_banner.visible = false)

func _on_boss_spawned(boss_name: String, max_hp: float) -> void:
	_boss_name.text = boss_name
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = max_hp
	_boss_hp_text.text = "%d / %d" % [int(max_hp), int(max_hp)]
	_boss_bar.visible = true

func _on_boss_hp_changed(current: float, max_hp: float) -> void:
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = current
	_boss_hp_text.text = "%d / %d" % [int(max(current, 0.0)), int(max_hp)]

func _on_boss_died() -> void:
	_boss_bar.visible = false

## Gather one cooldown entry per active skill: weapons first, ultimate last.
## Each entry: { "id": StringName, "fraction": float, "is_ultimate": bool }.
## Pure — does not access @onready nodes; safe to call from tests with stub players.
func collect_cooldowns(player) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	var weapons = player.get("weapons")
	if weapons is Dictionary:
		for id in weapons:
			var w = weapons[id]
			if w and w.has_method("cooldown_fraction"):
				out.append({ "id": id, "fraction": w.cooldown_fraction(), "is_ultimate": false })
	var ult = player.get("ultimate")
	if ult and ult.has_method("cooldown_fraction"):
		out.append({ "id": &"ultimate", "fraction": ult.cooldown_fraction(), "is_ultimate": true })
	return out

## Acquired passives for the left HUD zone. Pure (stub-friendly).
func collect_passives(player) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	var p = player.get("passives")
	if p is Dictionary:
		for id in p:
			out.append({ "id": id, "level": int(p[id]) })
	return out

## Sync the three cooldown zones with the current player's skill states.
func _update_cooldown_bars() -> void:
	if _weapons_box == null:
		return
	var all_entries: Array = collect_cooldowns(_player)

	# Split into weapon entries and ultimate entry.
	var weapon_entries: Array = []
	var ult_entry = null
	for e in all_entries:
		if e["is_ultimate"]:
			ult_entry = e
		else:
			weapon_entries.append(e)

	# --- Right zone: weapon slots ---
	if weapon_entries.size() != _cd_last_count:
		for child in _weapons_box.get_children():
			child.queue_free()
		_cd_bars.clear()
		for i in weapon_entries.size():
			var panel := Panel.new()
			panel.custom_minimum_size = Vector2(48, 48)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
			style.set_corner_radius_all(4)
			style.border_width_left   = 1
			style.border_width_top    = 1
			style.border_width_right  = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.3, 0.8, 1.0, 0.5)
			panel.add_theme_stylebox_override("panel", style)
			# TextureRect placeholder (real art assigned in a later task)
			var icon_rect := TextureRect.new()
			icon_rect.name = "IconTexture"
			icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(icon_rect)
			# Cooldown overlay bar (transparent bg, cyan fill)
			var bar := ProgressBar.new()
			bar.name = "Bar"
			bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bar.max_value = 1.0
			bar.value = weapon_entries[i]["fraction"]
			bar.show_percentage = false
			var bg_style := StyleBoxFlat.new()
			bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			bar.add_theme_stylebox_override("background", bg_style)
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = Color(0.2, 0.7, 1.0, 0.6)
			bar.add_theme_stylebox_override("fill", fill_style)
			panel.add_child(bar)
			# ID abbreviation — fallback label when no texture is loaded
			var id_lbl := Label.new()
			id_lbl.name = "IDLabel"
			id_lbl.text = str(weapon_entries[i]["id"]).substr(0, 4).to_upper()
			id_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			id_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			id_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			id_lbl.add_theme_font_size_override("font_size", 8)
			id_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(id_lbl)
			# READY glow label
			var ready_lbl := Label.new()
			ready_lbl.name = "ReadyLabel"
			ready_lbl.text = "READY"
			ready_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ready_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			ready_lbl.add_theme_font_size_override("font_size", 9)
			ready_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			ready_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ready_lbl.visible = false
			panel.add_child(ready_lbl)
			_weapons_box.add_child(panel)
			_cd_bars.append(bar)
		_cd_last_count = weapon_entries.size()
	for i in weapon_entries.size():
		if i >= _cd_bars.size():
			break
		var frac: float = weapon_entries[i]["fraction"]
		_cd_bars[i].value = frac
		var ready_lbl: Label = _cd_bars[i].get_parent().get_node_or_null("ReadyLabel")
		if ready_lbl:
			ready_lbl.visible = frac >= 1.0

	# --- Ultimate slot: radial sweep ---
	if _ult_radial != null:
		if ult_entry != null:
			_ult_radial.visible = true
			_ult_radial.set_fraction(ult_entry["fraction"])
		else:
			_ult_radial.visible = false

	# --- Left zone: passives ---
	if _passives_box != null:
		var passive_entries: Array = collect_passives(_player)
		if passive_entries.size() != _passive_last_count:
			for child in _passives_box.get_children():
				child.queue_free()
			_passive_panels.clear()
			for e in passive_entries:
				var panel := Panel.new()
				panel.custom_minimum_size = Vector2(40, 40)
				var style := StyleBoxFlat.new()
				style.bg_color = Color(0.1, 0.08, 0.15, 0.9)
				style.set_corner_radius_all(4)
				style.border_width_left   = 1
				style.border_width_top    = 1
				style.border_width_right  = 1
				style.border_width_bottom = 1
				style.border_color = Color(0.6, 0.3, 1.0, 0.5)
				panel.add_theme_stylebox_override("panel", style)
				var lbl := Label.new()
				lbl.text = str(e["id"]).substr(0, 3).to_upper()
				lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", 8)
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				panel.add_child(lbl)
				var lvl_lbl := Label.new()
				lvl_lbl.name = "LevelLabel"
				lvl_lbl.text = "x%d" % e["level"]
				lvl_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				lvl_lbl.offset_top    = -14.0
				lvl_lbl.offset_bottom =   0.0
				lvl_lbl.offset_left   = -20.0
				lvl_lbl.offset_right  =   0.0
				lvl_lbl.add_theme_font_size_override("font_size", 8)
				lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				panel.add_child(lvl_lbl)
				_passives_box.add_child(panel)
				_passive_panels.append(panel)
			_passive_last_count = passive_entries.size()
		# Always refresh level labels in-place so a level-up (count unchanged) is shown.
		for i in passive_entries.size():
			if i >= _passive_panels.size():
				break
			var lvl_lbl: Label = _passive_panels[i].get_node_or_null("LevelLabel")
			if lvl_lbl:
				lvl_lbl.text = "x%d" % passive_entries[i]["level"]
```

- [ ] **Step 2: Run headless import**

```
/c/Users/avino/tools/godot47/godot47.exe --headless --import
```
Expected: clean exit, no GDScript parse errors.

---

## Task 4: Update test files

**Files:**
- Modify: `test/test_hud_visual.gd`
- Modify: `test/test_hud_theme.gd`
- `test/test_hud.gd` — no changes needed (BossBar paths are preserved).

**Interfaces:**
- Consumes: new node paths from Task 2.

### 4a: `test/test_hud_visual.gd`

Changes: repoint 4 node paths (HP/XP bars), add 3 new structure assertions.

- [ ] **Step 1: Write updated `test/test_hud_visual.gd`**

```gdscript
extends GutTest
## Visual / style regression tests for HUD (Command Bar remake).
## Asserts styled ProgressBars, the EVOLVE banner, and the new command-bar structure.

func test_hud_process_mode_is_always() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"HUD root process_mode must be PROCESS_MODE_ALWAYS")

func test_hp_bar_has_fill_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var hp_bar: ProgressBar = hud.get_node("CommandBar/CBContent/HPZone/HPBarContainer/HPBar")
	assert_true(hp_bar.has_theme_stylebox_override("fill"),
		"HPBar must have a custom fill StyleBox (danger-orange) set via theme_override_styles/fill")

func test_xp_bar_has_fill_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var xp_bar: ProgressBar = hud.get_node("TopStrip/StripVBox/XPBar")
	assert_true(xp_bar.has_theme_stylebox_override("fill"),
		"XPBar must have a custom fill StyleBox (cyan) set via theme_override_styles/fill")

func test_hp_bar_has_background_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var hp_bar: ProgressBar = hud.get_node("CommandBar/CBContent/HPZone/HPBarContainer/HPBar")
	assert_true(hp_bar.has_theme_stylebox_override("background"),
		"HPBar must have a dark background StyleBox for contrast")

func test_xp_bar_has_background_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var xp_bar: ProgressBar = hud.get_node("TopStrip/StripVBox/XPBar")
	assert_true(xp_bar.has_theme_stylebox_override("background"),
		"XPBar must have a dark background StyleBox so bar is visible when near-empty")

func test_evolve_banner_starts_hidden() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var banner: Label = hud.get_node("EvolveBanner")
	assert_false(banner.visible, "EVOLVE banner must start hidden")

func test_evolve_banner_shown_on_evolution_unlocked() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var banner: Label = hud.get_node("EvolveBanner")
	assert_false(banner.visible, "EVOLVE banner should start hidden")
	GameEvents.evolution_unlocked.emit(&"test_weapon")
	assert_true(banner.visible,
		"EVOLVE banner must be visible immediately after evolution_unlocked is emitted")

func test_top_strip_exists() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_not_null(hud.get_node_or_null("TopStrip"),
		"TopStrip must exist as the full-width top status strip")

func test_command_bar_exists() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_not_null(hud.get_node_or_null("CommandBar"),
		"CommandBar must exist as the bottom command bar panel")

func test_ultimate_slot_present() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_not_null(hud.get_node_or_null("CommandBar/CBContent/RightZone/UltSlot"),
		"UltSlot must exist inside CommandBar RightZone")
```

### 4b: `test/test_hud_theme.gd`

Changes: update `test_hud_vbox_theme_is_set` to check `TopStrip` instead of `VBox`; update the file-level comment.

- [ ] **Step 2: Write updated `test/test_hud_theme.gd`**

```gdscript
extends GutTest
## Phase 6.1 — Dark sci-fi HUD theme (updated for command-bar remake).
## Verifies the theme asset exists and is wired into the HUD and upgrade-card scenes.
##
## NOTE: hud.tscn and upgrade_ui.tscn both root to CanvasLayer (not Control),
## so the theme is applied to their first Control child:
##   hud.tscn       → TopStrip (PanelContainer)
##   upgrade_ui.tscn → Panel (PanelContainer)

func test_theme_resource_is_theme() -> void:
	var theme = load("res://ui/theme/swarm_hud_theme.tres")
	assert_not_null(theme, "swarm_hud_theme.tres must exist")
	assert_true(theme is Theme, "loaded resource must be a Theme")

func test_hud_top_strip_theme_is_set() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var top_strip: Control = hud.get_node("TopStrip") as Control
	assert_not_null(top_strip, "TopStrip must exist in hud.tscn")
	assert_not_null(top_strip.theme, "TopStrip.theme must not be null (theme applied in hud.tscn)")

func test_upgrade_ui_panel_theme_is_set() -> void:
	var ui: Node = add_child_autofree(load("res://upgrades/upgrade_ui.tscn").instantiate())
	var panel: Control = ui.get_node("Panel") as Control
	assert_not_null(panel, "Panel must exist in upgrade_ui.tscn")
	assert_not_null(panel.theme, "Panel.theme must not be null (theme applied in upgrade_ui.tscn)")

func test_boss_bar_panel_has_theme() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var boss_bar: Control = hud.get_node("BossBar") as Control
	assert_not_null(boss_bar, "BossBar node must exist")
	assert_true(boss_bar is PanelContainer,
		"BossBar must now be a PanelContainer for dark-panel background")
	assert_not_null(boss_bar.theme,
		"BossBar.theme must not be null (themed in hud.tscn for dark sci-fi consistency)")

func test_evolve_banner_has_gold_font_color() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var banner: Label = hud.get_node("EvolveBanner") as Label
	assert_not_null(banner, "EvolveBanner must exist")
	assert_true(banner.has_theme_color_override("font_color"),
		"EvolveBanner must have a font_color override (gold neon callout)")
	var gold := Color(1.0, 0.8, 0.2, 1.0)
	assert_eq(banner.get_theme_color("font_color"), gold,
		"EvolveBanner font_color must be palette player_secondary gold")

func test_evolve_banner_has_cyan_outline() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var banner: Label = hud.get_node("EvolveBanner") as Label
	assert_true(banner.has_theme_constant_override("outline_size"),
		"EvolveBanner must have an outline_size override for neon glow effect")
	assert_true(banner.get_theme_constant("outline_size") > 0,
		"EvolveBanner outline_size must be positive")

func test_upgrade_card_hover_changes_stylebox() -> void:
	var ui: Node = add_child_autofree(load("res://upgrades/upgrade_ui.tscn").instantiate())
	var card0: Control = ui.get_node("Panel/PanelVBox/CardRow/Card0") as Control
	assert_not_null(card0, "Card0 must exist")
	assert_true(card0.has_theme_stylebox_override("panel"),
		"Card0 must have a panel override after _ready (normal state)")
	var style_before: StyleBox = card0.get_theme_stylebox("panel")
	(ui as UpgradeUI)._on_card_hover(0, true)
	var style_after: StyleBox = card0.get_theme_stylebox("panel")
	assert_not_null(style_after, "Card0 must still have a panel override after hover")
	assert_true(style_after != style_before,
		"Card0 panel stylebox must change on hover (different StyleBox object)")
```

---

## Task 5: Run test suite and verify

- [ ] **Step 1: Run headless import to register all changes**

```
/c/Users/avino/tools/godot47/godot47.exe --headless --import
```

- [ ] **Step 2: Run focused HUD tests**

```
/c/Users/avino/tools/godot47/godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gselect=test_hud.gd -gexit
/c/Users/avino/tools/godot47/godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gselect=test_hud_visual.gd -gexit
/c/Users/avino/tools/godot47/godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gselect=test_hud_theme.gd -gexit
```
Expected: all three file runs show 0 failures.

- [ ] **Step 3: Run full suite**

```
/c/Users/avino/tools/godot47/godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```
Expected: ≥1063 passing, 0 failures. (Count increases by 3 due to the new structure assertions.)

---

## Task 6: Write report and commit

- [ ] **Step 1: Write `.superpowers/sdd/hud-remake-report.md`** (see spec for required sections)

- [ ] **Step 2: Stage and commit**

```bash
git add ui/hud.tscn ui/hud.gd ui/hud_icon.gd test/test_hud.gd test/test_hud_visual.gd test/test_hud_theme.gd .superpowers/sdd/hud-remake-report.md
git commit -m "$(cat <<'EOF'
feat(visual): full HUD remake — command-bar layout (status strip, HP, cooldowns, ultimate)

Replaces the old VBox labels/bars with a full-screen two-zone command bar:
- TopStrip (anchored top, full width): timer+clock icon, kills+skull icon, LV badge, XP bar
- CommandBar (anchored bottom ~90% width): passives left, HP centerpiece, weapons+ultimate right
- BossBar and EvolveBanner nodes/paths preserved (test_hud.gd unchanged)
- All GameEvents signal handlers and collect_cooldowns/collect_passives helpers unchanged
- New HUDIcon (hud_icon.gd): 5 drawn icons via _draw() — clock, skull, heart, chevron, star-burst
- Weapon slots gain TextureRect placeholder + IDLabel fallback + styled neon border
- test_hud_visual.gd: 4 paths repointed + 3 new structure assertions (1066 total)
- test_hud_theme.gd: VBox→TopStrip repoint; test count unchanged

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage check:**
- ✅ Top status strip (timer+clock, kills+skull, level badge, full-width XP bar)
- ✅ Bottom command bar (PanelContainer, ~90% width, dark sci-fi panel + neon edge)
- ✅ Passives zone (left, framed slots, id abbrev + xN level)
- ✅ HP bar (center, heart icon, cur/max overlaid, danger fill, dark track, rounded+neon edge)
- ✅ Weapon cooldown slots (framed, fraction bar, TextureRect placeholder, id fallback, READY label)
- ✅ Ultimate slot (larger, RadialCooldown sweep, gold border, SPACE label)
- ✅ Boss bar (unchanged structure, same tests pass)
- ✅ Evolve banner (unchanged, same fade-tween)
- ✅ Icons (clock, skull, heart, chevron, star-burst via _draw)
- ✅ Colors from VisualPalette (danger orange HP, cyan XP/weapons, gold ult border, magenta boss fill)
- ✅ process_mode = ALWAYS preserved
- ✅ All signal connections preserved
- ✅ _find_siblings logic unchanged
- ✅ collect_cooldowns / collect_passives signatures unchanged
- ✅ RadialCooldown reused
- ✅ swarm_hud_theme.tres reused (theme set on TopStrip, CommandBar, BossBar)
- ✅ Tests repointed (not deleted), 3 new assertions added
- ✅ Proper anchors (top-full for strip, bottom-anchored for command bar)
- ✅ Commit message + Co-Authored-By
- ✅ Report path: `.superpowers/sdd/hud-remake-report.md`

**Placeholder scan:** None found.

**Type consistency:**
- `_ult_radial: RadialCooldown` — RadialCooldown extends Control; node in scene is `type="Control"` with RadialCooldown script. @onready assignment valid.
- `_passives_box: HBoxContainer`, `_weapons_box: HBoxContainer` — both are `type="HBoxContainer"` in scene. Valid.
- `collect_cooldowns` / `collect_passives` return `Array` with Dict entries — unchanged.
