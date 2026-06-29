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

# Cooldown HUD — created in _ready so tests can instantiate the script without a scene tree.
var _cooldowns_box: HBoxContainer = null
# Maps skill index -> ProgressBar so we can update each frame.
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

	# Cooldown indicator container — bottom-left, above the VBox.
	_cooldowns_box = HBoxContainer.new()
	_cooldowns_box.name = "CooldownsBox"
	_cooldowns_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_cooldowns_box.offset_bottom = -8.0
	_cooldowns_box.offset_top   = -72.0
	_cooldowns_box.offset_left  = 8.0
	_cooldowns_box.offset_right = 400.0
	_cooldowns_box.add_theme_constant_override("separation", 6)
	add_child(_cooldowns_box)

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

## Sync the cooldown bar strip with the current player's skill states.
func _update_cooldown_bars() -> void:
	if _cooldowns_box == null:
		return
	var entries: Array = collect_cooldowns(_player)
	# Rebuild indicator nodes if count changed.
	if entries.size() != _cd_last_count:
		for child in _cooldowns_box.get_children():
			child.queue_free()
		_cd_bars.clear()
		for i in entries.size():
			var is_ult: bool = entries[i]["is_ultimate"]
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
			bar.value = entries[i]["fraction"]
			bar.show_percentage = false
			var bg_style := StyleBoxFlat.new()
			bg_style.bg_color = Color(0.08, 0.08, 0.08, 0.0)
			bar.add_theme_stylebox_override("background", bg_style)
			var fill_style := StyleBoxFlat.new()
			if is_ult:
				fill_style.bg_color = Color(0.9, 0.6, 0.0, 0.9)  # gold tint for ultimate
			else:
				fill_style.bg_color = Color(0.2, 0.7, 1.0, 0.85)  # cyan for regular skills
			bar.add_theme_stylebox_override("fill", fill_style)
			panel.add_child(bar)
			# "READY" label overlay when fraction >= 1.0
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
			_cooldowns_box.add_child(panel)
			_cd_bars.append(bar)
		_cd_last_count = entries.size()
	# Update bar values each frame.
	for i in entries.size():
		if i >= _cd_bars.size():
			break
		var frac: float = entries[i]["fraction"]
		_cd_bars[i].value = frac
		# Toggle READY label.
		var ready_lbl: Label = _cd_bars[i].get_parent().get_node_or_null("ReadyLabel")
		if ready_lbl:
			ready_lbl.visible = frac >= 1.0
