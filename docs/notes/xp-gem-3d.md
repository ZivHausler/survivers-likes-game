# XPGem3D

`pickups/xp_gem_3d.gd` — `class_name XPGem3D extends Area3D`
`pickups/xp_gem_3d.tscn` — Area3D scene

3D port of `XPGem` (Area2D). Magnets toward the player on the XZ plane, then awards XP on overlap.

## World scale

1 world unit ≈ 16 px.

- `MAGNET_SPEED_MIN = 4.0` — speed the instant the gem latches
- `MAGNET_SPEED_MAX = 40.0` — peak speed (well above any player move speed)
- `MAGNET_ACCEL = 60.0` u/s² — ramp while latched
- `COLLECT_DIST = 0.35` — arrival auto-collect radius (anti-tunnel safety net)

## Magnet behaviour (latch + accelerate)

Once the gem first enters the player's pickup range it **latches** (`_magnetized`) and
homes in for good — it never un-magnetizes, even if the player outruns it. While latched
the speed **accelerates** every frame (`MAGNET_SPEED_MIN` → `MAGNET_SPEED_MAX` by
`MAGNET_ACCEL`), so a latched gem always overtakes the player regardless of move speed.
This fixes the old bug where a fast player left gems behind: the previous code re-gated on
`dist > pickup_range` every frame (stopping the gem dead) and crawled at `MIN` speed near
the range edge.

Pure static helpers (all XZ-only, `y` = 0):
```gdscript
static func in_pickup_range(gem_pos, player_pos, pickup_range) -> bool  # latch gate
static func next_magnet_speed(current, dt) -> float                     # accel ramp, capped
static func magnet_delta(gem_pos, player_pos, speed, dt) -> Vector3     # homing step
```
`magnet_delta` returns the exact remaining diff when a step would overshoot, so a fast gem
lands on the player instead of tunnelling past; `_process` also auto-collects within
`COLLECT_DIST` as a backup to the physics overlap.

## Collection

- `setup(value: int, player: Node3D)` — stores refs, connects `body_entered`.
- `_collect()` — guards double-collect; calls `player.add_xp(value)`; emits `GameEvents.xp_collected`; frees self.
- `body_entered` → fires when the player CharacterBody3D (layer 1) enters the Area3D.

## Scene collision

| Property | Value | Reason |
|---|---|---|
| `collision_layer` | 0 | Gem occupies no layer |
| `collision_mask` | 1 | Detects player body (layer 1) only — NOT enemies (layer 8) |
| `monitoring` | true | Must be true to receive body_entered |

## Visual

Small emissive sphere (SphereMesh r=0.2). Gentle scale-pulse tween for "alive" feel (runs in `_ready()`). Material color is set in `setup()` via `tier_color(_value)` so the orb visually signals its XP tier.

## tier_color static helper

```gdscript
static func tier_color(value: int) -> Color
```

Maps an XP value to one of five distinct tier colors. Higher value = hotter/rarer color.

| Range | Color | Name |
|---|---|---|
| 1–2 | `Color(0.3, 0.6, 1.0)` | blue — easiest/earliest enemies |
| 3–5 | `Color(0.3, 1.0, 0.4)` | green |
| 6–15 | `Color(1.0, 0.9, 0.2)` | yellow |
| 16–49 | `Color(1.0, 0.55, 0.1)` | orange |
| 50+ | `Color(1.0, 0.2, 0.6)` | magenta — bosses / late-game |

A fresh `StandardMaterial3D` with `emission_enabled = true` is created per gem in `setup()` so no shared resource is ever mutated.

## See also

- [[xp-gem]] — 2D original
- [[game-manager-3d]] — instantiates XPGem3D on enemy kills
