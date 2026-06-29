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

Small emissive gold sphere (SphereMesh r=0.2). Material set in `_ready()` via `StandardMaterial3D`. Gentle scale-pulse tween for "alive" feel.

## See also

- [[xp-gem]] — 2D original
- [[game-manager-3d]] — instantiates XPGem3D on enemy kills
