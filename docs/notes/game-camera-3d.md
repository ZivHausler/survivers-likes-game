# game-camera-3d

`GameCamera3D` (`core/game_camera_3d.gd`) is a `Camera3D` subclass introduced in the 3D vertical slice (Task 1.1).

## Behaviour

- **Projection**: Perspective (not orthographic) — subtle depth reads better than isometric.
- **Pitch**: Fixed at `pitch_degrees` (default **−55°**) — looking down with a clear side tilt, not straight down.
- **Follow**: Tracks `target` (a `Node3D`) on **X and Z only**. Camera Y = `height` (constant, default 14.0). The camera never rotates to face the target.
- **Pull-back**: Camera Z = `target.z + distance` (default 10.0). This positions the camera "behind" the target along +Z so the –55° pitch reads the scene correctly — the focal point lands roughly on the target.
- **Smooth follow**: Uses `lerp` with `follow_speed` (default 10.0) so motion feels weighted, not snappy.

## Geometry (why the numbers work)

With height=14, distance=10, pitch=−55°:
- Camera sits at `(target.x, 14, target.z + 10)`.
- Looking direction: `(0, sin(−55°), −cos(−55°))` ≈ `(0, −0.819, −0.574)`.
- Ray from camera hits y=0 at t = 14/0.819 ≈ 17.1 → Δz ≈ −0.574 × 17.1 ≈ −9.8 ≈ −10.
- So the camera looks directly at the target's XZ position. ✓

## Pure helpers (unit-testable without a live scene)

| Function | Returns |
|---|---|
| `compute_position(target_pos, height, distance) → Vector3` | Camera world position |
| `compute_pitch_basis(pitch_deg) → Basis` | Pure X-axis rotation basis |

## Tests

`test/test_game_camera_3d.gd` — 11 assertions covering XZ tracking, fixed Y, Z+distance offset, and pitch basis correctness.
