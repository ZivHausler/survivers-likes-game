# how-to-add-an-enemy

Step-by-step runbook for adding a new enemy variant.

---

## 1 — Author the EnemyData resource

Create `enemies/<variant>.tres`.  Template:

```
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]
[ext_resource type="Script" path="res://enemies/enemy_data.gd" id="1_enemy_data"]
[resource]
script = ExtResource("1_enemy_data")
id = &"<variant>"
color = Color(R, G, B, 1)
max_hp = 20.0
move_speed = 80.0
contact_damage = 6.0
xp_value = 2
is_ranged = false
radius = 10.0
```

Fields:

| Field | Description |
|-------|-------------|
| `id` | StringName; must match the key used in `Spawner._variants` |
| `color` | Tints `Enemy/Body` ColorRect (placeholder art) |
| `max_hp` | Starting hit points |
| `move_speed` | Pixels per second (chase) |
| `contact_damage` | Damage dealt to player on contact |
| `xp_value` | XP gem value on death |
| `is_ranged` | If true, enemy stops at ~140 px and holds position |
| `radius` | Collision circle radius used by Enemy |

## 2 — Register in Spawner

Open `spawning/spawner.gd`.  Add a `const` path and load it in `setup()`:

```gdscript
const MYENEMY_PATH := "res://enemies/<variant>.tres"
...
var myenemy: EnemyData = load(MYENEMY_PATH) as EnemyData
_variants[&"<variant>"] = myenemy
```

## 3 — Register in DifficultyTimeline

Open `spawning/difficulty_timeline.gd`.  In `state_at(t)`, add `&"<variant>"` to the `allowed_variants` array at the appropriate time threshold.

## 4 — (Optional) Custom behaviour

If the enemy needs unique behaviour (e.g., ranged projectile, split on death), override `Enemy` in a subclass and update `spawner.gd` to instantiate the specialised scene.

## 5 — Test

- Run the GUT suite (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`) — must stay green.
- Manual playtest: enemy spawns, moves, deals damage, drops XP gem.

See also: [[enemy]], [[difficulty-timeline]], [[spawner]]
