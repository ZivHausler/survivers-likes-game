# Friends Swarm — Knowledge Base Index

Map of all design notes, architecture decisions, and runbooks.
Add new notes here as they are created; link by `[[id]]`.

---

## Systems

- [[game-events]] — Global signal bus (`GameEvents` autoload)
- [[run-state]] — Cross-scene run persistence (`RunState` autoload)
- [[data-driven-characters]] — How a friend is modelled as `CharacterData` + weapon + passive + evolution
- [[stat-block]] — `StatBlock` resource: all numeric stats for a character/enemy
- [[character-data]] — `CharacterData` resource: complete friend definition (stats, weapon, passive, evolution)
- [[weapon-system]] — `Weapon` base class: self-driving timer, lifecycle contract, subclass pattern
- [[player]] — `Player` (`CharacterBody2D`): WASD movement, HP, XP, leveling, weapon spawn

## Concepts

- [[data-driven-characters]] — Data-driven character roster

## Decisions

- [[adr-godot]] — Why Godot 4 was chosen
- [[adr-data-driven-roster]] — Why characters are data (not code) driven

## Runbooks

_None yet — add operational procedures here as needed._
