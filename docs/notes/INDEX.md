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
- [[upgrade-system]] — `UpgradeSystem`: pool generation, `build_choices`, `apply`, level tracking
- [[player]] — `Player` (`CharacterBody2D`): WASD movement, HP, XP, leveling, weapon spawn
- [[enemy]] — `Enemy` (`CharacterBody2D`): steering, contact damage, death; `EnemyData` variants (swarmer, tank, spitter)
- [[difficulty-timeline]] — `DifficultyTimeline` (`RefCounted`): spawn interval curve, variant thresholds, 300 s boss windows
- [[spawner]] — `Spawner` (`Node2D`): ring spawner driven by `DifficultyTimeline`; mini-boss on boss_due
- [[xp-gem]] — `XPGem` (`Area2D`): magnet pickup that awards XP and emits `xp_collected`

## Concepts

- [[data-driven-characters]] — Data-driven character roster
- [[evolution-rule]] — Exact condition that unlocks the evolution upgrade (signature maxed + passive owned + not yet evolved)

## Decisions

- [[adr-godot]] — Why Godot 4 was chosen
- [[adr-data-driven-roster]] — Why characters are data (not code) driven

## Runbooks

_None yet — add operational procedures here as needed._
