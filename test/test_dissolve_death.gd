# See docs/notes/enemy-3d.md
extends GutTest
## Verifies the dissolve-death shader contract:
##   - shaders/dissolve_death.gdshader loads as a Shader resource
##   - A ShaderMaterial with that shader accepts the progress (float) and
##     edge_color (Color) uniforms defined in the shader contract.
## These tests will be RED until shaders/dissolve_death.gdshader exists.

func test_dissolve_death_shader_loads() -> void:
	var shader := load("res://shaders/dissolve_death.gdshader") as Shader
	assert_not_null(shader, "shaders/dissolve_death.gdshader must exist and load as Shader")

func test_dissolve_death_material_accepts_progress() -> void:
	var shader := load("res://shaders/dissolve_death.gdshader") as Shader
	assert_not_null(shader, "shader must load before testing uniforms")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("progress", 0.5)
	assert_almost_eq(float(mat.get_shader_parameter("progress")), 0.5, 0.001,
			"progress uniform must round-trip through ShaderMaterial")

func test_dissolve_death_material_accepts_edge_color() -> void:
	var shader := load("res://shaders/dissolve_death.gdshader") as Shader
	assert_not_null(shader, "shader must load before testing uniforms")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var col := Color(1.0, 0.2, 0.6, 1.0)
	mat.set_shader_parameter("edge_color", col)
	var got: Color = mat.get_shader_parameter("edge_color")
	assert_eq(got, col, "edge_color uniform must round-trip through ShaderMaterial")
