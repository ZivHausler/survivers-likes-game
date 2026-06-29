# XPGem3D

`pickups/xp_gem_3d.gd` — `class_name XPGem3D extends Area3D`
`pickups/xp_gem_3d.tscn` — Area3D scene

3D port of `XPGem` (Area2D). Magnets toward the player on the XZ plane, then awards XP on overlap.

## World scale

1 world unit ≈ 16 px.

- `MAGNET_SPEED_MAX = 19.0` (was 300 px)
- `MAGNET_SPEED_MIN = 4.0` (was 60 px)

## magnet_step static helper

```gdscript
static func magnet_step(gem_pos, player_pos, pickup_range, dt) -> Vector3
```

Pure function — returns the XZ position delta for one frame.
- Returns `Vector3.ZERO` when `dist > pickup_range`.
- Speed lerps from `MAGNET_SPEED_MIN` to `MAGNET_SPEED_MAX` as `dist → 0`.
- `y` component is always 0 (XZ plane movement).

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
