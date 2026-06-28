# Friends Swarm v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable Godot 4 horde-survivor vertical slice with two characters (Ziv, Avihay), full upgrade + synergy/evolution system, and a maintained Zettelkasten knowledge base.

**Architecture:** Data-driven. A shared `Player` carries an equipped `Weapon` (base-class interface) defined per-character by a `CharacterData` resource. Systems communicate through a `GameEvents` autoload signal bus so they stay decoupled and independently testable. Pure logic (upgrade pool + evolution rule, difficulty timeline) is extracted into plain `RefCounted` classes with GUT unit tests; scene/feel tasks are verified by manual playtest.

**Tech Stack:** Godot 4.3+, GDScript, GUT (Godot Unit Test) addon for logic tests.

## Global Constraints

- **Engine:** Godot 4.3 or newer; GDScript only.
- **Project layout root:** `res://` maps to repo root `~/friends-swarm/`.
- **Event bus:** cross-system communication goes through the `GameEvents` autoload — systems do not hold direct references to each other except parent→child wiring.
- **Groups:** enemies are in group `"enemies"`, the player is in group `"player"`. Damage is dealt by calling `take_damage(amount: float)` on a node in the relevant group.
- **Knowledge base (HARD RULE):** every task that creates or changes a component MUST create/update its note in `docs/notes/` and add it to `docs/notes/INDEX.md` in the same commit. Every GDScript file's first line is a comment `# See docs/notes/<note-id>.md`. A task is not done until its note is current.
- **Placeholder art:** colored `ColorRect`/`Polygon2D`/simple shapes only in v1. No art dependencies.
- **Commits:** frequent, conventional-commit style, end every commit message with the Co-Authored-By trailer used in this repo.

## File Structure

```
res://
├── project.godot
├── addons/gut/                      # testing addon
├── autoload/
│   ├── game_events.gd               # signal bus (autoload "GameEvents")
│   └── run_state.gd                 # autoload "RunState": selected character, last score
├── core/
│   ├── stat_block.gd                # Resource: tunable stats
│   ├── character_data.gd            # Resource: one friend = data
│   └── weapon.gd                    # base class for all signature abilities
├── player/
│   ├── player.gd
│   └── player.tscn
├── enemies/
│   ├── enemy.gd                     # base
│   ├── enemy.tscn
│   ├── swarmer.tres / tank.tres / spitter.tres   # EnemyData variants
│   └── enemy_data.gd                # Resource: per-variant stats
├── spawning/
│   ├── difficulty_timeline.gd       # pure logic (RefCounted)
│   └── spawner.gd / spawner.tscn
├── pickups/
│   ├── xp_gem.gd / xp_gem.tscn
├── weapons/
│   ├── ziv_stunning_looks.gd / .tscn
│   └── avihay_chat_spam.gd / .tscn
├── upgrades/
│   ├── upgrade.gd                   # Resource: one upgrade definition
│   ├── upgrade_system.gd            # pure logic (RefCounted): pool + evolution rule
│   └── upgrade_ui.gd / upgrade_ui.tscn
├── characters/
│   ├── ziv.tres / avihay.tres       # CharacterData instances
├── ui/
│   ├── hud.gd / hud.tscn
│   ├── character_select.gd / .tscn
│   └── game_over.gd / .tscn
├── game/
│   ├── game_manager.gd
│   ├── arena.tscn                   # the run scene
│   └── main.tscn                    # entry: routes select → arena → game over
├── test/                            # GUT tests
│   ├── test_upgrade_system.gd
│   └── test_difficulty_timeline.gd
└── docs/notes/                      # Zettelkasten
    ├── INDEX.md
    └── *.md
```

---

## Agent Execution Strategy (waves)

The orchestrator (main session) dispatches one fresh subagent per task and reviews between tasks. Tasks in the same wave touch **disjoint files** and may run in parallel; later waves depend on the interface contracts published by earlier ones.

- **Wave 0 — Foundation (sequential, 1 agent, gates everything):** Task 0.1, Task 0.2. Establishes project + shared contracts (`GameEvents`, `StatBlock`, `CharacterData`, `Weapon`) and the knowledge-base skeleton. Nothing else starts until this is reviewed and merged.
- **Wave 1 — Independent core (parallel, 3 agents):** Task 1A Player · Task 1B Enemy · Task 1C UpgradeSystem (pure logic). Each owns its own folder; all depend only on Wave 0 contracts.
- **Wave 2 — Built on Wave 1 (parallel, 4 agents):** Task 2A Spawner+timeline (needs Enemy) · Task 2B XPGem (needs Player) · Task 2C Ziv weapon · Task 2D Avihay weapon (both need Weapon base + Enemy).
- **Wave 3 — Integration (sequential, 1 agent — owns `arena.tscn`/`main.tscn`/GameManager to avoid scene-merge conflicts):** Task 3.1 GameManager · Task 3.2 UpgradeUI · Task 3.3 HUD + Game Over · Task 3.4 CharacterData + character select · Task 3.5 Arena assembly + difficulty/mini-boss + full playtest + runbook notes.

