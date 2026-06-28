# See docs/notes/upgrade-system.md
class_name Upgrade extends Resource

## Enum of upgrade categories.
enum Kind { SIGNATURE, PASSIVE, GENERIC, EVOLUTION }

@export var id: StringName
@export var display_name: String = ""
@export var kind: int = Kind.GENERIC  ## One of Kind.*
@export var max_level: int = 5
