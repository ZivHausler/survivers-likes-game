# See docs/notes/water-3d.md
class_name Water3D extends StaticBody3D
## Decorative water pond that also blocks movement: a flat surface mesh plus a
## cylindrical collision footprint on the Obstacles layer (16) and a matching
## NavigationObstacle3D so the swarm routes around it. No fluid simulation.