Collision rule: only Wave 3 edits `arena.tscn`, `main.tscn`, and `game_manager.gd`. Wave 1/2 agents never touch shared scenes; they deliver self-contained scenes the integrator instances.

---

## Task 0.1: Project scaffold + knowledge base skeleton

**Files:**
- Create: `project.godot`, `addons/gut/` (install GUT), `autoload/game_events.gd`, `autoload/run_state.gd`
- Create: `docs/notes/INDEX.md`, `docs/notes/adr-godot.md`, `docs/notes/adr-data-driven-roster.md`, `docs/notes/data-driven-characters.md`
- Create: `.gitignore` (Godot)

**Interfaces:**
- Produces: autoload `GameEvents` with signals — `signal enemy_killed(position: Vector2, xp_value: int)`, `signal xp_collected(amount: int)`, `signal player_leveled_up(level: int)`, `signal player_hp_changed(current: float, max: float)`, `signal player_died()`, `signal evolution_unlocked(weapon_id: StringName)`.
- Produces: autoload `RunState` with `var selected_character: CharacterData` and `var last_run := {"time": 0.0, "kills": 0}`.

- [ ] **Step 1: Create the Godot project** — make `project.godot` with name "Friends Swarm", set main scene to `res://game/main.tscn` (created later), register autoloads `GameEvents=res://autoload/game_events.gd` and `RunState=res://autoload/run_state.gd`. Add a Godot `.gitignore` (`.godot/`, `*.import`, `export_presets.cfg`).

- [ ] **Step 2: Install GUT** — add the GUT addon under `addons/gut/`, enable it in `project.godot`. Create `test/` and a placeholder `test/.gdignore`-free folder.

- [ ] **Step 3: Write `autoload/game_events.gd`**

```gdscript
# See docs/notes/game-events.md
extends Node
## Global signal bus. Systems emit/connect here instead of referencing each other.

signal enemy_killed(position: Vector2, xp_value: int)
signal xp_collected(amount: int)
signal player_leveled_up(level: int)
signal player_hp_changed(current: float, max_hp: float)
signal player_died()
signal evolution_unlocked(weapon_id: StringName)
```

- [ ] **Step 4: Write `autoload/run_state.gd`**

```gdscript
# See docs/notes/run-state.md
extends Node
## Survives scene changes: which character was picked, last run's score.

var selected_character: Resource = null  # CharacterData
var last_run := {"time": 0.0, "kills": 0}
```

- [ ] **Step 5: Write the knowledge-base skeleton** — create `docs/notes/INDEX.md` (map of content with sections: Systems / Concepts / Decisions / Runbooks, each linking notes as they appear). Write `adr-godot.md` (why Godot), `adr-data-driven-roster.md` (why characters are data), `data-driven-characters.md` (how a friend = `CharacterData` + weapon scene + passive + evolution), `game-events.md`, `run-state.md`. Each note has frontmatter (`id`, `title`, `tags`, `links`) and links related notes via `[[id]]`.

- [ ] **Step 6: Open the project once to verify it boots** — Run: `godot --headless --quit` in the project root. Expected: exits 0, no autoload parse errors.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: scaffold Godot project, event bus, and knowledge base"
```

---

## Task 0.2: Core data contracts (StatBlock, CharacterData, Weapon base)

**Files:**
- Create: `core/stat_block.gd`, `core/character_data.gd`, `core/weapon.gd`
- Create notes: `docs/notes/stat-block.md`, `docs/notes/character-data.md`, `docs/notes/weapon-system.md`

**Interfaces:**
- Produces `StatBlock` (Resource): `@export` floats `max_hp=100`, `move_speed=120`, `pickup_range=48`, `damage_mult=1.0`, `fire_rate_mult=1.0`, `armor=0.0`; method `duplicate_stats() -> StatBlock`.
- Produces `CharacterData` (Resource): `@export` `id: StringName`, `display_name: String`, `color: Color`, `base_stats: StatBlock`, `weapon_scene: PackedScene`, `passive_id: StringName`, `evolution_id: StringName`, `max_signature_level: int = 5`.
- Produces `Weapon` (base, `class_name Weapon extends Node2D`): `var level := 1`, `var stats: StatBlock`, methods `setup(player: Node, stats: StatBlock) -> void`, `fire() -> void` (override), `level_up() -> void`, `evolve() -> void` (override), `is_max_level(max_level: int) -> bool`. Drives its own `Timer` whose wait time = `base_cooldown / stats.fire_rate_mult`.

- [ ] **Step 1: Write `core/stat_block.gd`**

```gdscript
# See docs/notes/stat-block.md
class_name StatBlock extends Resource

