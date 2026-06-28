---
id: weapon-system
title: Weapon — Signature Ability Base Class
tags: [weapons, architecture, lifecycle]
links: [[stat-block]], [[character-data]], [[data-driven-characters]]
---

# Weapon (base class)

`Weapon` (`class_name Weapon extends Node2D`) is the base class for every signature ability in Friends Swarm. All weapons self-drive a firing `Timer`; subclasses only need to override `fire()` (and optionally `evolve()`).

## File

`res://core/weapon.gd`

## Key Variables

| Variable | Type | Default | Meaning |
|----------|------|---------|---------|
| `level` | `int` | `1` | Current upgrade level |
| `stats` | `StatBlock` | `null` | Live stat block injected by `setup()` |
| `evolved` | `bool` | `false` | Whether the weapon has evolved |
| `base_cooldown` | `float` | `1.0` | Base seconds between shots; **subclass sets this before calling `setup()`** |

## API

```gdscript
func setup(player: Node, p_stats: StatBlock) -> void
func fire() -> void            # override — called each timer tick
func level_up() -> void        # increments level, refreshes cooldown
func evolve() -> void          # override — swap behaviour, call super or _refresh_cooldown()
func is_max_level(max_level: int) -> bool
```

## Lifecycle (IMPORTANT)

```
Player.add_child(weapon)   →  weapon._ready() runs
                               • Timer created and connected to fire()
                               • Timer is NOT started; stats is NOT read

weapon.setup(player, stats) →  stats assigned
                               • _refresh_cooldown() sets wait_time
                               • Timer.start() called
```

**`setup()` MUST be called after `add_child()` to begin firing.** The Timer is started in `setup()`, not `_ready()`, because `stats` is `null` until the caller injects it. Reading `stats.fire_rate_mult` in `_ready()` would crash.

## Cooldown Formula

```
timer.wait_time = max(0.05, base_cooldown / stats.fire_rate_mult)
```

A `fire_rate_mult` > 1.0 speeds up the weapon (shorter cooldown). Minimum enforced cooldown is 50 ms.

## Subclass Pattern

```gdscript
class_name SomeWeapon extends Weapon

func _ready() -> void:
    base_cooldown = 0.8      # set BEFORE calling super
    super()                  # Weapon._ready() creates the timer

func setup(player: Node, p_stats: StatBlock) -> void:
    super(player, p_stats)   # assigns stats, starts timer

func fire() -> void:
    # spawn projectile here
    pass

func evolve() -> void:
    base_cooldown = 0.5
    super()
    _refresh_cooldown()
```

## Links

- [[stat-block]] — `stats` field, `fire_rate_mult`
- [[character-data]] — `weapon_scene` points to a scene whose root extends `Weapon`
- [[data-driven-characters]] — Overall data model
