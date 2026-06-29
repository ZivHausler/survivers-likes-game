# game-camera-3d

`GameCamera3D` (`core/game_camera_3d.gd`) is a `Camera3D` subclass introduced in the 3D vertical slice (Task 1.1). It started as a fixed tilted follow camera and now is a **player-driven orbit camera**.

## Model: orbit sphere

The camera sits on a **sphere of radius `distance`** centered on `target`. Both pitch and yaw move the camera's *position* around that sphere; the camera then `look_at()`s the target every frame, so **the target is always centered** — regardless of follow lag, orbit, or tilt.

- **Tilt (pitch)**: `pitch_degrees` (default **−65°**) is the elevation on the sphere. Drag-mutable, clamped to `[PITCH_MIN, PITCH_MAX]` = `[−85°, −25°]`. Steeper (more negative) → higher and more top-down.
- **Orbit (yaw)**: `yaw_degrees` (default **0°**) is the azimuth around the target's Y axis. Drag-mutable, wraps in `[−180°, 180°]`.
- **Radius**: `distance` (default **15.4**) is the straight-line distance from the target. At −65° this yields ≈ height 14 / pull-back 6.5 — the approved framing. The mouse wheel scales it via `zoom`.
- **Follow**: position smooth-`lerp`s toward the orbit point at `follow_speed` (default 10). Because `look_at` runs every frame, the target stays centered even while the position catches up.

> Why this replaced the earlier "fixed height/distance + analytic pitch basis" version: there, pitch only rotated the *orientation* (the camera pivoted in place → target slid off-center on tilt), and during orbit the lerping position lagged the snapping basis (→ off-center while swinging). Position-on-a-sphere + `look_at` fixes both.

## Controls

| Input | Effect |
|---|---|
| **Left-drag, horizontal** | Orbit (yaw) by `relative.x * DRAG_SENSITIVITY` |
| **Left-drag, vertical** | Tilt (pitch) by `relative.y * DRAG_SENSITIVITY`, clamped |
| **Middle-click** | `reset_view()` → default −65° pitch, 0° yaw |
| **Mouse wheel** | Zoom (scales `distance` via `zoom`) |

`DRAG_SENSITIVITY` = 0.3 °/px. Drag handling lives in `_unhandled_input`, so a drag is ignored while a UI element (e.g. the level-up cards) is consuming input.

## Camera-relative movement

The player (`player/player_3d.gd`) reads `yaw_radians()` from the active camera and rotates its WASD input by it (`move_to_velocity(dir, speed, yaw_rad)`), so "up" always heads toward screen-top regardless of orbit. See [player-3d](player-3d.md).

## Pure helpers (unit-testable without a live scene)

| Function | Returns |
|---|---|
| `compute_position(target_pos, radius, pitch_deg, yaw_deg) → Vector3` | Camera world position on the orbit sphere (always `radius` from the target, above it) |
| `clamp_pitch(deg) → float` | Clamp pitch to `[PITCH_MIN, PITCH_MAX]` |
| `clamp_zoom(z) → float` | Clamp zoom to `[ZOOM_MIN, ZOOM_MAX]` |
| `decay_trauma` / `shake_offset` | Screen-shake math |

Orientation is delegated to `Node3D.look_at(target, UP)` (an engine primitive), so given a correct position the centering is guaranteed; tests cover the position geometry and the radius invariant (`|pos − target| == radius` at any pitch/yaw).

## Tests

`test/test_game_camera_3d.gd` — orbit-sphere position (radius invariant, target tracking, yaw heading, pitch elevation, zoom scaling), pitch/zoom clamps, left-drag orbit/tilt, middle-click/`reset_view`, `yaw_radians`, wheel-zoom, and screen-shake helpers.

> Note: drag *feel* (sensitivity, direction signs) and the player's viewport-yaw read are confirmed by owner playtest — headless can't render or supply an active camera.
