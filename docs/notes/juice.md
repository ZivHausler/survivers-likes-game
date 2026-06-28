# Juice — Visual Effects Autoload

**File:** `autoload/juice.gd`
**Autoload name:** `Juice`

---

## Purpose

`Juice` is the decoupled visual-feedback layer for Friends Swarm.  
It listens to every `GameEvents` signal and translates game logic events into
screen-space effects (particles, camera shake, tweens, sounds).

**Decoupling guarantee:** disabling (removing) the `Juice` autoload reverts the
game to its pure-logic state with zero behaviour change.  Juice never mutates
game state; it is read-only from the simulation's perspective.

---

## Signal connections (all wired in `_ready`)

| Signal | Handler | Effect (Wave C) |
|---|---|---|
| `enemy_killed(position, xp_value)` | `_on_enemy_killed` | Death particles at position |
| `xp_collected(amount)` | `_on_xp_collected` | XP counter flash |
| `player_leveled_up(level)` | `_on_player_leveled_up` | Level-up fanfare |
| `player_hp_changed(current, max_hp)` | `_on_player_hp_changed` | Hit vignette / HP flash |
| `player_died()` | `_on_player_died` | Death-screen transition |
| `evolution_unlocked(weapon_id)` | `_on_evolution_unlocked` | Evolution sparkle |

All handler bodies are **empty stubs** in Wave A/B; Wave C fills them.

---

## Public API

```gdscript
Juice.register_camera(cam: Camera2D) -> void
```
Store a reference to the active camera (used for shake effects in Wave C).

```gdscript
Juice.register_player(p: Node2D) -> void
```
Store a reference to the player node (used for centred effects in Wave C).

Both refs are guarded with `is_instance_valid` before use.

---

## Adding effects (Wave C guide)

1. Identify the relevant handler (e.g. `_on_enemy_killed`).
2. Instantiate a pre-authored `PackedScene` effect and add it to the scene tree via `get_tree().root.add_child(effect)` or a dedicated effects layer.
3. Keep the handler idempotent — it must not crash if `_camera` or `_player` are null (call not yet registered or already freed).
