# See docs/notes/hud.md
class_name HUD extends CanvasLayer
## In-run heads-up display: timer, HP bar, XP bar + level, kill counter.
## process_mode = PROCESS_MODE_ALWAYS so _process runs BOTH during normal play
## (live timer/kills/XP) and while the level-up overlay pauses the tree.

@onready var _timer_label:   Label       = $VBox/TimerLabel
@onready var _kills_label:   Label       = $VBox/KillsLabel
@onready var _level_label:   Label       = $VBox/LevelLabel
@onready var _hp_bar:        ProgressBar = $VBox/HPBar
@onready var _xp_bar:        ProgressBar = $VBox/XPBar
@onready var _evolve_banner: Label       = $EvolveBanner
@onready var _boss_bar:      Control     = $BossBar
@onready var _boss_name:     Label       = $BossBar/BossNameLabel
@onready var _boss_hp_bar:   ProgressBar = $BossBar/BossHPBar
@onready var _boss_hp_text:  Label       = $BossBar/BossHPBar/BossHPText

var _game_manager: Node = null  # duck-typed: GameManager (2D) or GameManager3D
var _player: Node = null        # duck-typed: Player (2D) or Player3D
var _evolve_tween: Tween = null

# --- Three-zone cooldown HUD (created in _ready; no @onready so tests can load without scene) ---
# Left zone: passives (HBoxContainer, PRESET_BOTTOM_LEFT)
var _passives_box: HBoxContainer = null
var _passive_panels: Array = []
var _passive_last_count: int = 0
# Center zone: ultimate radial (RadialCooldown, anchored bottom-center)
var _ult_radial: RadialCooldown = null
# Right zone: weapon cooldown bars (HBoxContainer, PRESET_BOTTOM_RIGHT)
var _weapons_box: HBoxContainer = null
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

	# Left zone: passives.
	_passives_box = HBoxContainer.new()
	_passives_box.name = "PassivesBox"
	_passives_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_passives_box.offset_bottom = -8.0
	_passives_box.offset_top   = -56.0
	_passives_box.offset_left  = 8.0
	_passives_box.offset_right = 300.0
	_passives_box.add_theme_constant_override("separation", 4)
	add_child(_passives_box)

	# Center zone: radial ultimate indicator.
	_ult_radial = RadialCooldown.new()
	_ult_radial.name = "UltRadial"
	_ult_radial.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ult_radial.custom_minimum_size = Vector2(64, 64)
	_ult_radial.offset_left  = -32.0
	_ult_radial.offset_right =  32.0
	_ult_radial.offset_top   = -72.0
	_ult_radial.offset_bottom = -8.0
	_ult_radial.visible = false
	add_child(_ult_radial)

	# Right zone: weapon cooldown bars.
	_weapons_box = HBoxContainer.new()
	_weapons_box.name = "WeaponsBox"
	_weapons_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapons_box.offset_bottom = -8.0
	_weapons_box.offset_top   = -72.0
	_weapons_box.offset_left  = -300.0
	_weapons_box.offset_right = -8.0
	_weapons_box.add_theme_constant_override("separation", 6)
	add_child(_weapons_box)

	# Defer finding siblings so the full scene tree is ready
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
			_kills_label.text = "Kills: %d" % _game_manager.get_kills()
	if _player and is_instance_valid(_player):
		if _player.has_method("xp_to_next") and "level" in _player:
			_xp_bar.max_value = _player.xp_to_next(_player.get("level"))
		if "xp" in _player:
			_xp_bar.value = _player.get("xp")
	_update_cooldown_bars()

func _on_hp_changed(current: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value     = current

func _on_leveled_up(level: int) -> void:
	_level_label.text = "Lv %d" % level

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

	# --- Right zone: weapon bars ---
	if weapon_entries.size() != _cd_last_count:
		for child in _weapons_box.get_children():
			child.queue_free()
		_cd_bars.clear()
		for i in weapon_entries.size():
			var panel := Panel.new()
			panel.custom_minimum_size = Vector2(40, 40)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
			style.set_corner_radius_all(4)
			panel.add_theme_stylebox_override("panel", style)
			var bar := ProgressBar.new()
			bar.name = "Bar"
			bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bar.max_value = 1.0
			bar.value = weapon_entries[i]["fraction"]
			bar.show_percentage = false
			var bg_style := StyleBoxFlat.new()
			bg_style.bg_color = Color(0.08, 0.08, 0.08, 0.0)
			bar.add_theme_stylebox_override("background", bg_style)
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = Color(0.2, 0.7, 1.0, 0.85)  # cyan for weapons
			bar.add_theme_stylebox_override("fill", fill_style)
			panel.add_child(bar)
			var lbl := Label.new()
			lbl.name = "ReadyLabel"
			lbl.text = "RDY"
			lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.visible = false
			panel.add_child(lbl)
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

	# --- Center zone: ultimate radial ---
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
				panel.custom_minimum_size = Vector2(36, 36)
				var style := StyleBoxFlat.new()
				style.bg_color = Color(0.1, 0.08, 0.15, 0.85)
				style.set_corner_radius_all(4)
				panel.add_theme_stylebox_override("panel", style)
				var lbl := Label.new()
				lbl.text = str(e["id"]).substr(0, 3).to_upper()
				lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", 8)
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				panel.add_child(lbl)
				var lvl_lbl := Label.new()
				lvl_lbl.name = "LevelLabel"
				lvl_lbl.text = "x%d" % e["level"]
				lvl_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				lvl_lbl.offset_top    = -14.0
				lvl_lbl.offset_bottom =  0.0
				lvl_lbl.offset_left   = -20.0
				lvl_lbl.offset_right  =  0.0
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
