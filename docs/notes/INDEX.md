# Friends Swarm — Knowledge Base Index

Map of all design notes, architecture decisions, and runbooks.
Add new notes here as they are created; link by `[[id]]`.

---

## 3D Vertical Slice (Task 1.x)

- [[game-camera-3d]] — `GameCamera3D`: tilted perspective Camera3D, follows target on XZ; pure static helpers for unit testing
- [[arena-3d]] — `arena_3d.tscn`: 3D ground plane (200×200), DirectionalLight3D, WorldEnvironment; gameplay plane = XZ
- [[player-3d]] — `Player3D` (`CharacterBody3D`): WASD on XZ, HP/XP/level/stat logic; multi-weapon `weapons` dict (skill_id→Weapon3D) + `acquire_skill/level_skill/apply_skill_passive/evolve_skill`; `fire_rate` refreshes all weapons; legacy single-weapon fallback when `skills` empty; post-levelup i-frames via `set_invulnerable(duration)` / `is_invulnerable()` + model blink
- [[enemy-3d]] — `Enemy3D` (`CharacterBody3D`): steering/charm/contact-damage/death; real monster GLB models (bug/plant/diatryma/serpent); `face_angle()` rotation; best-effort animation; emits `enemy_killed_3d`
- [[weapon-system-3d]] — `Weapon3D` base class: Node3D port of Weapon; same timer/cooldown/level/evolve contract; 1 unit ≈ 16 px
- [[weapon-ziv-3d]] — `ZivStunningLooks3D`: 3D beam (Area3D BoxShape) + XZ charm sorting; evolve = Y-rotation + always-on CharmField
- [[weapon-avihay-3d]] — `AvihayChatSpam3D` + `Bubble3D`: XZ directional bubble spread, pierce, homing on evolve; SPEED=14 units/s
- [[spawner-3d]] — `Spawner3D` (`Node3D`): ring spawner driven by DifficultyTimeline; bosses use serpent model with texture-preserving tint; pure static helpers for testability; `xp_time_mult` scales normal-enemy XP with elapsed time (+100% per 2 min)
- [[obstacle-3d]] — reusable collidable map prop (trees, rocks, water); `StaticBody3D` on layer 16 with `NavigationObstacle3D` for RVO avoidance; `configure()` (single Mesh) + `set_model()` (multi-mesh gltf scene as child visual) APIs to assign the visual and size the footprint
- [[arena-scatter]] — `ArenaScatter`: static `compute_positions()` (deterministic seeded rejection-sampling placement on XZ; respects extent/clear-radius/min-separation) + instance-side `_ready` spawner that scatters real CC0 tree/rock gltf props as `Obstacle3D`s under an `Obstacles` node (exported tunable params; BoxMesh fallback on load failure)
- [[arena-map]] — `arena_3d.tscn`: realistic arena map — PBR grass ground (Poly Haven aerial_grass_rock CC0), HDRI mountain sky (Poly Haven kloofendal_43d_clear_puresky CC0); border walls, water ponds, and seeded collidable tree/rock prop scatter (CC0 fir_tree_01 + boulder_01)
- [[water-3d]] — `Water3D`: decorative pond that blocks movement; translucent `PlaneMesh` surface + `CylinderShape3D` on Obstacles layer 16 + `NavigationObstacle3D` so swarm routes around it; no fluid sim (StandardMaterial3D only)
- [[xp-gem-3d]] — `XPGem3D` (`Area3D`): magnet pickup (XZ plane) that awards XP; orb color reflects XP tier via `tier_color()` (blue→green→yellow→orange→magenta); `magnet_step` static helper
- [[game-manager-3d]] — `GameManager3D` (`Node`): full 3D run loop — CharacterData setup, SkillSystem (or legacy UpgradeSystem), level-up queue, routing via `_route_skill_upgrade` (SKILL/PASSIVE/SYNERGY/GENERIC) or `_apply_upgrade` (legacy), death → game_over; grants `LEVELUP_INVULN` (2.0 s) to player on final level-up resolution
- [[character-select-3d]] — `CharacterSelect3D` (`Control`): 3D entry screen; data-driven list of all 10 friends (CHARACTER_PATHS const, one Button per CharacterData, tinted by color, ScrollContainer/GridContainer so all 10 fit); sets RunState then → main_3d.tscn; boots at project start

