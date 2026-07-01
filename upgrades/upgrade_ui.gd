# See docs/notes/upgrade-ui.md
class_name UpgradeUI extends CanvasLayer
## Level-up overlay: shows up to 3 upgrade choice CARDS side-by-side.
## EVOLUTION and SYNERGY cards get golden styling and an "EVOLVE"/"SYNERGY" level badge.
## Accepts both UpgradeSystem (2D) and SkillSystem (3D) via duck-typing — both expose
## build_choices(rng, count), levels, and is_maxed(u).
## process_mode = PROCESS_MODE_WHEN_PAUSED so cards respond while the tree is paused.

signal chosen(upgrade: Upgrade)

const EVOLUTION_MODULATE := Color(1.0, 0.85, 0.1, 1.0)  # golden
const NORMAL_MODULATE    := Color(1.0, 1.0, 1.0, 1.0)

## Placeholder badge colours per upgrade kind (real icons pending art direction).
const KIND_COLOURS: Dictionary = {
	Upgrade.Kind.SIGNATURE: Color(0.75, 0.2,  0.2,  1.0),  # red
	Upgrade.Kind.PASSIVE:   Color(0.2,  0.45, 0.8,  1.0),  # blue
	Upgrade.Kind.GENERIC:   Color(0.3,  0.55, 0.3,  1.0),  # green
	Upgrade.Kind.EVOLUTION: Color(1.0,  0.85, 0.1,  1.0),  # gold
	Upgrade.Kind.SKILL:     Color(0.8,  0.3,  0.1,  1.0),  # orange-red
	Upgrade.Kind.SYNERGY:   Color(1.0,  0.85, 0.1,  1.0),  # gold
}

## Active system — untyped to accept both UpgradeSystem and SkillSystem.
var _system = null
var _choices: Array = []

## Card hover/focus StyleBoxes — normal matches theme default; hover brightens border.
var _style_card_normal: StyleBoxFlat = null
var _style_card_hover:  StyleBoxFlat = null

@onready var _panel: Control = $Panel

