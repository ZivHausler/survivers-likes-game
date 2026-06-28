---
id: run-state
title: "RunState — Cross-Scene Run Persistence"
tags: [autoload, persistence, run, state]
links: [game-events, data-driven-characters, adr-data-driven-roster]
---

# RunState — Cross-Scene Run Persistence

`RunState` is an autoload singleton (`res://autoload/run_state.gd`).
It survives scene changes (character select → gameplay → game-over) and holds
the data that must be readable from multiple scenes.

## Properties

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `selected_character` | `Resource` (`CharacterData`) | `null` | Which friend the player picked |
| `last_run` | `Dictionary` | `{"time": 0.0, "kills": 0}` | Stats from the most recent run |

## Lifecycle

1. **Character select** — sets `RunState.selected_character` before changing scene.
2. **Main game scene** — reads `selected_character`, instantiates player + weapon.
3. **On run end** — writes `last_run.time` and `last_run.kills` (listening to [[game-events]]).
4. **Game-over / main menu** — reads `last_run` to display results.

## `last_run` schema

```gdscript
{
    "time": float,   # seconds survived
    "kills": int     # total enemy_killed signals received
}
```

## Related

- [[game-events]] — `RunState` listens to `enemy_killed` to increment `last_run.kills`.
- [[data-driven-characters]] — `selected_character` is a `CharacterData` resource.