## Task 2 — Ranged & Dasher Enemies

- [[enemy-projectile-3d]] — `EnemyProjectile3D` (`Area3D`): traveling enemy attack fired by ranged enemies; moves along XZ direction, damages player hurtbox on contact, despawns on terrain (layer 16) for cover mechanic; lifetime cap = 6s
- [[enemy-attacks]] — `EnemyAttack` (`RefCounted`) strategy base: `desired_velocity()` + `attack_tick()` (no-ops in base); `Enemy3D._attack` is null for MELEE (inline default path) and set via `_make_attack()` for RANGED/DASHER; melee chase + CONTACT_RANGE contact-damage stays byte-identical in the `else` branch

## 3D Characters (Phase 5 — all 10 friends)

- [[char-avinoam]] — Avinoam "Divine Smite": holy/gold, NovaWeapon3D signature (Holy Smite), OrbitWeapon3D (Smite Orbs), Radiant Pulse, Judgment; model character-c.glb
- [[char-matan]] — Matan "Debug Mode": tech/cyan, signature (Debug Pulse Nova), Null Pointer Orbit, Stack Overflow Nova, Infinite Loop Nova; model character-b.glb
- [[char-ido]] — Ido "Steady State": earth/green, signature (Grounding Nova), Root Network Orbit, Stone Skin passive Nova, Tectonic Pulse Nova; model character-d.glb
- [[char-yuval]] — Yuval "Deep Cut": dark-blue, signature (Deep Strike Nova), Blade Orbit, Pressure Wave Nova, Lethal Tempo Nova; model character-e.glb
- [[char-natali]] — Natali "Nature's Wrath": leaf-green, signature (Thorn Burst Nova), Seed Orbit, Bloom Pulse Nova, Overgrowth Nova; model character-f.glb
- [[char-barak]] — Barak "Thunder Strike": electric-yellow, signature (Lightning Strike Nova), Thunder Orbit, Shockwave Nova, Storm Surge Nova; model character-g.glb
- [[char-yinon]] — Yinon "Shadow Veil": purple, signature (Shadow Slash Nova), Phantom Orbit, Umbra Nova, Eclipse Nova; model character-h.glb
- [[char-yoav]] — Yoav "Iron Will": iron-gray, signature (Iron Slam Nova), Shield Orbit, Bulwark Nova, Fortress Nova; model character-i.glb

## Task 3.3 — Extra Skills (4 per character)

- [[weapon-orbit-3d]] — `OrbitWeapon3D`: reusable rotating-orbiter archetype; N Area3D hitboxes; pure `orbiter_offsets()` helper; subclasses: ZivMirrorShards3D, AvihayGroupCall3D, AvihayMassDM3D
- [[weapon-nova-3d]] — `NovaWeapon3D`: reusable AoE pulse archetype; damage + optional charm; pure `affected_enemies()` helper; subclasses: ZivSelfieFlash3D, ZivAdoringAura3D, AvihayVoiceBlast3D
- [[skills-overview-3-3]] — Full roster: Ziv (Mirror Shards, Selfie Flash, Adoring Aura) + Avihay (Group Call, Voice Blast, Mass DM); upgrade file locations; manual-playtest checklist

## Systems

