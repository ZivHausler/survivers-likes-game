# Friends Swarm — Knowledge Base Index

Map of all design notes, architecture decisions, and runbooks.
Add new notes here as they are created; link by `[[id]]`.

---

## 3D Vertical Slice (Task 1.x)

- [[game-camera-3d]] — `GameCamera3D`: tilted perspective Camera3D, follows target on XZ; pure static helpers for unit testing
- [[arena-3d]] — `arena_3d.tscn`: 3D ground plane (200×200), DirectionalLight3D, WorldEnvironment; gameplay plane = XZ

## Systems

- [[game-events]] — Global signal bus (`GameEvents` autoload)
- [[run-state]] — Cross-scene run persistence (`RunState` autoload)
- [[juice]] — `Juice` autoload: decoupled visual-effects layer (connects to GameEvents; enemy_killed + hp_changed filled in Wave C / Task C1)
- [[vfx-system]] — Wave C VFX scenes: ScreenShake, HitFlash, DamageNumber, DeathPop, EvolutionFlash (C2), XpSparkle (C2)
- [[sprite-integration]] — Optional sprite fields on `CharacterData`/`EnemyData` + fallback rule (Wave A/B)
- [[data-driven-characters]] — How a friend is modelled as `CharacterData` + weapon + passive + evolution
- [[stat-block]] — `StatBlock` resource: all numeric stats for a character/enemy
- [[character-data]] — `CharacterData` resource: complete friend definition (stats, weapon, passive, evolution)
- [[weapon-system]] — `Weapon` base class: self-driving timer, lifecycle contract, subclass pattern
- [[weapon-ziv]] — `ZivStunningLooks`: "Stunning Looks" beam + charm; evolution "Absolutely Fabulous"
- [[weapon-avihay]] — `AvihayChatSpam`: "Chat Spam" homing bubbles + pierce; evolution "Reply-All Apocalypse"
- [[upgrade-system]] — `UpgradeSystem`: pool generation, `build_choices`, `apply`, level tracking; Wave 3 router + `effect_kind/effect_value`
- [[player]] — `Player` (`CharacterBody2D`): WASD movement, HP, XP, leveling, weapon spawn, `apply_stat_upgrade`
- [[enemy]] — `Enemy` (`CharacterBody2D`): steering, contact damage, death; `EnemyData` variants (swarmer, tank, spitter)
- [[difficulty-timeline]] — `DifficultyTimeline` (`RefCounted`): spawn interval curve, variant thresholds, 300 s boss windows
- [[spawner]] — `Spawner` (`Node2D`): ring spawner driven by `DifficultyTimeline`; mini-boss on boss_due
- [[xp-gem]] — `XPGem` (`Area2D`): magnet pickup that awards XP and emits `xp_collected`; pulsing scale Tween added in Task B3
- [[background]] — Arena ground tile (Sprite2D, texture_repeat) + full-screen vignette shader on CanvasLayer 0
- [[main-routing]] — `main.tscn` / `main.gd` entry router + `character_select` scene flow
- [[game-manager]] — `GameManager` (`Node`): run timer, kills, XP gem spawning, level-up pause flow, upgrade-effect router
- [[upgrade-ui]] — `UpgradeUI` (`CanvasLayer`): level-up overlay with 3 choices; golden EVOLUTION slot
- [[hud]] — `HUD` (`CanvasLayer`): timer, HP bar, XP bar + level, kill counter
- [[game-over]] — `GameOver` (`Control`): end-of-run screen with score + retry/select buttons

## Concepts

- [[data-driven-characters]] — Data-driven character roster
- [[evolution-rule]] — Exact condition that unlocks the evolution upgrade (signature maxed + passive owned + not yet evolved)

## Decisions

- [[adr-godot]] — Why Godot 4 was chosen
- [[adr-data-driven-roster]] — Why characters are data (not code) driven

## Assets

- [[asset-licenses]] — Asset license table: Kenney CC0 packs + MIT VFX library; CREDITS for haowg/GODOT-VFX-LIBRARY

## Runbooks

- [[how-to-add-a-character]] — Add friend #3..#10: weapon, upgrades, CharacterData, register in select screen
- [[how-to-add-an-enemy]] — Add a new enemy variant: EnemyData .tres, Spawner registration, DifficultyTimeline
- [[how-to-playtest]] — Manual playtest checklist: launch → select → play → evolve → die → game over
