# See docs/notes/upgrade-ui.md
class_name UpgradeUI extends CanvasLayer
## Level-up card picker: up to 3 premium "tech cards" dealt over a dark scrim on the paused
## arena. Each card (a UpgradeCard, which draws its own chamfered single-line neon frame)
## shows, top→bottom: level badge ("NEW" / "Lv cur / max") · fixed-ratio rounded icon plate ·
## name · (gap) · description · stat. Accent hue per kind: teal = weapon/skill, purple =
## passive/stat, gold = evolution/synergy (featured = stronger glow, SAME size — cards enlarge
## only on hover). A PASSIVE card that advances an owned skill toward its synergy shows a
## bottom-straddling tab: two tight "^" over the skill icon in a bordered pill.
## Accepts both UpgradeSystem (2D) and SkillSystem (3D) via duck-typing. Synergy tabs are
## SkillSystem-only (guarded by has_method), so the 2D system shows none.
## process_mode = PROCESS_MODE_WHEN_PAUSED so cards respond while the tree is paused.

signal chosen(upgrade: Upgrade)

## Card accent colours per upgrade kind.
const ACCENT_TEAL   := Color(0.20, 0.95, 0.75, 1.0)  # weapons / skills
const ACCENT_PURPLE := Color(0.70, 0.45, 1.00, 1.0)  # passives / stat upgrades
const ACCENT_GOLD   := Color(1.00, 0.82, 0.20, 1.0)  # evolution / synergy

## Cards are all the same size; only the hovered card enlarges.
const HOVER_SCALE := 1.06
## Corner radius of the card image mask, in short-side (plate height) units.
const ICON_RADIUS := 0.12
## Corner radius for the tiny synergy-tab icon. Larger fraction than the card image so the
## small icon reads as equally rounded (the same fraction on ~28px looks nearly square).
const TAB_ICON_RADIUS := 0.24

const _ROUNDED_SHADER := preload("res://upgrades/rounded_icon.gdshader")

