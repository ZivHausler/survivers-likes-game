# See docs/notes/skill-system.md
class_name SkillData extends Resource

## Bundles one skill: its identity, weapon, and the three upgrade cards
## (SKILL acquire/level, PASSIVE, SYNERGY) that belong to it.

## Unique identifier for this skill; must match skill_id on each bundled Upgrade.
@export var id: StringName
@export var display_name: String = ""
## The Weapon3D scene to instantiate when this skill is first acquired (level 0→1).
## Instantiation is the GameManager's responsibility (Task 3.2), NOT SkillSystem's.
@export var weapon_scene: PackedScene
## If true, this skill starts at level 1 (owned) when SkillSystem is initialised.
## Exactly one skill per character should be marked is_signature.
@export var is_signature: bool = false
## The acquire / level-up card for this skill. Kind must be SKILL, max_level = 5.
@export var skill_upgrade: Upgrade
## The passive card. Kind must be PASSIVE, max_level = 5.
## Only offered once the skill is owned (level ≥ 1).
@export var passive_upgrade: Upgrade
## The synergy (golden) card. Kind must be SYNERGY, max_level = 1.
## Only offered once skill_level == 5 AND passive_level ≥ 1 AND not yet synergized.
@export var synergy_upgrade: Upgrade
@export var description: String = ""
@export var icon: Texture2D
## Weapon type for pool filtering. &"natural" = offered to every character;
## otherwise one themed type id (&"charm", &"holy", …). Ultimates carry their
## owner's primary type for tagging consistency.
@export var type: StringName = &"natural"
