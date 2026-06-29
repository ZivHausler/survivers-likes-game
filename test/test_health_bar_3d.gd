extends GutTest
## Unit tests for the world-space mini-boss HealthBar3D.

func test_compute_fill_scale_clamps_high() -> void:
	assert_eq(HealthBar3D.compute_fill_scale(1.5), 1.0, "ratio above 1 clamps to 1.0")

func test_compute_fill_scale_clamps_low() -> void:
	assert_eq(HealthBar3D.compute_fill_scale(-0.3), 0.0, "negative ratio clamps to 0.0")

func test_compute_fill_scale_passthrough() -> void:
	assert_almost_eq(HealthBar3D.compute_fill_scale(0.5), 0.5, 0.001, "mid ratio passes through")

func test_set_ratio_updates_fill_pivot_scale() -> void:
	var bar: HealthBar3D = add_child_autofree(HealthBar3D.new())
	bar.set_ratio(0.25)
	assert_almost_eq(bar._fill_pivot.scale.x, 0.25, 0.001, "fill pivot x-scale tracks ratio")

func test_set_ratio_full_is_one() -> void:
	var bar: HealthBar3D = add_child_autofree(HealthBar3D.new())
	bar.set_ratio(1.0)
	assert_almost_eq(bar._fill_pivot.scale.x, 1.0, 0.001, "full HP → full-width fill")

func test_builds_background_and_fill_children() -> void:
	var bar: HealthBar3D = add_child_autofree(HealthBar3D.new())
	assert_not_null(bar._bg, "background quad must be built")
	assert_not_null(bar._fill, "fill quad must be built")
