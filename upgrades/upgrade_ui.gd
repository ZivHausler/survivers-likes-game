# See docs/notes/upgrade-ui.md
class_name UpgradeUI extends CanvasLayer
## Level-up overlay: shows 3 upgrade choices; golden style when EVOLUTION is offered.
## process_mode is set to PROCESS_MODE_WHEN_PAUSED so it responds while the tree is paused.

signal chosen(upgrade: Upgrade)

const EVOLUTION_MODULATE := Color(1.0, 0.85, 0.1, 1.0)  # golden
const NORMAL_MODULATE    := Color(1.0, 1.0, 1.0, 1.0)

var _system: UpgradeSystem = null
var _choices: Array = []

@onready var _panel: Control   = $Panel
@onready var _btn0:  Button    = $Panel/VBox/Button0
@onready var _btn1:  Button    = $Panel/VBox/Button1
@onready var _btn2:  Button    = $Panel/VBox/Button2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_panel.visible = false
	_btn0.pressed.connect(func(): _pick(0))
	_btn1.pressed.connect(func(): _pick(1))
	_btn2.pressed.connect(func(): _pick(2))

## Called by GameManager when the player levels up.
## Builds choices from the UpgradeSystem and shows the panel.
func present(system: UpgradeSystem, _player: Player) -> void:
	_system = system
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_choices = system.build_choices(rng, 3)

	var btns := [_btn0, _btn1, _btn2]
	for i in btns.size():
		var btn: Button = btns[i]
		if i < _choices.size():
			var u: Upgrade = _choices[i]
			btn.text = u.display_name
			btn.visible = true
			var is_evo := (u.kind == Upgrade.Kind.EVOLUTION)
			btn.modulate = EVOLUTION_MODULATE if is_evo else NORMAL_MODULATE
		else:
			btn.visible = false

	_panel.visible = true

func _pick(index: int) -> void:
	if index >= _choices.size():
		return
	_panel.visible = false
	chosen.emit(_choices[index])