@export var max_hp: float = 100.0
@export var move_speed: float = 120.0
@export var pickup_range: float = 48.0
@export var damage_mult: float = 1.0
@export var fire_rate_mult: float = 1.0
@export var armor: float = 0.0

func duplicate_stats() -> StatBlock:
    return duplicate(true) as StatBlock
```

- [ ] **Step 2: Write `core/character_data.gd`**

```gdscript
# See docs/notes/character-data.md
class_name CharacterData extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var color: Color = Color.WHITE          # placeholder art tint
@export var base_stats: StatBlock
@export var weapon_scene: PackedScene
@export var passive_id: StringName               # dedicated passive's id
@export var evolution_id: StringName             # evolved ability id
@export var max_signature_level: int = 5
```

- [ ] **Step 3: Write `core/weapon.gd`**

```gdscript
# See docs/notes/weapon-system.md
class_name Weapon extends Node2D
## Base class for every signature ability. Subclasses override fire() and evolve().

var level: int = 1
var stats: StatBlock
var evolved: bool = false
var base_cooldown: float = 1.0   # subclass sets in _ready before timer starts

@onready var _timer: Timer = Timer.new()

func setup(_player: Node, p_stats: StatBlock) -> void:
    stats = p_stats

func _ready() -> void:
    add_child(_timer)
    _timer.timeout.connect(fire)
    _timer.wait_time = max(0.05, base_cooldown / stats.fire_rate_mult)
    _timer.start()

func fire() -> void:
    pass  # override

func level_up() -> void:
    level += 1
    _refresh_cooldown()

func evolve() -> void:
    evolved = true  # override to swap behavior, then call super or _refresh_cooldown()

func is_max_level(max_level: int) -> bool:
    return level >= max_level

func _refresh_cooldown() -> void:
    _timer.wait_time = max(0.05, base_cooldown / stats.fire_rate_mult)
```

- [ ] **Step 4: Verify it parses** — Run: `godot --headless --quit`. Expected: exits 0, classes register (no "Could not resolve class" errors).

- [ ] **Step 5: Write the three notes** — `stat-block.md`, `character-data.md`, `weapon-system.md` (each: purpose, the exported fields / API above, file path, links to `[[data-driven-characters]]`). Add all three to `INDEX.md`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: core data contracts (StatBlock, CharacterData, Weapon)"
```

---

## Task 1A: Player (movement, HP, XP, leveling)

**Files:**
- Create: `player/player.gd`, `player/player.tscn`
- Create note: `docs/notes/player.md`

**Interfaces:**
- Consumes: `GameEvents`, `StatBlock`, `Weapon`.
- Produces `Player` (`CharacterBody2D`): `func setup(data: CharacterData) -> void` (applies stats, instances `data.weapon_scene` as child, calls `weapon.setup`), `var weapon: Weapon`, `var level: int`, `func add_xp(amount: int) -> void`, `func take_damage(amount: float) -> void`, `var pickup_range: float` (read by XPGem). Emits via `GameEvents`: `player_hp_changed`, `player_leveled_up`, `player_died`. XP curve: `xp_to_next(level) = 5 + level * 5`.

- [ ] **Step 1: Build `player.tscn`** — `CharacterBody2D` (group `"player"`) with child `ColorRect` (16×16, centered, tinted from data.color), a `Camera2D`, and an `Area2D` "Hurtbox" with `CollisionShape2D`. Save scene.

- [ ] **Step 2: Write movement + the failing-by-hand checks in `player.gd`** — read input (`Input.get_vector`), `velocity = dir * stats.move_speed`, `move_and_slide()`. Apply `setup()` to instance weapon and stats. Implement `add_xp`, `xp_to_next`, level-up loop (handle multi-level), `take_damage` with armor + death emit. Emit `player_hp_changed` on setup and on damage. Full code:

```gdscript
# See docs/notes/player.md
class_name Player extends CharacterBody2D

var stats: StatBlock
var weapon: Weapon
var level: int = 1
var xp: int = 0
var hp: float = 0.0

func setup(data: CharacterData) -> void:
    stats = data.base_stats.duplicate_stats()
    hp = stats.max_hp
    ($ColorRect as ColorRect).color = data.color
    weapon = data.weapon_scene.instantiate()
    add_child(weapon)
    weapon.setup(self, stats)
    GameEvents.player_hp_changed.emit(hp, stats.max_hp)

func _physics_process(_dt: float) -> void:
    var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = dir * stats.move_speed
    move_and_slide()

func xp_to_next(lvl: int) -> int:
    return 5 + lvl * 5

func add_xp(amount: int) -> void:
    xp += amount
    while xp >= xp_to_next(level):
        xp -= xp_to_next(level)
        level += 1
        GameEvents.player_leveled_up.emit(level)

func take_damage(amount: float) -> void:
    var dealt: float = max(0.0, amount - stats.armor)
    hp -= dealt
    GameEvents.player_hp_changed.emit(hp, stats.max_hp)
    if hp <= 0.0:
        GameEvents.player_died.emit()

func get_pickup_range() -> float:
    return stats.pickup_range
```

