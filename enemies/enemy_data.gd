# See docs/notes/enemy.md
class_name EnemyData extends Resource

@export var id: StringName
@export var color: Color = Color.WHITE
@export var max_hp: float = 10.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 4.0
@export var xp_value: int = 1
@export var is_ranged: bool = false

## Attack archetype. MELEE = chase + contact (default, legacy behavior).
## RANGED = kite + fire EnemyProjectile3D. DASHER = hold, telegraph, lunge.
enum AttackKind { MELEE = 0, RANGED = 1, DASHER = 2 }
@export var attack_kind: int = AttackKind.MELEE

# ── RANGED params (used when attack_kind == RANGED) ──────────────────────────
@export var attack_range: float = 12.0       ## world units; kite to this distance and fire
@export var attack_cooldown: float = 2.0      ## seconds between shots
@export var windup_time: float = 0.4          ## telegraph before a shot launches
@export var projectile_speed: float = 16.0    ## world units / s
@export var projectile_damage: float = 6.0

# ── DASHER params (used when attack_kind == DASHER) ──────────────────────────
@export var dash_trigger_range: float = 14.0  ## start a dash when within this
@export var dash_windup: float = 0.5          ## telegraph before the lunge
@export var dash_speed: float = 30.0          ## lunge speed (world units / s)
@export var dash_duration: float = 0.35       ## seconds the lunge lasts
@export var dash_cooldown: float = 2.5        ## seconds between dashes

@export var radius: float = 8.0
@export var texture: Texture2D  ## Optional sprite texture; null → use color circle placeholder

## 3D model scene (GLB PackedScene). Null → keep placeholder sphere in 3D.
## Set per-variant in the .tres; 2D enemy ignores this field.
@export var model_scene: PackedScene
## Uniform scale applied to the Model Node3D when model_scene is set.
## FBX→GLB conversions may need tuning per-monster (playtest-tunable).
@export var model_scale: float = 1.0
## Y position offset (local Model space) to seat model feet at y≈0.
## Positive lifts the mesh up; adjust until feet contact the arena floor.
@export var model_y_offset: float = 0.0
