# See docs/notes/upgrade-system.md
class_name Upgrade extends Resource

## Enum of upgrade categories.
enum Kind { SIGNATURE, PASSIVE, GENERIC, EVOLUTION }

@export var id: StringName
@export var display_name: String = ""
@export var kind: int = Kind.GENERIC  ## One of Kind.*
@export var max_level: int = 5
## For GENERIC upgrades: which stat to mutate (e.g. &"move_speed", &"max_hp").
@export var effect_kind: StringName = &""
## Per-level value applied when this upgrade is chosen (stat delta, passive bonus, etc.).
@export var effect_value: float = 0.0