- [ ] **Step 3: Add input actions** — in `project.godot` add `move_left/right/up/down` mapped to WASD + arrows.

- [ ] **Step 4: Manual smoke test** — make a throwaway scene with a Player + a dummy CharacterData (no weapon yet is fine: guard `if data.weapon_scene`), run, confirm WASD moves the square and camera follows. Expected: smooth movement.

- [ ] **Step 5: Write `player.md` note** — API above, signals emitted, XP curve, links `[[weapon-system]]`, `[[game-events]]`, `[[stat-block]]`. Add to INDEX.

- [ ] **Step 6: Commit** — `git commit -m "feat: player movement, HP, XP, leveling"`

---

## Task 1B: Enemy base + variants + steering

**Files:**
- Create: `enemies/enemy.gd`, `enemies/enemy.tscn`, `enemies/enemy_data.gd`, `enemies/swarmer.tres`, `enemies/tank.tres`, `enemies/spitter.tres`
- Create note: `docs/notes/enemy.md`

**Interfaces:**
- Consumes: `GameEvents`.
- Produces `EnemyData` (Resource): `@export` `id`, `color: Color`, `max_hp: float`, `move_speed: float`, `contact_damage: float`, `xp_value: int`, `is_ranged: bool`, `radius: float`.
- Produces `Enemy` (`CharacterBody2D`, group `"enemies"`): `func setup(data: EnemyData, target: Node2D) -> void`, `func take_damage(amount: float) -> void`; on death emits `GameEvents.enemy_killed(global_position, data.xp_value)` and frees. Steers toward `target` each physics frame; deals `contact_damage` to player on overlap (cooldown 0.5s).

- [ ] **Step 1: Write `enemy_data.gd`** (the Resource with the exported fields above, plus `# See docs/notes/enemy.md` header).

- [ ] **Step 2: Build `enemy.tscn`** — `CharacterBody2D` (group `"enemies"`) + `ColorRect`/`Polygon2D` body + `CollisionShape2D` + an `Area2D` "ContactArea".

- [ ] **Step 3: Write `enemy.gd`** — steering toward target; ranged variant stops at distance and (v1) just does contact (projectiles optional, mark as a follow-up note); contact damage with per-enemy timer; `take_damage` → death emit. Code:

```gdscript
# See docs/notes/enemy.md
class_name Enemy extends CharacterBody2D

var data: EnemyData
var target: Node2D
var hp: float = 0.0
var _contact_cd: float = 0.0

func setup(p_data: EnemyData, p_target: Node2D) -> void:
    data = p_data
    target = p_target
    hp = data.max_hp
    ($Body as CanvasItem).modulate = data.color

func _physics_process(dt: float) -> void:
    if not is_instance_valid(target):
        return
    var to_target := target.global_position - global_position
    var dist := to_target.length()
    var desired := 0.0 if (data.is_ranged and dist < 140.0) else data.move_speed
    velocity = to_target.normalized() * desired
    move_and_slide()
    _contact_cd = max(0.0, _contact_cd - dt)
    if dist < data.radius + 12.0 and _contact_cd == 0.0 and target.has_method("take_damage"):
        target.take_damage(data.contact_damage)
        _contact_cd = 0.5

func take_damage(amount: float) -> void:
    hp -= amount
    if hp <= 0.0:
        GameEvents.enemy_killed.emit(global_position, data.xp_value)
        queue_free()
```

- [ ] **Step 4: Author the three `.tres` variants** — swarmer (fast, hp 10, dmg 4, xp 1), tank (slow, hp 80, dmg 14, xp 5), spitter (ranged, hp 20, dmg 8, xp 3). Distinct colors.

- [ ] **Step 5: Manual smoke test** — scene with a static target + 20 enemies; confirm they converge and despawn when `take_damage` kills them (call from a debug key).

- [ ] **Step 6: Write `enemy.md` note** (variants table, contract, `[[game-events]]`, `[[spawner]]`). Add to INDEX.

- [ ] **Step 7: Commit** — `git commit -m "feat: enemy base, steering, and three variants"`

---

## Task 1C: Upgrade system (pure logic) + evolution rule

**Files:**
- Create: `upgrades/upgrade.gd`, `upgrades/upgrade_system.gd`
- Create test: `test/test_upgrade_system.gd`
- Create notes: `docs/notes/upgrade-system.md`, `docs/notes/evolution-rule.md`

