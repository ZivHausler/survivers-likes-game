# See docs/notes/run-state.md
extends Node
## Survives scene changes: which character was picked, last run's score.

var selected_character: Resource = null  # CharacterData
var last_run := {"time": 0.0, "kills": 0}
var party: Dictionary = {}  # peer_id:int -> fighter CharacterData .tres path; set by SessionRoot.enter_arena
