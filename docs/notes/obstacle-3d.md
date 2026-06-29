# Obstacle3D — Reusable Collidable Map Prop

## Overview
`Obstacle3D` is a reusable scene-based prop for static arena obstacles (trees, rocks, water).

## Structure
- **Root**: `StaticBody3D` with `collision_layer = 16` (Obstacles layer)
- **collision_mask = 0**: Obstacles don't care about colliding with anything else (the arena and enemies collide with *them*)
- **Children**:
  - `MeshInstance3D`: Placeholder visual mesh (assigned via `configure()`)
  - `CollisionShape3D`: Holds a `CylinderShape3D` footprint (resized via `configure()`)
  - `NavigationObstacle3D`: Radius for enemy RVO avoidance; prevents swarm from pathfinding through the prop

## API
```gdscript
func configure(mesh: Mesh, footprint_radius: float, height: float) -> void
```
- Assigns the visual mesh to `MeshInstance3D`
- Resizes `CollisionShape3D` to a cylinder matching `footprint_radius` (radius) and `height` (height)
- Sets `NavigationObstacle3D.radius = footprint_radius` so enemies route around the prop

## Usage
Task 3 (scatter phase) instantiates `obstacle_3d.tscn` and calls `configure()` with appropriate mesh, radius, and height.

## Notes
- Layer 16 is chosen so skill projectiles (which never mask layer 16) pass over obstacles unchanged
- The eager `@onready` guard in `configure()` handles both tree-attached and non-tree cases (tests instantiate without adding to tree)
