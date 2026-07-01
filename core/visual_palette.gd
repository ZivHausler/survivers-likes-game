# See docs/notes/visual-palette.md
extends Node

const ROLES := {
	&"player_primary": Color(0.3, 0.8, 1.0),
	&"player_secondary": Color(1.0, 0.8, 0.2),
	&"enemy_primary": Color(0.6, 0.3, 1.0),
	&"enemy_secondary": Color(1.0, 0.2, 0.6),
	&"danger": Color(1.0, 0.35, 0.1),
	&"pickup_low": Color(0.3, 0.6, 1.0),
	&"pickup_mid": Color(0.3, 1.0, 0.4),
	&"pickup_high": Color(1.0, 0.9, 0.2),
	&"pickup_higher": Color(1.0, 0.55, 0.1),
	&"pickup_top": Color(1.0, 0.2, 0.6),
	&"env_neutral": Color(0.45, 0.47, 0.5),
}

func role(name: StringName) -> Color:
	return ROLES.get(name, Color.MAGENTA)