**Interfaces:**
- Produces `Upgrade` (Resource): `id: StringName`, `display_name: String`, `kind: int` (enum `SIGNATURE/PASSIVE/GENERIC/EVOLUTION`), `max_level: int`.
- Produces `UpgradeSystem` (`RefCounted`): constructed with `(character: CharacterData, generic_pool: Array[Upgrade], signature_upgrade: Upgrade, passive_upgrade: Upgrade, evolution_upgrade: Upgrade)`. State: `levels: Dictionary` (id→int), `evolved: bool`. Methods:
  - `build_choices(rng: RandomNumberGenerator, count := 3) -> Array[Upgrade]`
  - `evolution_available() -> bool` → `levels[signature.id] >= character.max_signature_level and levels.get(passive.id, 0) >= 1 and not evolved`
  - `apply(u: Upgrade) -> void` (increments level; if EVOLUTION → sets `evolved=true`, emits `GameEvents.evolution_unlocked`)
  - helper `is_maxed(u) -> bool`.

  Rule: if `evolution_available()`, `build_choices` returns the evolution as a guaranteed golden option plus filler. Otherwise it draws `count` non-maxed upgrades from {signature, passive, generics}, no duplicates.

- [ ] **Step 1: Write the failing tests** in `test/test_upgrade_system.gd`:

```gdscript
extends GutTest

func _make_sys(max_sig := 3) -> UpgradeSystem:
    var ch := CharacterData.new(); ch.id = &"ziv"; ch.max_signature_level = max_sig
    ch.passive_id = &"vanity"; ch.evolution_id = &"fabulous"
    var sig := Upgrade.new(); sig.id = &"sig"; sig.kind = Upgrade.Kind.SIGNATURE; sig.max_level = max_sig
    var pas := Upgrade.new(); pas.id = &"vanity"; pas.kind = Upgrade.Kind.PASSIVE; pas.max_level = 5
    var evo := Upgrade.new(); evo.id = &"fabulous"; evo.kind = Upgrade.Kind.EVOLUTION; evo.max_level = 1
    var gens: Array = []
    for i in 5:
        var g := Upgrade.new(); g.id = StringName("g%d" % i); g.kind = Upgrade.Kind.GENERIC; g.max_level = 5
        gens.append(g)
    return UpgradeSystem.new(ch, gens, sig, pas, evo)

func test_evolution_not_available_initially():
    assert_false(_make_sys().evolution_available())

func test_evolution_available_when_sig_max_and_passive_owned():
    var s := _make_sys(3)
    s.levels[&"sig"] = 3
    s.levels[&"vanity"] = 1
    assert_true(s.evolution_available())

func test_evolution_blocked_without_passive():
    var s := _make_sys(3)
    s.levels[&"sig"] = 3
    assert_false(s.evolution_available())

func test_build_choices_offers_evolution_when_available():
    var s := _make_sys(3)
    s.levels[&"sig"] = 3; s.levels[&"vanity"] = 1
    var rng := RandomNumberGenerator.new(); rng.seed = 1
    var choices := s.build_choices(rng, 3)
    var has_evo := choices.any(func(u): return u.kind == Upgrade.Kind.EVOLUTION)
    assert_true(has_evo)

func test_maxed_upgrades_not_offered():
    var s := _make_sys(3)
    s.levels[&"g0"] = 5  # generic maxed
    var rng := RandomNumberGenerator.new(); rng.seed = 2
    for _i in 10:
        var choices := s.build_choices(rng, 3)
        assert_false(choices.any(func(u): return u.id == &"g0"))
```

