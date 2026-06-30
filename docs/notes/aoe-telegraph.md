# aoe-telegraph

**ID:** `[[aoe-telegraph]]`

Flat additive ring telegraph decal drawn on the XZ ground plane. Spawned by the `SkillVFX` autoload on every `skill_cast` event to give LoL Swarm-style ground readability.

## Files

| File | Role |
|---|---|
| `shaders/telegraph_ring.gdshader` | Additive ring shader — `blend_add, cull_disabled, unshaded, depth_test_disabled`; uniforms `ring_color`, `radius` (0..1 normalized), `width` |
| `vfx/aoe_telegraph_3d.gd` | `class_name AoeTelegraph3D extends MeshInstance3D`; `play_at(pos, radius, color)` |
| `vfx/aoe_telegraph_3d.tscn` | `MeshInstance3D` + flat `PlaneMesh` (2×2 units); shader material wired |
| `autoload/skill_vfx.gd` | Additive dispatch: after existing `SkillCastFx3D`, spawns `AoeTelegraph3D` |

## API

```gdscript
# Spawn and play a telegraph at world-space pos, expanding to radius world-units.
AoeTelegraph3D.play_at(pos: Vector3, radius: float, color: Color) -> void
```

The node auto-frees after `0.9 s` (0.8 s lifetime + 0.1 s guard).

## How it works

The shader operates in normalized UV space (0..1 across the mesh). The script scales the `MeshInstance3D` to `radius * 2` on XZ, so UV maps directly to world units. `play_at` creates a fresh `ShaderMaterial` per instance (avoids shared-material aliasing), then tweens `shader_parameter/radius` from `0.02` to `0.92` (expand), followed by a fade-out of `ring_color.a` to 0.

## Concerns / Known limitations

- **No radius in signal**: `GameEvents.skill_cast` carries `(vfx_id, color, position)` — no radius. A fixed `_DEFAULT_TELEGRAPH_RADIUS = 6.0` is used for all casts. This can be refined if the signal is extended or a per-weapon radius lookup is added later.
- **All casts get a telegraph**: There is no reliable way to distinguish nova/ground casts from orbit/projectile casts from the signal alone. All `skill_cast` emissions receive a telegraph. This is intentional for readability; orbit weapons will also pulse a ring which is a minor false positive but not harmful.
- **Boss telegraphs**: Boss variants (brighter, `VisualPalette.role(&"danger")`) are noted in the spec but not yet driven from the signal (no boss flag in signal). Could be wired when enemy-type info is added to the signal.

## Related

- [[skill-vfx]] — `SkillVFX` autoload that dispatches the telegraph
- [[visual-palette]] — `VisualPalette` color roles (`danger` for boss telegraphs)
- [[game-events]] — `skill_cast` signal definition
