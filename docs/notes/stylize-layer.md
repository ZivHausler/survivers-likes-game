---
id: stylize-layer
title: "stylize-layer — Cel + Rim + Emissive Spatial Shader"
tags: [shader, visual, stylized-render, lol-swarm]
links: [visual-palette]
---

# stylize-layer — Cel + Rim + Emissive Spatial Shader

`shaders/cel_rim.gdshader` is the core look-shader for the League of Legends: Swarm stylized
render layer. It gives 3D meshes a flat-lit, hand-drawn aesthetic: hard cel-shaded diffuse bands,
a Fresnel rim glow, and an optional painted emissive overlay.

## Intent

Match the LoL: Swarm visual read: solid toon shading (no soft gradients), bright colored
silhouette rim, and selective glow painted via a mask texture. The shader is cheap (no loops)
and is designed to be set as `material_override` on character/enemy `MeshInstance3D`s by the
`Stylize` autoload (Task 1.3).

## Uniform Contract

| Uniform | Type | Default | Purpose |
|---------|------|---------|---------|
| `albedo_tint` | `Color` | `(1,1,1,1)` | Flat tint multiplied with the albedo texture |
| `albedo` | `sampler2D` | white | Optional diffuse texture; flat tint when unbound |
| `rim_color` | `Color` | `(1,1,1,1)` | Fresnel rim glow color |
| `rim_power` | `float` | `2.0` | Rim falloff exponent (higher = tighter rim) |
| `emissive_mask` | `sampler2D` | black | Optional single-channel mask for glow areas |
| `emissive_color` | `Color` | `(1,1,1,1)` | Color of the emissive glow |
| `emissive_energy` | `float` | `1.0` | Intensity multiplier for the emissive glow |

`albedo` and `emissive_mask` use Godot hint defaults (`hint_default_white` /
`hint_default_black`) so the shader is fully functional with nothing bound.

## Implementation

**Cel ramp (`light()`):** `NdotL` is quantized into 2 bands via `step()` — dark below 0,
mid 50% from 0..0.5, full from 0.5..1. Result multiplied by `ATTENUATION * LIGHT_COLOR` and
accumulated into `DIFFUSE_LIGHT`. Works correctly with multiple lights and shadow maps.

**Rim (`fragment()`):** `pow(1 - dot(NORMAL, VIEW), rim_power)` gives a Fresnel falloff at
silhouette edges; scaled by `rim_color` and added to `EMISSION`.

**Emissive mask (`fragment()`):** Red channel of `emissive_mask` multiplied by
`emissive_color * emissive_energy` added to `EMISSION`. Artists paint glow areas in red on a
black mask.

## Stylize Autoload (`vfx/stylize.gd`)

The `Stylize` autoload (registered as `Stylize` in `project.godot`) applies `cel_rim.gdshader`
to any model subtree via a single call:

```gdscript
Stylize.apply_to(node: Node3D, tint: Color, rim: Color) -> void
```

**What it does:** Recursively walks all `MeshInstance3D` descendants of `node`. For each one,
it builds a `ShaderMaterial` with `cel_rim.gdshader`, sets `albedo_tint` and `rim_color`, copies
any existing `albedo_texture` from the surface's active `StandardMaterial3D` (via
`get_active_material(i)`) into the shader's `albedo` param, then assigns it as
`material_override`.

**Call order matters:** Wire `apply_to()` AFTER `_apply_texture` / `_apply_tint` in `setup()`
so the surface override materials already carry the albedo atlas texture to copy.

**Removable (decoupled):** Callers guard with `get_node_or_null("/root/Stylize")` so the
entire visual layer is a no-op when the autoload is absent — gameplay logic is unaffected.

### Caller pattern

```gdscript
var _s := get_node_or_null("/root/Stylize")
if _s:
    _s.apply_to(_model, tint, VisualPalette.role(&"enemy_secondary"))
```

Player wires `data.model_tint` as tint; enemies wire `data.color`.

### Usage example (direct)

```gdscript
var mat := ShaderMaterial.new()
mat.shader = preload("res://shaders/cel_rim.gdshader")
mat.set_shader_parameter("albedo_tint", VisualPalette.role(&"player_primary"))
mat.set_shader_parameter("rim_color",   VisualPalette.role(&"player_secondary"))
mat.set_shader_parameter("albedo",      surface_albedo_texture)
mesh_instance.material_override = mat
```

## Related

- [[visual-palette]] — Color roles (`player_primary`, `enemy_primary`, etc.) used to drive
  `albedo_tint` and `rim_color` per character/enemy type
