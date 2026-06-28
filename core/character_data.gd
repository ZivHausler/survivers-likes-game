# See docs/notes/character-data.md
class_name CharacterData extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var color: Color = Color.WHITE          # placeholder art tint
@export var base_stats: StatBlock
@export var weapon_scene: PackedScene
@export var passive_id: StringName               # dedicated passive's id
@export var evolution_id: StringName             # evolved ability id
@export var max_signature_level: int = 5
## Upgrade resources — set in each character's .tres file.
@export var signature_upgrade: Upgrade
@export var passive_upgrade: Upgrade
@export var evolution_upgrade: Upgrade
@export var sprite_frames: SpriteFrames  ## Optional animated sprite; null → use color placeholder
