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
## 3-D model fields — additive; defaults so existing 2-D .tres files keep working.
@export var model_scene: PackedScene     ## Kenney GLB to instance (null = keep capsule placeholder)
@export var model_scale: float = 1.0    ## Uniform scale applied to the Model Node3D
@export var model_tint: Color = Color.WHITE  ## Optional albedo tint to differentiate friends sharing a base model
