# Orbit Camera + Camera-Relative Movement — Design

> Date: 2026-06-29 · Branch: `feature/orbit-camera` · Status: approved, pending implementation plan

## Goal

Let the player **freely orbit and tilt** the gameplay camera by **dragging with the left mouse
button**, instead of the fixed −65° tilt. Movement stays intuitive by becoming **camera-relative**:
"up" always moves the player toward the top of the screen no matter how the view is rotated.

This builds on the just-made tilt change (default pitch −65°, `distance` 6.5, carried into this branch).

## Behavior (player-facing)

| Input | Effect |
|-------|--------|
| **Left-drag, horizontal** | Orbit the camera around the player (yaw) |
| **Left-drag, vertical** | Tilt the camera (pitch), clamped to a sane range |
| **Middle-click** | Reset view to default (−65° pitch, original facing / yaw 0) |
| **Mouse wheel** | Zoom in/out (unchanged) |
| **WASD / arrows** | Move relative to the current screen orientation |

- The orbited/tilted view **persists** where the player leaves it (free-look; no auto-snap-back).
- Pitch is clamped to **[−85°, −25°]** so the camera can't flip under the floor or go fully flat.
- Yaw spins freely (no clamp); stored normalized to avoid unbounded growth (cosmetic).

## Components

### 1. `core/game_camera_3d.gd` — the orbit camera

**New/changed state**
- `@export var yaw_degrees: float = 0.0` — orbit angle around the target's Y axis.
- `pitch_degrees` becomes runtime-mutable via drag (already exported; default −65°).
- New constants: `DRAG_SENSITIVITY` (~0.3 °/px), `PITCH_MIN = -85.0`, `PITCH_MAX = -25.0`,
  `DEFAULT_PITCH = -65.0`, `DEFAULT_YAW = 0.0`.
- New transient: `_dragging: bool` (left button held).

**Input** — extend the existing `_unhandled_input` (which already handles wheel-zoom):
- Left button pressed/released → set/clear `_dragging`.
- `InputEventMouseMotion` while `_dragging`:
  - `yaw_degrees` adjusted by `relative.x * DRAG_SENSITIVITY` (sign chosen so drag-right swings the
    view right; verified by feel in playtest).
  - `pitch_degrees = clamp_pitch(pitch_degrees - relative.y * DRAG_SENSITIVITY)`.
- Middle button pressed → `reset_view()` (sets pitch/yaw back to the `DEFAULT_*` constants).

Using `_unhandled_input` means drags are ignored while a UI element (the level-up cards) has the
event — so the player won't accidentally orbit while picking an upgrade.

**Orbit geometry — pure static helpers (unit-testable, the codebase's core pattern):**
- `compute_position(target_pos, height, distance, yaw_rad)` — the horizontal offset now **rotates by
  yaw** around the target:
  `Vector3(target.x + sin(yaw)*distance, height, target.z + cos(yaw)*distance)`.
  At `yaw = 0` this is `(target.x, height, target.z + distance)` — **identical to today**.
- `compute_basis(pitch_deg, yaw_deg)` replaces `compute_pitch_basis`. It composes yaw (around Y) with
  pitch (around X): `Basis.from_euler(Vector3(0, yaw, 0)) * Basis.from_euler(Vector3(pitch, 0, 0))`.
  Because position and orientation rotate by the **same** yaw around the target, the camera keeps
  pointing at the player from any angle. At `yaw = 0` it equals the old pitch-only basis.
- `clamp_pitch(deg)` — clamps to `[PITCH_MIN, PITCH_MAX]`.
- New accessor `yaw_radians() -> float` for the player to consume.

`_ready` and `_physics_process` pass `yaw_degrees` into both helpers; zoom still scales height/distance
and composes with orbit unchanged.

### 2. `player/player_3d.gd` — camera-relative movement

- `move_to_velocity(dir, speed, yaw_rad := 0.0)` — rotate the input vector by the camera yaw before
  mapping to world XZ: `Vector3(dir.x, 0, dir.y).rotated(Vector3.UP, yaw_rad) * speed`. The default
  `0.0` keeps every existing 2-arg call/test **identical** (world-fixed = current behavior).
- In `_physics_process`: read the active camera via `get_viewport().get_camera_3d()`; if it
  `is GameCamera3D`, feed `cam.yaw_radians()` into `move_to_velocity`. No camera (headless tests) →
  yaw 0 → current behavior, no crash.
- `face_angle` is unchanged: the model still faces the **actual world velocity**, which is now already
  camera-relative, so facing stays correct.

## Error handling / edge cases

- **Pitch clamp** prevents under-floor flip / fully-flat horizon.
- **No active camera** (headless / before wiring): movement yaw defaults to 0 → world-fixed.
- **Zoom** composes with orbit (both just scale/rotate the same offset).
- **UI interaction**: `_unhandled_input` yields to UI, so card-picking never triggers a drag.
- **Yaw growth**: normalized via `fmod`/`wrapf` to keep the stored value bounded (cosmetic only).

## Testing (GUT, headless)

> ⚠️ GUT 9.7.0 silently skips files using `assert_le`/`assert_ge` — use `assert_true(x <= y)`.
> Watch that the test count rises as expected.

- `compute_position` orbit: `yaw = 0` matches legacy values exactly; `yaw = 90°`, `180°` place the
  camera at the expected offsets around the target.
- `compute_basis`: `yaw = 0` equals the old pitch-only basis (keep a hardcoded-trig check, add −65°);
  a yaw-rotation case produces the expected basis columns.
- `clamp_pitch`: clamps below −85 and above −25; passes mid-range through.
- `move_to_velocity` with yaw: `yaw = 0` unchanged; `yaw = 90°` rotates the input as expected; zero
  input → zero (never NaN).
- `reset_view()`: restores `pitch_degrees`/`yaw_degrees` to the `DEFAULT_*` constants.
- **Drag feel** (sensitivity, drag-direction sign, smoothness) → owner playtest; headless can't render.

## Refactor note

This renames `compute_pitch_basis` → `compute_basis` and extends `compute_position`'s signature. Both
touch existing camera tests; those call sites get the new `yaw` argument (value 0), which preserves
current geometry so they stay green. Keeping these as pure static helpers preserves the codebase's
testable-core convention.

## Out of scope (YAGNI)

- No momentum/inertia on the orbit, no edge-pan, no right-drag, no touch/gamepad camera control.
- No per-character or persisted camera preferences.
- No change to zoom, shake, or follow behavior beyond threading `yaw` through.
