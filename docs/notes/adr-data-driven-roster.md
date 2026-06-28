---
id: adr-data-driven-roster
title: "ADR: Data-Driven Character Roster"
tags: [adr, characters, data-driven, resource]
links: [adr-godot, data-driven-characters]
---

# ADR: Data-Driven Character Roster

## Status
Accepted

## Context

Friends Swarm will ship with multiple playable "friends" (characters), each
with a unique starting weapon, passive stat bonus, and evolution path. We need
a way to add and balance characters without touching game code.

## Decision

Represent every playable character as a Godot `Resource` subclass (`CharacterData`).
Characters are `.tres` files — pure data, no behaviour code.

## Rationale

- **Designer-editable** — `.tres` files can be edited in the Godot Inspector; no code
  changes required to tweak HP or weapon assignments.
- **Type-safe** — `CharacterData` enforces a schema via `@export` annotations; the
  editor validates values at author-time.
- **Serialisable** — `Resource.save/load` round-trips cleanly; useful for save-state
  and run preview (see [[run-state]]).
- **Decoupled** — `RunState.selected_character` holds a `Resource` reference; the
  character scene and weapon scene are loaded from paths stored on it (see [[data-driven-characters]]).
- **Extensible** — adding a new character = creating a `.tres`, no new GDScript class.

## Consequences

- `CharacterData` resource class must be defined before any character `.tres` can exist.
- Weapon scenes must also be data-referenced (path on `CharacterData`) not hard-coded.
- See [[data-driven-characters]] for full field spec.
