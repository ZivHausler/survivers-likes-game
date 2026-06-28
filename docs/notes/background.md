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

## Playtest notes

- Ground tile is a solid flat colour; reads as a clean grass/road surface.
- Vignette is subtle at 0.65 max alpha; adjust the multiplier in the shader to taste.
- For a scrolling feel, the Background Sprite2D lives in world space and the camera
  moves normally — the tiled region is large enough for typical play sessions.
  If the player can travel > 2048 px from origin, extend `region_rect`.
