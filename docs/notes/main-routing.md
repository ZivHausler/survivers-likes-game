# main-routing

`game/main.gd` / `game/main.tscn` — entry routing scene

## Responsibilities

`main.tscn` is the project's main scene (set in `project.godot`).  Its only job
is to bounce to the character-select screen so the rest of the flow can begin.

`main.gd._ready()` calls
`get_tree().change_scene_to_file.call_deferred("res://ui/character_select.tscn")`.

The `call_deferred` is required: calling `change_scene_to_file` synchronously
during `_ready` errors with "Parent node is busy adding/removing children".

## Character select (`ui/character_select.gd` / `.tscn`)

`CharacterSelect` (Control) shows one button per playable character, each tinted
by that character's `CharacterData.color`.  On click it sets
`RunState.selected_character = load(path)` and `change_scene_to_file` to the
arena.  Adding a character means adding a button + load path here — see
[[how-to-add-a-character]].

## Scene flow

```
main.tscn  →  character_select.tscn  →  arena.tscn  →  game_over.tscn
                                            ↑                  │
                                            └──── Retry ───────┘
                                            ↑
                            Character Select (from game over)
```

Related: [[game-manager]] (owns the run inside arena.tscn),
[[game-over]] (routes back to arena/select), [[how-to-add-a-character]]
(character select wiring).