- [ ] **Step 2: Run tests, verify they fail** — Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_upgrade_system.gd -gexit`. Expected: FAIL (classes not defined).

- [ ] **Step 3: Implement `upgrade.gd` and `upgrade_system.gd`** to satisfy the contract above (enum `Kind {SIGNATURE, PASSIVE, GENERIC, EVOLUTION}`; `build_choices` honors the evolution rule and excludes maxed/duplicate ids).

- [ ] **Step 4: Run tests, verify pass** — same command. Expected: all 5 PASS.

- [ ] **Step 5: Write notes** — `upgrade-system.md` (pool generation, API) and `evolution-rule.md` (the exact condition, cross-linked from both `[[weapon-system]]` and `[[upgrade-system]]`). Add to INDEX.

- [ ] **Step 6: Commit** — `git commit -m "feat: upgrade system + evolution rule (tested)"`

---

## Task 2A: Spawner + difficulty timeline

**Files:**
- Create: `spawning/difficulty_timeline.gd`, `spawning/spawner.gd`, `spawning/spawner.tscn`
- Create test: `test/test_difficulty_timeline.gd`
- Create notes: `docs/notes/difficulty-timeline.md`, `docs/notes/spawner.md`

**Interfaces:**
- Consumes: `Enemy`, `EnemyData` variants.
- Produces `DifficultyTimeline` (`RefCounted`, pure): `func state_at(t: float) -> Dictionary` returning `{spawn_interval: float, allowed_variants: Array[StringName], boss_due: bool}`; spawn interval shrinks over time, tougher variants unlock at thresholds (tank @60s, spitter @120s), `boss_due` true at each 300s boundary (caller resets via `mark_boss_spawned`).
- Produces `Spawner` (`Node2D`): `func setup(target: Node2D) -> void`; each interval spawns an allowed variant just off-screen around `target`; spawns a mini-boss (tank with ×8 hp, ×3 size) when timeline says so.

- [ ] **Step 1: Write failing tests** for `DifficultyTimeline.state_at` (interval at t=0 vs t=240 strictly decreasing; tank not in allowed at t=10 but present at t=90; `boss_due` true near t=300). Use the GUT command from Task 1C with this test file.

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement `difficulty_timeline.gd`** (pure functions, no engine deps beyond `clamp`/`lerp`).

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Build `spawner.tscn` + `spawner.gd`** — holds an internal accumulator, queries the timeline using elapsed run time, instances `enemy.tscn`, calls `enemy.setup(variant_data, target)`, positions on a ring of radius ~400 around target. Loads the three `.tres` variants by id.

- [ ] **Step 6: Manual smoke test** — arena throwaway scene with Player + Spawner; confirm enemies stream in, rate increases, a big tank appears ~5 min (temporarily lower the boss threshold to test fast, then restore).

- [ ] **Step 7: Write notes**, add to INDEX.

- [ ] **Step 8: Commit** — `git commit -m "feat: spawner + difficulty timeline (tested)"`

---

## Task 2B: XP gem + magnet pickup

**Files:**
- Create: `pickups/xp_gem.gd`, `pickups/xp_gem.tscn`
- Create note: `docs/notes/xp-gem.md`

**Interfaces:**
- Consumes: `GameEvents.enemy_killed` (spawned by GameManager in Wave 3), `Player.get_pickup_range()`, `Player.add_xp`.
- Produces `XPGem` (`Area2D`): `func setup(value: int, player: Node2D) -> void`; each frame, if within `player.get_pickup_range()` it accelerates toward the player; on body/area overlap with player calls `player.add_xp(value)`, emits `GameEvents.xp_collected(value)`, frees.

- [ ] **Step 1: Build `xp_gem.tscn`** — `Area2D` + small colored shape + `CollisionShape2D`.

- [ ] **Step 2: Write `xp_gem.gd`** — magnet logic (lerp velocity toward player when in range), pickup on overlap. Guard against invalid player.

- [ ] **Step 3: Manual smoke test** — scene with Player + several gems; walking near pulls them in and XP rises (watch `player.xp` in remote inspector).

- [ ] **Step 4: Write note**, add to INDEX.

- [ ] **Step 5: Commit** — `git commit -m "feat: XP gem with magnet pickup"`

---

## Task 2C: Ziv — Stunning Looks (signature + evolution)

**Files:**
- Create: `weapons/ziv_stunning_looks.gd`, `weapons/ziv_stunning_looks.tscn`
- Create note: `docs/notes/weapon-ziv.md`

**Interfaces:**
- Consumes: `Weapon` base, enemies via group `"enemies"` + `take_damage`.
- Produces `ZivStunningLooks extends Weapon`: `fire()` charms (briefly zeroes velocity / sets a `charmed` flag) the nearest N enemies in a radius AND fires a slow piercing rainbow beam (a long thin `Area2D` hitbox dealing damage to all enemies it overlaps). `level_up()` scales radius/charm count/beam damage. `evolve()` → permanent charm field within radius + the beam sweeps (rotates continuously) = "Absolutely Fabulous". Damage scales with `stats.damage_mult`.

- [ ] **Step 1: Build `ziv_stunning_looks.tscn`** — root extends Weapon script; child `Area2D` "Beam" (thin rectangle hitbox, starts disabled) + `Area2D` "CharmField".

- [ ] **Step 2: Write the script** — `base_cooldown` set; `fire()` enables the beam briefly (`Area2D.get_overlapping_bodies()` → `take_damage`), and charms nearest enemies (call a soft `charm(duration)` on enemy if present, else temporarily set their `data.move_speed`-based velocity to 0 via a `charmed_until` field — add a minimal `charm(t)` method to Enemy in this task and note it). Levels scale numbers. `evolve()` makes the beam persistent + rotating and the charm field always-on.

- [ ] **Step 3: Manual smoke test** — Player(Ziv weapon) vs a cluster of enemies: beam damages a line, nearby enemies pause; after forcing `level=max` then `evolve()`, beam sweeps continuously.

- [ ] **Step 4: Write note**, add to INDEX. Link `[[weapon-system]]`, `[[evolution-rule]]`.

- [ ] **Step 5: Commit** — `git commit -m "feat: Ziv signature ability + evolution"`

---

## Task 2D: Avihay — Chat Spam (signature + evolution)

**Files:**
- Create: `weapons/avihay_chat_spam.gd`, `weapons/avihay_chat_spam.tscn`, `weapons/bubble.gd`, `weapons/bubble.tscn`
- Create note: `docs/notes/weapon-avihay.md`

**Interfaces:**
- Consumes: `Weapon` base, enemies via group + `take_damage`.
- Produces `AvihayChatSpam extends Weapon`: `fire()` spawns message-bubble projectiles (`Area2D` that travels, deals damage on hit, despawns after lifetime/pierce count) in spread directions. `level_up()` adds bubbles / fire rate / pierce. `evolve()` → "Reply-All Apocalypse": bubbles become homing and fire in all directions densely. Produces `Bubble` (`Area2D`): `setup(direction, damage, pierce, homing)`.

- [ ] **Step 1: Build `bubble.tscn` + `bubble.gd`** — travels along direction, `take_damage` targets on overlap, decrements pierce, optional homing toward nearest enemy.

- [ ] **Step 2: Build `avihay_chat_spam.tscn` + script** — `fire()` instantiates bubbles toward nearest enemy + spread; scaling per level; `evolve()` sets homing + 360° dense pattern.

- [ ] **Step 3: Manual smoke test** — bubbles stream out, damage enemies, pierce per level; evolved = screen-filling homing.

- [ ] **Step 4: Write note**, add to INDEX.

- [ ] **Step 5: Commit** — `git commit -m "feat: Avihay signature ability + evolution"`

---

## Task 3.1: GameManager (run state, timer, kills, flow)

**Files:**
- Create: `game/game_manager.gd`
- Create note: `docs/notes/game-manager.md`

**Interfaces:**
- Consumes: all Wave 1/2 contracts + `GameEvents`.
- Produces `GameManager` (`Node`): owns run `elapsed: float` and `kills: int`; on `GameEvents.enemy_killed` increments kills and spawns an `XPGem` at the position with the given value; on `GameEvents.player_leveled_up` triggers the level-up flow (pause tree, ask `UpgradeUI`); on `GameEvents.player_died` writes `RunState.last_run` and transitions to game over. Exposes `get_elapsed()`, `get_kills()` for the HUD.

- [ ] **Step 1: Write `game_manager.gd`** — connect signals in `_ready`; accumulate `elapsed` in `_process` (skip while paused); spawn gems on kill; pause + show upgrade UI on level-up, apply choice, unpause; on death store score + `get_tree().change_scene_to_file(...game_over...)`.
- [ ] **Step 2: Manual smoke test** (after Task 3.5 wiring) — verify kills count, gems spawn, level-up pauses.
- [ ] **Step 3: Write note**, add to INDEX.
- [ ] **Step 4: Commit** — `git commit -m "feat: game manager run flow"`

---

## Task 3.2: Upgrade UI (level-up choice)

**Files:**
- Create: `upgrades/upgrade_ui.gd`, `upgrades/upgrade_ui.tscn`
- Create note: `docs/notes/upgrade-ui.md`

**Interfaces:**
- Consumes: `UpgradeSystem.build_choices`, `UpgradeSystem.apply`, `Player.weapon` (to call `level_up`/`evolve`), `GameEvents.evolution_unlocked`.
- Produces `UpgradeUI` (`CanvasLayer`): `func present(system: UpgradeSystem, player: Player) -> void` shows 3 buttons (golden style when an option is `EVOLUTION`); on click → `system.apply(choice)`, route effect (signature→`player.weapon.level_up()`, evolution→`player.weapon.evolve()`, passive/generic→apply stat or weapon param), then hide + unpause.

- [ ] **Step 1: Build `upgrade_ui.tscn`** — `CanvasLayer` + centered `PanelContainer` + 3 `Button`s; process mode = "When Paused".
- [ ] **Step 2: Write `upgrade_ui.gd`** — build from `build_choices`, wire clicks to apply + route effects, highlight evolution.
- [ ] **Step 3: Manual smoke test** — leveling shows 3 options; maxing signature + owning passive shows golden EVOLVE; taking it visibly changes the weapon.
- [ ] **Step 4: Write note**, add to INDEX.
- [ ] **Step 5: Commit** — `git commit -m "feat: level-up upgrade UI with evolution option"`

---

## Task 3.3: HUD + Game Over

**Files:**
- Create: `ui/hud.gd`, `ui/hud.tscn`, `ui/game_over.gd`, `ui/game_over.tscn`
- Create notes: `docs/notes/hud.md`, `docs/notes/game-over.md`

**Interfaces:**
- HUD (`CanvasLayer`): shows timer (`GameManager.get_elapsed`), HP bar (`GameEvents.player_hp_changed`), XP bar + level (`player_leveled_up` + poll xp), kills (`GameManager.get_kills`).
- Game Over (`Control`): reads `RunState.last_run`, shows time + kills, buttons "Retry" (→ arena) and "Character Select" (→ select).

- [ ] **Step 1: Build + script HUD** (labels/bars bound to signals).
- [ ] **Step 2: Build + script Game Over** screen.
- [ ] **Step 3: Manual smoke test** — values update live; death shows correct score; buttons route.
- [ ] **Step 4: Write notes**, add to INDEX.
- [ ] **Step 5: Commit** — `git commit -m "feat: HUD and game over screen"`

---

## Task 3.4: Character data assets + character select

**Files:**
- Create: `characters/ziv.tres`, `characters/avihay.tres`, `upgrades/*` generic upgrade `.tres` set, per-character signature/passive/evolution `Upgrade` `.tres`
- Create: `ui/character_select.gd`, `ui/character_select.tscn`
- Create note: `docs/notes/how-to-add-a-character.md`

**Interfaces:**
- Produces `ziv.tres` / `avihay.tres` (`CharacterData`) wired to their weapon scenes, base stats, `passive_id`, `evolution_id`.
- Produces the `Upgrade` resources each character feeds into `UpgradeSystem`, and a shared generic-upgrade set (move speed, max hp, magnet, fire rate, armor) with `apply` semantics documented.
- Character select sets `RunState.selected_character` then loads the arena.

- [ ] **Step 1: Author the generic upgrade `.tres` set** and document how each mutates `StatBlock`/weapon.
- [ ] **Step 2: Author Ziv & Avihay `CharacterData` + their signature/passive/evolution `Upgrade` resources.**
- [ ] **Step 3: Build character-select screen** (two buttons tinted by `color`, sets RunState, changes scene).
- [ ] **Step 4: Write `how-to-add-a-character.md` runbook** (the exact files to author for friend #3..#10, referencing this task). Add to INDEX.
- [ ] **Step 5: Commit** — `git commit -m "feat: Ziv/Avihay data, upgrades, character select"`

---

## Task 3.5: Arena assembly + difficulty/boss + full playtest

**Files:**
- Create: `game/arena.tscn`, `game/main.tscn`
- Create note: `docs/notes/how-to-add-an-enemy.md`; update `INDEX.md` completeness pass.

**Interfaces:**
- `arena.tscn` instances: Player (from `RunState.selected_character`), Spawner, GameManager, HUD, UpgradeUI. `main.tscn` routes character-select → arena → game-over.

- [ ] **Step 1: Assemble `arena.tscn`** wiring every system; GameManager constructs the `UpgradeSystem` from the selected character's upgrades and hands it to `UpgradeUI` on level-up.
- [ ] **Step 2: Assemble `main.tscn`** as the entry routing scene; set as main scene.
- [ ] **Step 3: Full playtest — Ziv:** select → survive, level up, pick upgrades, reach max signature + passive → EVOLVE → die → game over → retry. Confirm every Success Criterion in the spec.
- [ ] **Step 4: Full playtest — Avihay:** same loop; confirm the two characters feel distinct.
- [ ] **Step 5: Mini-boss check** — confirm a mini-boss spawns on cadence and drops a burst of XP.
- [ ] **Step 6: Write `how-to-add-an-enemy.md`; final `INDEX.md` pass** — confirm every built component has a current, linked note (the spec's knowledge-base success criterion).
- [ ] **Step 7: Run the full GUT suite** — Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`. Expected: all tests PASS.
- [ ] **Step 8: Commit** — `git commit -m "feat: arena assembly, full playtest, runbook notes"`

---

## Self-Review

**Spec coverage:** §3 core loop → Tasks 1A/2A/2B/3.1/3.5. §4 enemies/waves/mini-boss → 1B/2A/3.5. §5 upgrades + evolution rule → 1C/3.2/3.4. §6 roster (Ziv+Avihay only in v1) → 2C/2D/3.4. §7 structure → file map + all tasks. §8 knowledge base → every task's note step + 0.1 skeleton + 3.5 completeness pass. §9 testing → GUT tasks (1C, 2A) + manual playtests. §10 success criteria → 3.3 (game over/score), 3.2 (evolve option), 3.5 (full loop, boss, notes). No gaps.

**Placeholder scan:** No TBD/TODO. Scene-heavy tasks specify node trees + full script code for logic; art is explicitly placeholder shapes per Global Constraints.

**Type consistency:** `take_damage(amount: float)` used uniformly (Enemy, Player). `GameEvents.enemy_killed(position, xp_value)` matches emit (1B) and consumer (3.1). `Weapon.level_up()/evolve()/is_max_level()` consistent across base (0.2) and consumers (2C/2D/3.2). `UpgradeSystem.build_choices/apply/evolution_available` consistent across 1C and 3.2/3.5. `CharacterData` fields consistent across 0.2/3.4. `Player.get_pickup_range()` defined (1A) and consumed (2B).
