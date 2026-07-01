# See docs/notes/visual-palette.md
extends GutTest

func test_role_returns_known_color():
	assert_eq(VisualPalette.role(&"player_primary"), Color(0.3,0.8,1.0))

func test_unknown_role_returns_magenta_sentinel():
	assert_eq(VisualPalette.role(&"nope"), Color.MAGENTA)
