# See docs/notes/hud.md
class_name HUD extends CanvasLayer
## In-run heads-up display. Binds ONLY existing game data:
##   Top    — timer / kills / level / enemy-count + XP bar
##   Boss   — boss name + HP bar (hidden until a boss spawns)
##   Command— HP bar, portrait, weapon cooldown icons, ultimate radial, passives
##   Minimap / Settings / Evolve banner / UltReady popup
## process_mode = PROCESS_MODE_ALWAYS so _process runs during normal play AND
## while the level-up overlay pauses the tree (live timer/kills/XP).

@onready var _timer:         Label          = $Top/TopRow/Timer
@onready var _kills:         Label          = $Top/TopRow/Kills
@onready var _level:         Label          = $Top/TopRow/Level
@onready var _enemies:       Label          = $Top/TopRow/Enemies
@onready var _xp_bar:        ProgressBar    = $Top/XP
@onready var _boss:          Control        = $Boss
@onready var _boss_name:     Label          = $Boss/BossName
@onready var _boss_hp:       ProgressBar    = $Boss/BossHP
@onready var _boss_hp_text:  Label          = $Boss/BossHP/BossHPText
@onready var _hp_bar:        ProgressBar    = $Command/HP
@onready var _hp_text:       Label          = $Command/HP/HPText
@onready var _portrait_tex:  TextureRect    = $Command/Portrait
@onready var _weapons_box:   HBoxContainer  = $Command/Weapons
@onready var _ult_radial:    RadialCooldown = $Command/Ult
@onready var _passives_box:  HBoxContainer  = $Command/Passives
@onready var _evolve_banner: Label          = $Evolve
@onready var _ult_popup:     Label          = $UltReady
@onready var _minimap                       = $Minimap  # ui/minimap.gd (dynamic to avoid class-cache dep)

var _game_manager: Node = null  # duck-typed: GameManager (2D) or GameManager3D
var _player: Node = null        # duck-typed: Player (2D) or Player3D
var _icon_map: Dictionary = {}  # skill_id → Texture2D, built from the player's character_data
var _evolve_tween: Tween = null
var _ult_popup_tween: Tween = null
var _ult_was_ready: bool = false
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
	# Defer finding siblings so the full scene tree is ready.
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
	if _minimap != null and _minimap.has_method("set_player"):
		_minimap.set_player(_player)
	_build_icon_map()

## Build skill_id → ability-icon lookup from the player's character_data (skills +
## ultimate) and set the command portrait. Duck-typed so a 2D/stub player without
## character_data simply yields no icons (slots fall back to their text abbreviation).
func _build_icon_map() -> void:
	_icon_map.clear()
	if _player == null or not is_instance_valid(_player):
		return
	var cd = _player.get("character_data")
	if cd == null:
		return
	var skills = cd.get("skills")
	if skills is Array:
		for sd in skills:
			if sd != null:
				_register_icon(sd)
	_register_icon(cd.get("ultimate"))
	# Command portrait: explicit field, else convention art/icons/portraits/<id>.png.
	var portrait = cd.get("portrait")
	if portrait == null:
		portrait = _load_convention("res://art/icons/portraits/%s.png" % cd.get("id"))
	if portrait != null and _portrait_tex != null:
		_portrait_tex.texture = portrait
		_portrait_tex.visible = true

## Map a SkillData's id to its icon: explicit SkillData.icon wins, else the
## convention path art/icons/abilities/<id>.png (so new icons need no .tres edits).
func _register_icon(sd) -> void:
	if sd == null:
		return
	var icon = sd.icon
	if icon == null:
		icon = _load_convention("res://art/icons/abilities/%s.png" % sd.id)
	if icon != null:
		_icon_map[sd.id] = icon

func _load_convention(path: String):
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _process(_dt: float) -> void:
	if _game_manager and is_instance_valid(_game_manager):
		if _game_manager.has_method("get_elapsed") and _timer != null:
			var secs := int(_game_manager.get_elapsed())
			_timer.text = "%d:%02d" % [int(secs / 60.0), secs % 60]
		if _game_manager.has_method("get_kills") and _kills != null:
			_kills.text = "%d" % _game_manager.get_kills()
	if _enemies != null:
		_enemies.text = "%d" % get_tree().get_nodes_in_group("enemies").size()
	if _player and is_instance_valid(_player) and _xp_bar != null:
		if _player.has_method("xp_to_next") and "level" in _player:
			_xp_bar.max_value = _player.xp_to_next(_player.get("level"))
		if "xp" in _player:
			_xp_bar.value = _player.get("xp")
	_update_cooldown_bars()

func _on_hp_changed(current: float, max_hp: float) -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = max_hp
	_hp_bar.value     = current
	if _hp_text != null:
		_hp_text.text = "%d / %d" % [int(max(current, 0.0)), int(max_hp)]

