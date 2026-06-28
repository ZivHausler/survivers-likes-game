# VFX System — Wave C Effect Scenes

Added in Task C1. All effects are pure-visual nodes that auto-free; they never
touch gameplay state.

---

## ScreenShake

**File:** `fx/screen_shake.gd` | **Class:** `ScreenShake`  
**Usage:** Add as a child `Node` of the player's `Camera2D` in `player.tscn`.

Trauma-based shake model: trauma decays at `DECAY` units/s; camera offset
magnitude = `trauma² × MAX_OFFSET`. The pure helper `ScreenShake._offset_for(trauma, t)`
is static and fully testable without a live scene.

```gdscript
# Acquired by Juice via:
var shake := _camera.get_node_or_null("ScreenShake") as ScreenShake
shake.add_trauma(0.25)
```

---

## HitFlash

**File:** `vfx/hit_flash.gd` | **Class:** `HitFlash`  
**Usage:** Call `HitFlash.flash(canvas_item, duration)` from anywhere.

Static utility. Tweens `modulate` to `Color.WHITE` then back to the node's
original modulate over `duration` seconds (40 % forward / 60 % return).
Guarded: no-ops if `ci` is freed. Does not alter any gameplay property.

```gdscript
HitFlash.flash($Sprite, 0.08)   # brief enemy hit flash
HitFlash.flash(_player, 0.15)   # player takes damage
```

---

## DamageNumber

**Files:** `vfx/damage_number.tscn` / `vfx/damage_number.gd` | **Class:** `DamageNumber`  
**Base:** `Label`

Floats upward `FLOAT_DIST` pixels and fades alpha to 0 over `LIFETIME` seconds,
then calls `queue_free` via the tween's `finished` signal.

```gdscript
var num: DamageNumber = _DamageNumberScene.instantiate()
parent.add_child(num)
num.setup(xp_value, position)
```

Constants exposed for tests: `DamageNumber.LIFETIME`, `DamageNumber.FLOAT_DIST`.

---

## DeathPop

**Files:** `vfx/death_pop.tscn` / `vfx/death_pop.gd` | **Class:** `DeathPop`  
**Base:** `CPUParticles2D`

One-shot particle burst (`one_shot = true`, `explosiveness = 0.9`). Configured
with 12 particles, warm-orange colour, 40–120 px/s velocity, full spread.
Auto-frees via `SceneTreeTimer` after `lifetime + 0.2 s`.

```gdscript
var pop: DeathPop = _DeathPopScene.instantiate()
parent.add_child(pop)
pop.play_at(position)
```

---

---

## EvolutionFlash

**Files:** `vfx/evolution_flash.tscn` / `vfx/evolution_flash.gd` | **Class:** `EvolutionFlash`  
**Base:** `CanvasLayer`

Full-screen additive white flash used for evolution events (intensity 1.0) and level-up
fanfare (intensity 0.4). Creates a `ColorRect` with `BLEND_MODE_ADD` and a radial
`CPUParticles2D` burst, then auto-frees via `SceneTreeTimer` after 0.8 s.

```gdscript
var flash: EvolutionFlash = _EvolutionFlashScene.instantiate()
flash.set_intensity(0.4)   # omit for full-brightness evolution flash
parent.add_child(flash)    # auto-frees after ~0.8 s
```

`set_intensity(v: float)` scales the ColorRect alpha: `0.85 * v`. Default (no call) = 1.0.

---

## XpSparkle

**Files:** `vfx/xp_sparkle.tscn` / `vfx/xp_sparkle.gd` | **Class:** `XpSparkle`  
**Base:** `CPUParticles2D`

Small golden burst (8 particles, 0.4 s lifetime, one-shot) that fires at the player's
position when `xp_collected` is emitted. Auto-frees after `lifetime + 0.2 s`.

```gdscript
var sparkle: XpSparkle = _XpSparkleScene.instantiate()
parent.add_child(sparkle)
sparkle.play_at(_player.global_position)
```

---

## Decoupling guarantee

All effects are added to `get_tree().current_scene` (obtained from the registered
player's tree), not to the player or enemy nodes themselves. If no player is
registered (or it has been freed), `Juice._safe_parent()` returns `null` and the
handler returns early — no spawning, no crash. Camera-shake calls guard
`is_instance_valid(_camera)` separately.
