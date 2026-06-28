# arena-3d

`arena/arena_3d.tscn` — the 3D gameplay arena, introduced in Task 1.1 alongside the existing 2D `arena/arena.tscn` (which is NOT deleted).

## Scene hierarchy

```
Arena3D (Node3D)
├── Ground (StaticBody3D)  — collision_layer=1
│   ├── GroundMesh (MeshInstance3D)  — PlaneMesh 200×200
│   └── GroundCollision (CollisionShape3D)  — thin BoxShape3D
├── DirectionalLight3D  — angled ~60° from above, shadows on
└── WorldEnvironment  — solid dark-grey bg + ambient colour light
```

## Design notes

- **Gameplay plane**: XZ (Y is up). Ground sits at Y=0.
- **Ground size**: 200×200 units — large enough that the camera never shows the edge during a normal run.
- **Collision layer**: 1 (same as 2D convention so future physics queries stay consistent).
- **Lighting**: A single `DirectionalLight3D` angled to cast clear shadows under the –55° camera. `WorldEnvironment` provides ambient fill so shadowed areas are not pitch black.
- **No sky resource**: Uses a solid background colour to keep load simple and avoid skybox asset dependency.
