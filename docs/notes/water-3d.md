# Water3D

`Water3D` (`StaticBody3D`) is a decorative pond that also blocks movement. A flat `PlaneMesh` (24×24 units) with a translucent blue `StandardMaterial3D` provides the visual; a `CylinderShape3D` (radius=12, height=2) on Obstacles layer 16 prevents the player and enemies from walking into the pond; a `NavigationObstacle3D` (radius=12) instructs the RVO system to route the swarm around it. No fluid simulation — a StandardMaterial3D with `transparency=1` and low roughness is sufficient for v1.
