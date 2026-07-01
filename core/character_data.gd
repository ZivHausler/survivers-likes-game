# See docs/notes/character-data.md
class_name CharacterData extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var color: Color = Color.WHITE          # placeholder art tint
@export var portrait: Texture2D                 # HUD command-bar portrait (null → letter placeholder)
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
@export var model_texture: Texture2D    ## Skin atlas applied to all MeshInstance3D surfaces; null = no texture override
@export var stylize_model: bool = false  ## Apply the cel/rim Stylize layer. Default OFF: existing models keep their native look; only NEW assets that want the neon overlay opt in by setting this true.
## 3-D skill roster — 4 SkillData entries for 3D characters; 2D characters leave empty.
## See docs/notes/skill-system.md for full model description.
@export var skills: Array[SkillData] = []
## 1–2 type ids this character can roll type-gated weapons from. Empty = natural only.
@export var types: Array[StringName] = []
## This character's exclusive ultimate — granted at run start into a dedicated
## manual SPACE slot (not the weapon upgrade pool). Activated by the player via
## SPACE; never offered as a level-up card, never upgraded. is_signature not required.
@export var ultimate: SkillData
