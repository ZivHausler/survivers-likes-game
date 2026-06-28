---
id: adr-godot
title: "ADR: Choose Godot 4 as Engine"
tags: [adr, engine, godot]
links: [adr-data-driven-roster, data-driven-characters]
---

# ADR: Choose Godot 4 as Engine

## Status
Accepted

## Context

Friends Swarm is a 2-D bullet-heaven / auto-battler. We need an engine that
supports fast iteration on gameplay systems, a clean signal/node model for
decoupling systems, and first-class GDScript for rapid prototyping with the
option to drop to C++ (GDExtension) later.

## Decision

Use **Godot 4.7** (stable) as the game engine.

## Rationale

- **Free and open-source** — no royalties, no seat licences, source available.
- **Node/Signal model** — maps directly onto our event-bus design (see [[game-events]]). Systems decouple through `GameEvents` rather than direct references.
- **GDScript 2.0** — typed, fast for iteration; close to Python syntax the team knows.
- **Small binary / fast iteration** — `godot --headless` lets CI run tests without a display.
- **GUT** — mature unit-test framework (Godot Unit Test) integrates as an addon.
- **2-D renderer** — Polygon2D + GPU particles handle our top-down visual style well.

## Consequences

- Team must learn GDScript (low ramp-up given Python familiarity).
- Export pipeline is non-trivial for consoles, but web/desktop covers our targets.
- All character data modelled as `Resource` subclasses — see [[adr-data-driven-roster]].
