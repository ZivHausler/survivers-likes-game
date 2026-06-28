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

| Signal | Handler | Effect |
|---|---|---|
| `enemy_killed(position, xp_value)` | `_on_enemy_killed` | **C1:** DeathPop burst + DamageNumber + small shake |
| `xp_collected(amount)` | `_on_xp_collected` | stub (Wave D) |
| `player_leveled_up(level)` | `_on_player_leveled_up` | stub (Wave D) |
| `player_hp_changed(current, max_hp)` | `_on_player_hp_changed` | **C1:** HitFlash on player + shake on HP decrease |
| `player_died()` | `_on_player_died` | stub (Wave D) |
| `evolution_unlocked(weapon_id)` | `_on_evolution_unlocked` | stub (Wave D) |

Wave C (Task C1) filled `_on_enemy_killed` and `_on_player_hp_changed`.

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
Camera shake is forwarded to the `ScreenShake` child of `_camera` (see [[vfx-system]]).

---

## Guard contract

- `_safe_parent()` returns `null` if `_player` is freed/null → handlers return early, zero spawns.
- `_add_trauma()` no-ops if `_camera` is null/freed or has no `ScreenShake` child.
- `HitFlash.flash()` no-ops if its `CanvasItem` argument is freed.
- Enemy hit-flash (`enemy.gd`) only calls `HitFlash.flash` when the enemy **survives** the hit, avoiding any post-`queue_free` access.
