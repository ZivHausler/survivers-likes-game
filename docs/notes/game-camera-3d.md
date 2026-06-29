# game-camera-3d

`GameCamera3D` (`core/game_camera_3d.gd`) is a `Camera3D` subclass introduced in the 3D vertical slice (Task 1.1). It started as a fixed tilted follow camera and now also supports **player-driven orbit/tilt by left-drag**.

## Behaviour

- **Projection**: Perspective (not orthographic) — subtle depth reads better than isometric.
- **Tilt (pitch)**: `pitch_degrees` (default **−65°**) — looking down with a clear side tilt, not straight down. Drag-mutable, clamped to `[PITCH_MIN, PITCH_MAX]` = `[−85°, −25°]`.
- **Orbit (yaw)**: `yaw_degrees` (default **0°**) — orbit angle around the target's Y axis. Drag-mutable, wraps in `[−180°, 180°]`.
- **Follow**: Tracks `target` (a `Node3D`) on **X and Z only**. Camera Y = `height` (constant, default 14.0). Position and orientation rotate by the **same yaw** around the target, so the camera keeps aiming at the target from any angle.
- **Pull-back**: Horizontal radius `distance` (default 6.5) from the target. At yaw 0 the camera sits at `(target.x, height, target.z + distance)`; non-zero yaw rotates that offset around the target.
- **Smooth follow**: Uses `lerp` with `follow_speed` (default 10.0) so motion feels weighted, not snappy. (Only position lerps; orientation snaps.)

## Controls

| Input | Effect |
|---|---|
| **Left-drag, horizontal** | Orbit (yaw) by `relative.x * DRAG_SENSITIVITY` |
| **Left-drag, vertical** | Tilt (pitch) by `relative.y * DRAG_SENSITIVITY`, clamped |
| **Middle-click** | `reset_view()` → default −65° pitch, 0° yaw |
| **Mouse wheel** | Zoom (scales `height`/`distance` via `zoom`) |

`DRAG_SENSITIVITY` = 0.3 °/px. Drag handling lives in `_unhandled_input`, so a drag is ignored while a UI element (e.g. the level-up cards) is consuming input.

## Geometry (why the numbers work)

With height=14, distance=6.5, pitch=−65° (yaw 0):
- Camera sits at `(target.x, 14, target.z + 6.5)`.
- `atan(height/distance) = atan(14/6.5) ≈ 65°`, so the camera looks directly at the target's XZ position. ✓
- Pitch and pull-back are kept in sync so this aim holds; changing one without the other shifts the focal point.

## Camera-relative movement

The player (`player/player_3d.gd`) reads `yaw_radians()` from the active camera and rotates its WASD input by it (`move_to_velocity(dir, speed, yaw_rad)`), so "up" always heads toward screen-top regardless of orbit. See [player-3d](player-3d.md).

## Pure helpers (unit-testable without a live scene)

| Function | Returns |
|---|---|
| `compute_position(target_pos, height, distance, yaw_deg=0) → Vector3` | Camera world position, orbited by yaw |
| `compute_basis(pitch_deg, yaw_deg=0) → Basis` | Yaw (around Y) ∘ pitch (around X) orientation |
| `clamp_pitch(deg) → float` | Clamp pitch to `[PITCH_MIN, PITCH_MAX]` |
| `clamp_zoom(z) → float` | Clamp zoom to `[ZOOM_MIN, ZOOM_MAX]` |
| `decay_trauma` / `shake_offset` | Screen-shake math |

Position and `compute_basis` use the **same yaw**, so the camera's +Z axis (it looks down −Z) shares the heading of the position offset and keeps aiming at the target — verified by `test_compute_basis_azimuth_matches_position_azimuth`.

## Tests

`test/test_game_camera_3d.gd` — covers XZ tracking, fixed Y, yaw orbit position/basis, pitch clamp, left-drag orbit/tilt, middle-click/`reset_view`, `yaw_radians`, zoom, and screen-shake. Hardcoded-trig ground truth for both the −55° and −65° pitch bases.

> Note: the drag *feel* (sensitivity, direction signs) and the player's viewport-yaw read are confirmed by owner playtest — headless can't render or supply an active camera.
