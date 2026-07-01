# See docs/notes/stylize-layer.md
extends GutTest

func test_cel_rim_loads():
	var s := load("res://shaders/cel_rim.gdshader")
	assert_not_null(s)
	var m := ShaderMaterial.new(); m.shader = s
	assert_eq(m.shader, s)
