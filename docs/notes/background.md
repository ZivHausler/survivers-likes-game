---
id: background
title: Background Ground Tile + Vignette
tags: [visual, arena, background, vignette]
links: [arena]
---

# Background Ground Tile + Vignette

Added as part of Task B3 (visual overhaul). The goal is a clean ground plane under all
gameplay nodes and a subtle darkened-edge vignette above the gameplay but below the HUD.

## Ground background

**Node:** `Background` (`Sprite2D`) — **first child** of `Arena` in `game/arena.tscn`.

**Approach:** A single `Sprite2D` with `texture_repeat = ENABLED` and `region_enabled = true`.
`region_rect = Rect2(-2048, -2048, 4096, 4096)` tiles the texture to cover a 4096×4096 world-space
region centred at the origin. The node is rendered at `z_index = -10` so it is drawn below
all gameplay nodes (Player, Enemy, Pickups) without a CanvasLayer.

**Tile chosen:** `art/tiles/Tiles/tile_0000.png` — Kenney Tiny Town (CC0), the first tile
in the pack which is a flat grass/ground tile. It reads cleanly at game scale.

**Why not TileMap:** A single Sprite2D is the simplest approach for v1. A TileMapLayer
requires a TileSet resource and editor workflow; the Sprite2D region approach requires only
a texture reference and two property flags and is easy to adjust later.

**Does not capture input:** `Sprite2D` has no collision and no mouse filter; gameplay is
unaffected.

## Vignette

**Node:** `Vignette` (`CanvasLayer`, `layer = 0`) with child `VignetteRect` (`ColorRect`).

**Ordering:**
- `layer = 0` renders above the 2D world but below the HUD (`CanvasLayer`, default `layer = 1`).
- `VignetteRect` anchors cover the full viewport (`anchor_right = 1, anchor_bottom = 1`).
- `mouse_filter = 2` (`IGNORE`) — no input interception.

**Shader:** Inline `canvas_item` fragment shader on a `ShaderMaterial`:
```glsl
shader_type canvas_item;
void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv) * 2.0;
    float v = smoothstep(0.4, 1.0, dist);
    COLOR = vec4(0.0, 0.0, 0.0, v * 0.65);
}
```
This produces a radial darkening (transparent center → ~65% opaque black edges).
`smoothstep(0.4, 1.0, dist)` ensures the centre ~40% of the screen is clear.

## Camera-following (Task D2)

Player movement is unbounded, so a static ±2048 region eventually shows black
past the edges. `GameManager._process` now repositions the Background Sprite2D
each frame to follow the player:

```gdscript
_background.global_position = player.global_position.snapped(Vector2(16.0, 16.0))
```

Snapping to 16 px (= tile size) prevents sub-pixel shimmer as the sprite moves.
Because `texture_repeat` is enabled, the tiled region is always centred on the
player, making the background effectively infinite with zero extra memory.

`_background` is resolved once in `GameManager._ready()` via
`parent.get_node_or_null("Background")` and guarded with `is_instance_valid`
before each use. The background does not move while the tree is paused (level-up
overlay), which is correct — the player can't move then either.

## Playtest notes

- Ground tile reads as a clean grass/road surface.
- Vignette is subtle at 0.65 max alpha; adjust the multiplier in the shader to taste.
- Background follows the player each frame — it will never run out no matter how
  far the player roams. Confirm during manual playtest: move in one direction for
  several seconds; the tile pattern should continue uninterrupted.