var _system = null
var _choices: Array = []
var _card_accents: Array = []

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
	$Panel/PanelVBox/CardRow/Card0/CardContent/IconPlate/IconRect,
	$Panel/PanelVBox/CardRow/Card1/CardContent/IconPlate/IconRect,
	$Panel/PanelVBox/CardRow/Card2/CardContent/IconPlate/IconRect,
]
@onready var _icon_plates: Array = [
	$Panel/PanelVBox/CardRow/Card0/CardContent/IconPlate,
	$Panel/PanelVBox/CardRow/Card1/CardContent/IconPlate,
	$Panel/PanelVBox/CardRow/Card2/CardContent/IconPlate,
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
@onready var _synergy_tabs: Array = [
	$Panel/PanelVBox/CardRow/Card0/SynergyTab,
	$Panel/PanelVBox/CardRow/Card1/SynergyTab,
	$Panel/PanelVBox/CardRow/Card2/SynergyTab,
]
@onready var _synergy_icons: Array = [
	$Panel/PanelVBox/CardRow/Card0/SynergyTab/TabBox/SkillIcon,
	$Panel/PanelVBox/CardRow/Card1/SynergyTab/TabBox/SkillIcon,
	$Panel/PanelVBox/CardRow/Card2/SynergyTab/TabBox/SkillIcon,
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_panel.visible = false
	_card_accents.resize(_cards.size())
	var tab_style := _make_tab_style()
	for i in _cards.size():
		var idx := i  # capture for lambda
		var card := _cards[i] as Control
		card.gui_input.connect(func(event: InputEvent) -> void: _on_card_input(event, idx))
		card.mouse_entered.connect(func(): _on_card_hover(idx, true))
		card.mouse_exited.connect( func(): _on_card_hover(idx, false))
		card.focus_mode = Control.FOCUS_ALL
		card.focus_entered.connect(func(): _on_card_hover(idx, true))
		card.focus_exited.connect( func(): _on_card_hover(idx, false))
		# Rounded-corner mask on the icon image (matches the plate/frame radius).
		var mat := ShaderMaterial.new()
		mat.shader = _ROUNDED_SHADER
		mat.set_shader_parameter("radius", ICON_RADIUS)
		var ir := _icon_rects[i] as TextureRect
		ir.material = mat
		# Keep the shader `aspect` in sync with the rect's real size. This fires when the
		# panel is first shown and the container lays the icon out — without it, the aspect
		# stays at its pre-layout value on the FIRST level-up (corners/ratio look wrong) and
		# only corrected once a hover re-ran _apply_card_visual. resized() makes it correct
		# from the first frame it is sized, no hover required.
		ir.resized.connect(_update_icon_aspect.bind(ir))
		# Rounded mask on the small synergy-tab skill icon (larger fraction — see const).
		var smat := ShaderMaterial.new()
		smat.shader = _ROUNDED_SHADER
		smat.set_shader_parameter("radius", TAB_ICON_RADIUS)
		var si := _synergy_icons[i] as TextureRect
		si.material = smat
		si.resized.connect(_update_icon_aspect.bind(si))
		(_synergy_tabs[i] as Panel).add_theme_stylebox_override("panel", tab_style)

## Set the rounded-icon shader's `aspect` uniform from a TextureRect's current size so the
## corner radius stays circular on non-square plates. Safe to call any time; no-op until sized.
func _update_icon_aspect(rect: TextureRect) -> void:
	if rect and rect.material is ShaderMaterial and rect.size.y > 0.0:
		(rect.material as ShaderMaterial).set_shader_parameter("aspect", rect.size.x / rect.size.y)

## The accent colour for an upgrade kind (drives frame, glow, badge, stat highlight).
func _accent_for(kind: int) -> Color:
	match kind:
		Upgrade.Kind.EVOLUTION, Upgrade.Kind.SYNERGY:
			return ACCENT_GOLD
		Upgrade.Kind.SKILL, Upgrade.Kind.SIGNATURE:
			return ACCENT_TEAL
		_:
			return ACCENT_PURPLE  # PASSIVE, GENERIC

## Rounded icon-plate StyleBox, tinted to the card's rarity hue with a thin light border.
func _make_plate_style(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.24, accent.g * 0.24, accent.b * 0.30, 1.0)
	sb.set_corner_radius_all(14)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	return sb

## Bordered dark pill for the bottom synergy tab (gold, matching the "^^" hint).
func _make_tab_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.05, 0.98)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = ACCENT_GOLD
	return sb

## Best icon for an upgrade: explicit Upgrade.icon, else convention art/icons/abilities/
## <skill_id or id>.png. Returns null when nothing is found.
func _icon_for(u: Upgrade):
	if u.icon != null:
		return u.icon
	var key := String(u.skill_id) if String(u.skill_id) != "" else String(u.id)
	return _load_convention("res://art/icons/abilities/%s.png" % key)

func _load_convention(path: String):
	if ResourceLoader.exists(path):
		return load(path)
	return null

## Called by GameManager when the player levels up.
func present(system, _player) -> void:
	_system = system
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_choices = system.build_choices(rng, 3)

	for i in _cards.size():
		var card: Control = _cards[i]
		if i >= _choices.size():
			card.visible = false
			continue
		var u: Upgrade = _choices[i]
		var is_evo    := (u.kind == Upgrade.Kind.EVOLUTION)
		var is_synergy := (u.kind == Upgrade.Kind.SYNERGY)
		var accent := _accent_for(u.kind)
		_card_accents[i] = accent

		card.visible = true
		(card as UpgradeCard).configure(accent, is_evo or is_synergy)
		(_icon_plates[i] as Panel).add_theme_stylebox_override("panel", _make_plate_style(accent))

		(_name_labels[i] as Label).text = u.display_name
		(_icon_rects[i] as TextureRect).texture = _icon_for(u)
		(_desc_labels[i] as Label).text = u.description

		var stat_lbl: Label = _stat_labels[i]
		stat_lbl.text = u.stat_text
		stat_lbl.add_theme_color_override("font_color", accent)

		# Level badge: NEW when unowned, else "Lv cur / max"; evolution/synergy get a word.
		var cur_level: int = system.levels.get(u.id, 0)
		var lbl: Label = _level_labels[i]
		lbl.add_theme_color_override("font_color", accent)
		if is_evo:
			lbl.text = "EVOLVE"
		elif is_synergy:
			lbl.text = "SYNERGY"
		elif cur_level == 0:
			lbl.text = "NEW"
		else:
			lbl.text = "Lv %d / %d" % [cur_level, u.max_level]

		_update_synergy_hint(i, u, system)
		call_deferred("_apply_card_visual", i, false)

	_panel.visible = true

## Show the bottom "^^ [skill icon]" tab when this PASSIVE card advances an owned skill toward
## its synergy. SkillSystem-only (guarded), so the 2D UpgradeSystem shows nothing.
func _update_synergy_hint(i: int, u: Upgrade, system) -> void:
	var tab: Panel = _synergy_tabs[i]
	tab.visible = false
	if u.kind != Upgrade.Kind.PASSIVE:
		return
	if not (system.has_method("skill_id_of") and system.has_method("skill_for") \
			and system.has_method("synergy_pending")):
		return
	var sid: StringName = system.skill_id_of(u)
	if String(sid) == "" or not system.synergy_pending(sid):
		return
	var skill = system.skill_for(sid)
	if skill == null:
		return
	var skill_icon = skill.icon
	if skill_icon == null:
		skill_icon = _load_convention("res://art/icons/abilities/%s.png" % String(sid))
	(_synergy_icons[i] as TextureRect).texture = skill_icon
	tab.visible = true

## Apply the card's hover scale (around its centre) + glow, and keep the icon mask aspect in
## sync with the plate's actual size (so the rounded corners stay circular).
func _apply_card_visual(index: int, hovered: bool) -> void:
	if index >= _cards.size():
		return
	var card := _cards[index] as Control
	if card == null or not card.visible:
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * (HOVER_SCALE if hovered else 1.0)
	if card is UpgradeCard:
		(card as UpgradeCard).set_hovered(hovered)
	var icon := _icon_rects[index] as TextureRect
	if icon and icon.material is ShaderMaterial and icon.size.y > 0.0:
		(icon.material as ShaderMaterial).set_shader_parameter("aspect", icon.size.x / icon.size.y)
	var sicon := _synergy_icons[index] as TextureRect
	if sicon and sicon.material is ShaderMaterial and sicon.size.y > 0.0:
		(sicon.material as ShaderMaterial).set_shader_parameter("aspect", sicon.size.x / sicon.size.y)

func _on_card_hover(index: int, hovered: bool) -> void:
	if index >= _cards.size() or index >= _card_accents.size():
		return
	if _card_accents[index] == null:
		return
	_apply_card_visual(index, hovered)

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