func _on_leveled_up(level: int) -> void:
	if _level != null:
		_level.text = "LV %d" % level

func _on_evolution_unlocked(_weapon_id: StringName) -> void:
	if _evolve_banner == null:
		return
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
	if _boss == null:
		return
	_boss_name.text = boss_name
	_boss_hp.max_value = max_hp
	_boss_hp.value = max_hp
	_boss_hp_text.text = "%d / %d" % [int(max_hp), int(max_hp)]
	_boss.visible = true

func _on_boss_hp_changed(current: float, max_hp: float) -> void:
	if _boss_hp == null:
		return
	_boss_hp.max_value = max_hp
	_boss_hp.value = current
	_boss_hp_text.text = "%d / %d" % [int(max(current, 0.0)), int(max_hp)]

func _on_boss_died() -> void:
	if _boss != null:
		_boss.visible = false

## Briefly show the "ULTIMATE READY" popup when the ultimate finishes cooling down.
func _flash_ult_ready() -> void:
	if _ult_popup == null:
		return
	if _ult_popup_tween and _ult_popup_tween.is_valid():
		_ult_popup_tween.kill()
	_ult_popup.visible = true
	_ult_popup.modulate = Color.WHITE
	_ult_popup_tween = create_tween()
	_ult_popup_tween.tween_property(_ult_popup, "modulate:a", 0.0, 1.8).set_delay(1.2)
	_ult_popup_tween.tween_callback(func(): _ult_popup.visible = false)

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

## Acquired passives for the HUD passives row. Pure (stub-friendly).
func collect_passives(player) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	var p = player.get("passives")
	if p is Dictionary:
		for id in p:
			out.append({ "id": id, "level": int(p[id]) })
	return out

## Sync the weapon/ultimate/passive HUD zones with the current player's skill states.
func _update_cooldown_bars() -> void:
	if _weapons_box == null:
		return
	var all_entries: Array = collect_cooldowns(_player)

	# Split into weapon entries and the ultimate entry.
	var weapon_entries: Array = []
	var ult_entry = null
	for e in all_entries:
		if e["is_ultimate"]:
			ult_entry = e
		else:
			weapon_entries.append(e)

	# --- Weapon slots: ability icon + cooldown fill ---
	if weapon_entries.size() != _cd_last_count:
		for child in _weapons_box.get_children():
			child.queue_free()
		_cd_bars.clear()
		for i in weapon_entries.size():
			var panel := Panel.new()
			panel.custom_minimum_size = Vector2(52, 52)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
			style.set_corner_radius_all(4)
			style.border_width_left   = 1
			style.border_width_top    = 1
			style.border_width_right  = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.3, 0.8, 1.0, 0.5)
			panel.add_theme_stylebox_override("panel", style)
			# Ability icon (from SkillData.icon via _icon_map); text label is the fallback.
			var icon_rect := TextureRect.new()
			icon_rect.name = "IconTexture"
			icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var slot_icon = _icon_map.get(weapon_entries[i]["id"], null)
			if slot_icon != null:
				icon_rect.texture = slot_icon
			panel.add_child(icon_rect)
			# Cooldown overlay bar (transparent bg, cyan fill).
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
			# ID abbreviation — fallback label when no texture is loaded.
			var id_lbl := Label.new()
			id_lbl.name = "IDLabel"
			id_lbl.text = str(weapon_entries[i]["id"]).substr(0, 4).to_upper()
			id_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			id_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			id_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			id_lbl.add_theme_font_size_override("font_size", 8)
			id_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			id_lbl.visible = slot_icon == null  # hide the abbreviation once a real icon loads
			panel.add_child(id_lbl)
			# Keybind badge (1..N) in the top-left corner.
			var key_lbl := Label.new()
			key_lbl.name = "KeyLabel"
			key_lbl.text = str(i + 1)
			key_lbl.position = Vector2(3, 0)
			key_lbl.add_theme_font_size_override("font_size", 11)
			key_lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
			key_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			key_lbl.add_theme_constant_override("outline_size", 3)
			key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(key_lbl)
			# READY glow label.
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

	# --- Ultimate radial: sweep + "ready" popup on the rising edge ---
	if _ult_radial != null:
		if ult_entry != null:
			_ult_radial.visible = true
			_ult_radial.set_fraction(ult_entry["fraction"])
			var ready: bool = ult_entry["fraction"] >= 1.0
			if ready and not _ult_was_ready:
				_flash_ult_ready()
			_ult_was_ready = ready
		else:
			_ult_radial.visible = false
			_ult_was_ready = false

	# --- Passive chips ---
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
		# Always refresh level labels in-place so a level-up (count unchanged) shows.
		for i in passive_entries.size():
			if i >= _passive_panels.size():
				break
			var lvl_lbl: Label = _passive_panels[i].get_node_or_null("LevelLabel")
			if lvl_lbl:
				lvl_lbl.text = "x%d" % passive_entries[i]["level"]