- [[game-events]] — Global signal bus (`GameEvents` autoload)
- [[run-state]] — Cross-scene run persistence (`RunState` autoload)
- [[visual-palette]] — League of Legends: Swarm color palette (`VisualPalette` autoload)
- [[stylize-layer]] — `cel_rim.gdshader`: cel+rim+emissive spatial shader; uniform contract for Task 1.3 Stylize autoload
- [[juice]] — `Juice` autoload: decoupled visual-effects layer (connects to GameEvents; enemy_killed + hp_changed filled in Wave C / Task C1)
- [[juice-3d]] — `Juice3D` autoload: 3D companion to Juice; DeathPop3D, DamageNumber3D, HitFlash3D, camera shake via GameCamera3D.add_trauma (Task 1.6)
- [[skill-vfx]] — `SkillVFX` autoload: decoupled skill cast/hit VFX layer; `skill_cast`/`skill_hit` signals; SkillCastFx3D + SkillHitFx3D GPUParticles3D; per-archetype color defaults (Task 4.5)
- [[aoe-telegraph]] — `AoeTelegraph3D`: flat additive ring decal on the XZ ground plane; expands/pulses then auto-frees; dispatched by SkillVFX on every `skill_cast` for LoL Swarm ground readability (Task 1.6)
- [[vfx-system]] — Wave C VFX scenes: ScreenShake, HitFlash, DamageNumber, DeathPop, EvolutionFlash (C2), XpSparkle (C2)
- [[sprite-integration]] — Optional sprite fields on `CharacterData`/`EnemyData` + fallback rule (Wave A/B)
- [[data-driven-characters]] — How a friend is modelled as `CharacterData` + weapon + passive + evolution
- [[stat-block]] — `StatBlock` resource: all numeric stats for a character/enemy
- [[character-data]] — `CharacterData` resource: complete friend definition (stats, weapon, passive, evolution, 3D model/scale/tint)
- [[weapon-system]] — `Weapon` base class: self-driving timer, lifecycle contract, subclass pattern
- [[weapon-ziv]] — `ZivStunningLooks`: "Stunning Looks" beam + charm; evolution "Absolutely Fabulous"
- [[weapon-avihay]] — `AvihayChatSpam`: "Chat Spam" homing bubbles + pierce; evolution "Reply-All Apocalypse"
- [[upgrade-system]] — `UpgradeSystem`: pool generation, `build_choices`, `apply`, level tracking; Wave 3 router + `effect_kind/effect_value`
- [[skill-system]] — `SkillData` + `SkillSystem` (3D): 4 skills/character (Task 3.2: 1-element array for Ziv/Avihay; Task 3.3 adds remaining 3 each), level 0=not-owned, synergy rule, acquisition-detection contract; ziv_charm + avihay_spam now wired
- [[player]] — `Player` (`CharacterBody2D`): WASD movement, HP, XP, leveling, weapon spawn, `apply_stat_upgrade`
- [[enemy]] — `Enemy` (`CharacterBody2D`): steering, contact damage, death; `EnemyData` variants (swarmer, tank, spitter)
- [[difficulty-timeline]] — `DifficultyTimeline` (`RefCounted`): spawn interval curve, variant thresholds, 300 s boss windows
- [[spawner]] — `Spawner` (`Node2D`): ring spawner driven by `DifficultyTimeline`; mini-boss on boss_due
- [[xp-gem]] — `XPGem` (`Area2D`): magnet pickup that awards XP and emits `xp_collected`; pulsing scale Tween added in Task B3
- [[background]] — Arena ground tile (Sprite2D, texture_repeat) + full-screen vignette shader on CanvasLayer 0
- [[main-routing]] — `main.tscn` / `main.gd` entry router + `character_select` scene flow
- [[game-manager]] — `GameManager` (`Node`): run timer, kills, XP gem spawning, level-up pause flow, upgrade-effect router
- [[upgrade-ui]] — `UpgradeUI` (`CanvasLayer`): system-agnostic (accepts UpgradeSystem or SkillSystem); 3 choices; golden EVOLUTION/SYNERGY slot; SKILL/SYNERGY KIND_COLOURS; "NEW" / "Lv X/max" / "EVOLVE" / "SYNERGY" badges
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
- [[asset-pipeline]] — External artkit tool (`C:\Users\avino\swarm\`) that produces 3D chars/props/textures; flow + the consumer contract (glb clip names `idle`/`walk` & `idle`/`move`, `model_scene` swap seam, scale/facing)

## Runbooks

- [[how-to-add-a-character]] — Add friend #3..#10: weapon, upgrades, CharacterData, register in select screen
- [[how-to-add-an-enemy]] — Add a new enemy variant: EnemyData .tres, Spawner registration, DifficultyTimeline
- [[how-to-playtest]] — Manual playtest checklist: launch → select → play → evolve → die → game over
