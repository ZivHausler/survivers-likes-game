extends GutTest
var _safeA := Vector3.ZERO
func _vcA(v: Vector3) -> void: _safeA = v
func _mk(pos: Vector3) -> NavigationAgent3D:
    var a := NavigationAgent3D.new(); a.avoidance_enabled=true; a.radius=1.0; a.max_speed=12.0
    a.neighbor_distance = 50.0
    var b := CharacterBody3D.new(); b.add_child(a); add_child_autofree(b); b.global_position=pos
    return a
func test_two_agents() -> void:
    var A: NavigationAgent3D = _mk(Vector3(0,0,0))
    var B: NavigationAgent3D = _mk(Vector3(4,0,0))
    A.velocity_computed.connect(_vcA)
    await get_tree().physics_frame
    NavigationServer3D.map_set_active(A.get_navigation_map(), true)
    for i in range(10):
        A.set_velocity(Vector3(6,0,0))
        B.set_velocity(Vector3(-6,0,0))
        await get_tree().physics_frame
        if i>=5: gut.p("frame %d  A.safe=%s" % [i, str(_safeA)])
    assert_true(true)