@onready var _cards: Array = [
	$Panel/PanelVBox/CardRow/Card0,
	$Panel/PanelVBox/CardRow/Card1,
	$Panel/PanelVBox/CardRow/Card2,
]
@onready var _name_labels: Array = [
	$Panel/PanelVBox/CardRow/Card0/CardContent/NameLabel,
	$Panel/PanelVBox/CardRow/Card1/CardContent/NameLabel,
	$Panel/PanelVBox/CardRow/Card2/CardContent/NameLabel,
]
@onready var _icon_rects: Array = [
	$Panel/PanelVBox/CardRow/Card0/CardContent/IconRect,
	$Panel/PanelVBox/CardRow/Card1/CardContent/IconRect,
	$Panel/PanelVBox/CardRow/Card2/CardContent/IconRect,
]
@onready var _desc_labels: Array = [
	$Panel/PanelVBox/CardRow/Card0/CardContent/DescLabel,
	$Panel/PanelVBox/CardRow/Card1/CardContent/DescLabel,
	$Panel/PanelVBox/CardRow/Card2/CardContent/DescLabel,
]
@onready var _stat_labels: Array = [
	$Panel/PanelVBox/CardRow/Card0/CardContent/StatLabel,
	$Panel/PanelVBox/CardRow/Card1/CardContent/StatLabel,
	$Panel/PanelVBox/CardRow/Card2/CardContent/StatLabel,
]
@onready var _level_labels: Array = [
	$Panel/PanelVBox/CardRow/Card0/CardContent/LevelLabel,
	$Panel/PanelVBox/CardRow/Card1/CardContent/LevelLabel,
	$Panel/PanelVBox/CardRow/Card2/CardContent/LevelLabel,
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_panel.visible = false

	# Normal card style — matches the theme's PanelContainer panel StyleBox.
	_style_card_normal = StyleBoxFlat.new()
	_style_card_normal.bg_color = Color(0.05, 0.06, 0.10, 0.85)
	_style_card_normal.border_width_left   = 1
	_style_card_normal.border_width_top    = 1
	_style_card_normal.border_width_right  = 1
	_style_card_normal.border_width_bottom = 1
	_style_card_normal.border_color = Color(0.3, 0.8, 1.0, 0.6)
	_style_card_normal.set_corner_radius_all(4)
	_style_card_normal.content_margin_left   = 8.0
	_style_card_normal.content_margin_top    = 8.0
	_style_card_normal.content_margin_right  = 8.0
	_style_card_normal.content_margin_bottom = 8.0

	# Hover card style — brighter bg, full-opacity cyan 2px border.
	_style_card_hover = StyleBoxFlat.new()
	_style_card_hover.bg_color = Color(0.08, 0.14, 0.22, 0.95)
	_style_card_hover.border_width_left   = 2
	_style_card_hover.border_width_top    = 2
	_style_card_hover.border_width_right  = 2
	_style_card_hover.border_width_bottom = 2
	_style_card_hover.border_color = Color(0.3, 0.8, 1.0, 1.0)
	_style_card_hover.set_corner_radius_all(4)
	_style_card_hover.content_margin_left   = 8.0
	_style_card_hover.content_margin_top    = 8.0
	_style_card_hover.content_margin_right  = 8.0
	_style_card_hover.content_margin_bottom = 8.0

	for i in _cards.size():
		var idx := i  # capture for lambda
		var card := _cards[i] as Control
		card.gui_input.connect(func(event: InputEvent) -> void: _on_card_input(event, idx))
		card.mouse_entered.connect(func(): _on_card_hover(idx, true))
		card.mouse_exited.connect( func(): _on_card_hover(idx, false))
		card.focus_mode = Control.FOCUS_ALL
		card.focus_entered.connect(func(): _on_card_hover(idx, true))
		card.focus_exited.connect( func(): _on_card_hover(idx, false))
		card.add_theme_stylebox_override("panel", _style_card_normal)


## Called by GameManager when the player levels up.
## Accepts both UpgradeSystem (2D) and SkillSystem (3D) — both expose
## build_choices(rng, count), levels, and is_maxed(u).
func present(system, _player) -> void:
	_system = system
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_choices = system.build_choices(rng, 3)

	for i in _cards.size():
		_on_card_hover(i, false)  # reset any lingering hover state from last presentation

	for i in _cards.size():
		var card: Control = _cards[i]
		if i < _choices.size():
			var u: Upgrade = _choices[i]
			var is_evo    := (u.kind == Upgrade.Kind.EVOLUTION)
			var is_synergy := (u.kind == Upgrade.Kind.SYNERGY)
			var is_golden := is_evo or is_synergy
			card.visible = true
			card.modulate = EVOLUTION_MODULATE if is_golden else NORMAL_MODULATE

			(_name_labels[i] as Label).text = u.display_name

			# Placeholder coloured badge — swap for TextureRect when real icons land.
			(_icon_rects[i] as ColorRect).color = KIND_COLOURS.get(u.kind, Color.WHITE)

			(_desc_labels[i] as Label).text = u.description
			(_stat_labels[i] as Label).text = u.stat_text

			var cur_level: int = system.levels.get(u.id, 0)
			var lbl: Label = _level_labels[i]
			if is_evo:
				lbl.text = "EVOLVE"
			elif is_synergy:
				lbl.text = "SYNERGY"
			elif cur_level == 0:
				lbl.text = "NEW"
			else:
				lbl.text = "Lv %d / %d" % [cur_level, u.max_level]
		else:
			card.visible = false

	_panel.visible = true


func _on_card_hover(index: int, hovered: bool) -> void:
	if index >= _cards.size():
		return
	var card := _cards[index] as Control
	card.add_theme_stylebox_override("panel",
		_style_card_hover if hovered else _style_card_normal)


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_pick(index)
	elif event is InputEventKey \
			and event.pressed \
			and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		_pick(index)


func _pick(index: int) -> void:
	if index >= _choices.size():
		return
	_panel.visible = false
	chosen.emit(_choices[index])
