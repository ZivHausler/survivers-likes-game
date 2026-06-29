# character-select-3d

`CharacterSelect3D` (`Control`) — entry screen for the 3D vertical slice.

Lives in `ui/character_select_3d.tscn`. Boots at project start (set as `run/main_scene` in `project.godot`).

## Flow

1. Two buttons: Ziv and Avihay (loaded from `ziv_3d.tres` / `avihay_3d.tres`).
2. Buttons are tinted by `CharacterData.color`.
3. On click: `RunState.selected_character = char_data`, then `change_scene_to_file("res://game/main_3d.tscn")`.

## Mirroring 2D

Mirrors `ui/character_select.*` exactly, but:
- Loads `ziv_3d.tres` / `avihay_3d.tres` (world-scale stats, 3D weapon scenes).
- Navigates to `main_3d.tscn` instead of `arena.tscn`.

## Manual playtest required

- Buttons appear, are readable, and tinted correctly.
- Selecting Ziv starts main_3d with Ziv's 3D weapon.
- Selecting Avihay starts main_3d with Avihay's 3D weapon.
- No errors in Output panel on scene transition.
