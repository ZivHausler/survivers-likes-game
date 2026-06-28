# how-to-add-a-character

Step-by-step runbook for adding friend #3 and beyond.

---

## 1 — Create the weapon scene + script

In `weapons/`, create `<name>_<ability>.gd` (extends `Weapon`) and a matching `.tscn`.

Requirements for the script:
- Set `base_cooldown` before calling `super()` in `_ready()`.
- Override `fire()` with the ability's effect.
- Override `level_up()` — call `super()` first, then scale stats.
- Override `evolve()` — call `super()` first (sets `evolved = true`), then activate the evolved behaviour.
- Override `apply_passive(value: float)` — apply the dedicated passive bonus (e.g. extra duration, damage, rate).

## 2 — Create the three Upgrade resources

Create a folder `upgrades/<name>/` with three `.tres` files:

| File | Fields |
|------|--------|
| `signature.tres` | `id=&"<name>_signature"`, `kind=0` (SIGNATURE), `max_level=5`, `display_name` |
| `passive.tres`   | `id=&"<name>_passive"`, `kind=1` (PASSIVE), `max_level=5`, `effect_value=<delta_per_level>` |
| `evolution.tres` | `id=&"<name>_evolution"`, `kind=3` (EVOLUTION), `max_level=1`, `display_name="EVOLVE: ..."` |

Template (replace values):
```
[gd_resource type="Resource" script_class="Upgrade" load_steps=2 format=3]
[ext_resource type="Script" uid="uid://b1q0nl1sgdf2j" path="res://upgrades/upgrade.gd" id="1_upgrade"]
[resource]
script = ExtResource("1_upgrade")
id = &"<name>_signature"
display_name = "<Label>"
kind = 0
max_level = 5
effect_kind = &""
effect_value = 0.0
```

## 3 — Create the CharacterData resource

Create `characters/<name>.tres`:

```
[gd_resource type="Resource" script_class="CharacterData" load_steps=8 format=3]
[ext_resource type="Script" uid="uid://oeuj1jqprh5d" path="res://core/character_data.gd" id="1_char_data"]
[ext_resource type="Script" uid="uid://0rwxad1au28r" path="res://core/stat_block.gd" id="2_stat_block"]
[ext_resource type="PackedScene" path="res://<weapon_scene>" id="3_weapon"]
[ext_resource type="Resource" path="res://upgrades/<name>/signature.tres" id="4_sig"]
[ext_resource type="Resource" path="res://upgrades/<name>/passive.tres"   id="5_pas"]
[ext_resource type="Resource" path="res://upgrades/<name>/evolution.tres" id="6_evo"]

[sub_resource type="Resource" id="Resource_stats"]
script = ExtResource("2_stat_block")
max_hp = 100.0
move_speed = 120.0
pickup_range = 48.0
damage_mult = 1.0
fire_rate_mult = 1.0
armor = 0.0

[resource]
script = ExtResource("1_char_data")
id = &"<name>"
display_name = "<Name>"
color = Color(R, G, B, 1.0)
base_stats = SubResource("Resource_stats")
weapon_scene = ExtResource("3_weapon")
passive_id = &"<name>_passive"
evolution_id = &"<name>_evolution"
max_signature_level = 5
signature_upgrade = ExtResource("4_sig")
passive_upgrade = ExtResource("5_pas")
evolution_upgrade = ExtResource("6_evo")
```

## 4 — Register in character_select.tscn

Open `ui/character_select.gd` and add a new Button + load path for the new character.

## 5 — Verify

- Run `godot --headless --import` — no errors.
- Run the GUT suite — all tests still pass.
- Manual: select the new character, verify weapon fires, leveling shows the right upgrades, evolution triggers after max signature + passive.

## Notes on generic upgrades

Generic upgrades (`upgrades/generic/*.tres`) are shared by all characters.  The `GameManager` loads them automatically.  You do not need to author new generic upgrades per character.

See also: [[upgrade-system]], [[evolution-rule]], [[data-driven-characters]]
