# Sprite Integration — Visual Data Fields

Describes the optional sprite fields added in Wave A (Task A2) and the fallback
rule used by Wave B renderers.

---

## New fields

### `CharacterData.sprite_frames: SpriteFrames`  (default `null`)

Added to `core/character_data.gd`.  
Holds an `AnimatedSprite2D`-compatible `SpriteFrames` resource for the player
character.  When a character's `.tres` file has no `sprite_frames` set, the
field is `null`.

### `EnemyData.texture: Texture2D`  (default `null`)

Added to `enemies/enemy_data.gd`.  
A single sprite texture for the enemy.  When `null`, the enemy renders with its
existing coloured-circle placeholder.

---

## Fallback rule

> **If the optional sprite field is `null`, fall back to the existing colour-shape placeholder. Never crash.**

Implemented in Wave B (Tasks B1 and B2):

- `Player` checks `data.sprite_frames != null` before assigning to `AnimatedSprite2D`.
  If null, the existing `ColorRect` / polygon placeholder remains visible.
- `Enemy` checks `data.texture != null` before assigning to `Sprite2D`.
  If null, the existing coloured `Polygon2D` / circle remains visible.

This rule ensures all existing `.tres` files (which have no sprite field) keep
working identically after the Wave A field additions.

---

## Backward compatibility

The new fields use Godot 4's `@export` with a reference type default of `null`.
Existing `.tres` resource files do not serialise the field, so loading them
produces `null` automatically — no migration needed.
