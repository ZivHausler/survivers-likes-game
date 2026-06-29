# Type-Based Weapon System — Foundation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the data-model + run-assembly machinery for the TemTem-style type-gated weapon pool, validated with unit tests, *before* any weapon content is authored.

**Architecture:** Add a `type` tag to `SkillData` and `types` + `ultimate` to `CharacterData`. A new `SkillPool` provides a pure type-filter (`natural ∪ matching types`). `SkillSystem` gains an injectable weapon-slot cap. `GameManager3D` assembles each run's skill list as `[ultimate] + filtered pool` via a pure, testable helper. No new weapons yet — the mechanism is proven against stub data and stays backward-compatible with the existing per-character `skills` path.

**Tech Stack:** Godot 4.7, GDScript, GUT test framework (headless).

## Global Constraints

- Engine: **Godot 4.7 stable**. Headless boot must stay green: `godot --headless --quit`.
- Full GUT suite must stay green after every task: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` (currently ~220 passing).
- Single-file test run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/<file>.gd -gexit`.
- GDScript only. Tests `extends GutTest`. Follow existing `test/` conventions.
- All new fields are **additive with defaults** so existing `.tres` resources keep loading.
- Type ids are `StringName`s. The universal type is `&"natural"`. Themed types: `&"charm"`, `&"social"`, `&"holy"`, `&"pack"`, `&"toxic"`, `&"pest"`, `&"joy"`, `&"bomber"`, `&"rush"`, `&"sound"`.
- Default weapon-slot cap = **6** (ultimate excluded from the count). Cap value `<= 0` means unlimited.

---

### Task 1: Add type-system fields to SkillData and CharacterData

**Files:**
- Modify: `core/skill_data.gd` (add `type` after line 25)
- Modify: `core/character_data.gd` (add `types` + `ultimate` after line 24)
- Test: `test/test_type_system_fields.gd` (create)

**Interfaces:**
- Produces: `SkillData.type: StringName` (default `&"natural"`); `CharacterData.types: Array[StringName]` (default `[]`); `CharacterData.ultimate: SkillData` (default `null`).

- [ ] **Step 1: Write the failing test**

Create `test/test_type_system_fields.gd`:

```gdscript
extends GutTest
## Verifies the additive type-system fields on SkillData and CharacterData,
## including backward-compatibility with existing .tres resources.

func test_skilldata_type_defaults_to_natural() -> void:
	var sd := SkillData.new()
	assert_eq(sd.type, &"natural", "SkillData.type must default to &\"natural\"")

func test_skilldata_type_is_assignable() -> void:
	var sd := SkillData.new()
	sd.type = &"charm"
	assert_eq(sd.type, &"charm")

func test_characterdata_types_defaults_empty() -> void:
	var cd := CharacterData.new()
	assert_eq(cd.types.size(), 0, "CharacterData.types must default to []")
	assert_null(cd.ultimate, "CharacterData.ultimate must default to null")

func test_existing_skill_resource_still_loads_with_default_type() -> void:
	# Back-compat: a .tres authored before the field existed loads with the default.
	var sd: SkillData = load("res://characters/skills/ziv_mirror_shards.tres")
	assert_not_null(sd, "existing skill resource must still load")
	assert_eq(sd.type, &"natural", "legacy resource must read the default type")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_type_system_fields.gd -gexit`
Expected: FAIL — `Invalid set index 'type'` / `Invalid set index 'types'` (fields don't exist yet).

- [ ] **Step 3: Add the field to `core/skill_data.gd`**

After line 25 (`@export var icon: Texture2D`), add:

```gdscript
## Weapon type for pool filtering. &"natural" = offered to every character;
## otherwise one themed type id (&"charm", &"holy", …). Ultimates carry their
## owner's primary type for tagging consistency.
@export var type: StringName = &"natural"
```

- [ ] **Step 4: Add the fields to `core/character_data.gd`**

After line 24 (`@export var skills: Array[SkillData] = []`), add:

```gdscript
## 1–2 type ids this character can roll type-gated weapons from. Empty = natural only.
@export var types: Array[StringName] = []
## This character's exclusive ultimate (its SkillData.is_signature must be true).
## Auto-granted at run start; never offered to other characters.
@export var ultimate: SkillData
```

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_type_system_fields.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add core/skill_data.gd core/character_data.gd test/test_type_system_fields.gd
git commit -m "feat: add type tag to SkillData and types/ultimate to CharacterData

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: SkillPool — pure type-filter + registry stub

**Files:**
- Create: `core/skill_pool.gd`
- Test: `test/test_skill_pool.gd` (create)

**Interfaces:**
- Consumes: `SkillData.type` (Task 1).
- Produces:
  - `SkillPool.filter(pool: Array, types: Array) -> Array` — pure; returns entries whose `type == &"natural"` OR `type ∈ types`, order-preserving.
  - `SkillPool.all() -> Array` — preloaded shared-pool registry. Returns `[]` until content plans populate it.
  - `SkillPool.for_types(types: Array) -> Array` — `filter(all(), types)`.

- [ ] **Step 1: Write the failing test**

Create `test/test_skill_pool.gd`:

```gdscript
extends GutTest
## Tests the pure type-filter used to build each run's offer pool.

func _stub(id: StringName, type: StringName) -> SkillData:
	var sd := SkillData.new()
	sd.id = id
	sd.type = type
	return sd

func _ids(arr: Array) -> Array:
	var out := []
	for sd in arr:
		out.append(sd.id)
	return out

func test_filter_includes_natural_always() -> void:
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := _ids(SkillPool.filter(pool, []))
	assert_eq(got, [&"n"], "empty types → natural only")

func test_filter_includes_matching_type() -> void:
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := _ids(SkillPool.filter(pool, [&"charm"]))
	assert_eq(got, [&"n", &"c"], "natural + charm, not holy")

func test_filter_dual_type() -> void:
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := _ids(SkillPool.filter(pool, [&"charm", &"holy"]))
	assert_eq(got, [&"n", &"c", &"h"], "natural + both matching types")

func test_all_is_empty_until_content_added() -> void:
	# Registry is intentionally empty in the foundation; content plans append to it.
	assert_eq(SkillPool.all().size(), 0)

func test_for_types_composes_all_and_filter() -> void:
	# With an empty registry, for_types is empty regardless of types.
	assert_eq(SkillPool.for_types([&"charm"]).size(), 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_skill_pool.gd -gexit`
Expected: FAIL — `Identifier "SkillPool" not declared`.

- [ ] **Step 3: Create `core/skill_pool.gd`**

```gdscript
class_name SkillPool extends RefCounted
## Shared weapon pool + the pure type-filter that gates which weapons a character
## may be offered. The registry (`all()`) is populated by content plans via the
## explicit preload list below; the foundation ships it empty.

## Order-preserving filter: keep entries whose type is &"natural" OR is in `types`.
static func filter(pool: Array, types: Array) -> Array:
	var out: Array = []
	for sd in pool:
		if sd.type == &"natural" or types.has(sd.type):
			out.append(sd)
	return out

## All shared-pool weapons (10 natural + 10 typed once content lands). Empty for now.
static func all() -> Array:
	# Content plans add: const W_PEW_PEW := preload("res://characters/skills/pew_pew.tres")
	# and list them here. Foundation registry is intentionally empty.
	return []

## Weapons a character with `types` may be offered: natural ∪ matching types.
static func for_types(types: Array) -> Array:
	return filter(all(), types)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_skill_pool.gd -gexit`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add core/skill_pool.gd test/test_skill_pool.gd
git commit -m "feat: add SkillPool type-filter and empty shared-pool registry

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Weapon-slot cap in SkillSystem

**Files:**
- Modify: `core/skill_system.gd` (constructor line 28-35; `_normal_pool` lines 148-161)
- Test: `test/test_weapon_slot_cap.gd` (create)

**Interfaces:**
- Consumes: `SkillData.is_signature`, `Upgrade.Kind.SKILL` (existing).
- Produces:
  - `SkillSystem._init(skills: Array, generic_pool: Array, weapon_cap: int = 6)` — new 3rd arg.
  - `SkillSystem.owned_weapon_count() -> int` — owned non-signature SKILL weapons.
  - Behavior: when `weapon_cap > 0` and `owned_weapon_count() >= weapon_cap`, `_normal_pool()` stops offering SKILL upgrades for **not-yet-owned, non-signature** skills. Level-ups of owned weapons, passives, synergies, and generics are unaffected. The signature ultimate never counts toward the cap.

- [ ] **Step 1: Write the failing test**

Create `test/test_weapon_slot_cap.gd`:

```gdscript
extends GutTest
## Verifies the weapon-slot cap: at cap, no new weapons are offered, but
## level-ups of owned weapons and generics still are. Signature is exempt.

func _skill_upgrade(sid: StringName) -> Upgrade:
	var u := Upgrade.new()
	u.id = sid
	u.kind = Upgrade.Kind.SKILL
	u.max_level = 5
	u.skill_id = sid
	return u

func _passive_upgrade(sid: StringName) -> Upgrade:
	var u := Upgrade.new()
	u.id = StringName(str(sid) + "_p")
	u.kind = Upgrade.Kind.PASSIVE
	u.max_level = 5
	u.skill_id = sid
	return u

func _synergy_upgrade(sid: StringName) -> Upgrade:
	var u := Upgrade.new()
	u.id = StringName(str(sid) + "_s")
	u.kind = Upgrade.Kind.SYNERGY
	u.max_level = 1
	u.skill_id = sid
	return u

func _skill(sid: StringName, signature: bool) -> SkillData:
	var sd := SkillData.new()
	sd.id = sid
	sd.is_signature = signature
	sd.skill_upgrade = _skill_upgrade(sid)
	sd.passive_upgrade = _passive_upgrade(sid)
	sd.synergy_upgrade = _synergy_upgrade(sid)
	return sd

func _pool_ids(sys: SkillSystem) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var out := []
	# Pull a generous count so we see the whole eligible pool.
	for u in sys.build_choices(rng, 99):
		out.append(u.id)
	return out

func test_owned_weapon_count_excludes_signature() -> void:
	var ult := _skill(&"ult", true)
	var w1 := _skill(&"w1", false)
	var sys := SkillSystem.new([ult, w1], [], 6)
	# Only the signature is owned at start → 0 non-signature weapons.
	assert_eq(sys.owned_weapon_count(), 0)
	sys.apply(w1.skill_upgrade)  # acquire w1 (0→1)
	assert_eq(sys.owned_weapon_count(), 1)

func test_new_weapon_blocked_at_cap() -> void:
	var ult := _skill(&"ult", true)
	var w1 := _skill(&"w1", false)
	var w2 := _skill(&"w2", false)
	var sys := SkillSystem.new([ult, w1, w2], [], 1)  # cap = 1
	sys.apply(w1.skill_upgrade)  # own 1 weapon → at cap
	var ids := _pool_ids(sys)
	assert_does_not_have(ids, &"w2", "new weapon must not be offered at cap")
	assert_has(ids, &"w1", "owned weapon level-up must still be offered")

func test_under_cap_offers_new_weapon() -> void:
	var ult := _skill(&"ult", true)
	var w1 := _skill(&"w1", false)
	var w2 := _skill(&"w2", false)
	var sys := SkillSystem.new([ult, w1, w2], [], 6)
	sys.apply(w1.skill_upgrade)
	var ids := _pool_ids(sys)
	assert_has(ids, &"w2", "below cap, new weapon is offered")

func test_cap_zero_means_unlimited() -> void:
	var ult := _skill(&"ult", true)
	var w1 := _skill(&"w1", false)
	var w2 := _skill(&"w2", false)
	var sys := SkillSystem.new([ult, w1, w2], [], 0)  # unlimited
	sys.apply(w1.skill_upgrade)
	var ids := _pool_ids(sys)
	assert_has(ids, &"w2", "cap<=0 disables the limit")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_weapon_slot_cap.gd -gexit`
Expected: FAIL — `_init()` takes 2 args / `owned_weapon_count` not found.

- [ ] **Step 3: Update the constructor in `core/skill_system.gd`**

Replace lines 24-35 (the two `var` decls and `_init`):

```gdscript
var _skills: Array          # Array[SkillData]
var _generic_pool: Array    # Array[Upgrade]
## Max simultaneously-owned non-signature weapons. <= 0 = unlimited.
var _weapon_cap: int = 6


func _init(skills: Array, generic_pool: Array, weapon_cap: int = 6) -> void:
	_skills = skills
	_generic_pool = generic_pool
	_weapon_cap = weapon_cap
	# Initialise the signature skill as owned (level 1).
	for skill in _skills:
		if skill.is_signature:
			levels[skill.skill_upgrade.id] = 1
			break
```

- [ ] **Step 4: Add `owned_weapon_count()` and gate `_normal_pool()`**

Add this query method just after `is_owned` (after line 44):

```gdscript
## Count of owned (level ≥ 1), non-signature weapons — what the cap limits.
func owned_weapon_count() -> int:
	var n := 0
	for skill in _skills:
		if not skill.is_signature and levels.get(skill.skill_upgrade.id, 0) >= 1:
			n += 1
	return n
```

Then replace the `_normal_pool()` body (lines 148-161) with the cap-aware version:

```gdscript
func _normal_pool() -> Array[Upgrade]:
	var pool: Array[Upgrade] = []
	var at_cap := _weapon_cap > 0 and owned_weapon_count() >= _weapon_cap
	for skill in _skills:
		var owned := is_owned(skill)
		# SKILL upgrade: acquire (level 0) or level-up (1-4). At cap, suppress
		# acquiring NEW non-signature weapons; owned level-ups always allowed.
		if not is_maxed(skill.skill_upgrade):
			var is_new_weapon := not owned and not skill.is_signature
			if not (is_new_weapon and at_cap):
				pool.append(skill.skill_upgrade)
		# PASSIVE upgrade: offered only if skill is owned AND passive not maxed
		if owned and not is_maxed(skill.passive_upgrade):
			pool.append(skill.passive_upgrade)
	# Generic upgrades
	for g in _generic_pool:
		if not is_maxed(g):
			pool.append(g)
	return pool
```

- [ ] **Step 5: Run the new test + the existing skill-system test**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_weapon_slot_cap.gd -gexit`
Expected: PASS (4 tests).
Run the existing coverage to confirm no regression (default cap 6 never trips for 4-skill characters):
`godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_apply_upgrade.gd -gexit`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add core/skill_system.gd test/test_weapon_slot_cap.gd
git commit -m "feat: add injectable weapon-slot cap to SkillSystem (default 6)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: GameManager run-assembly helper (type-filtered pool + ultimate)

**Files:**
- Modify: `game/game_manager_3d.gd` (add static helper; branch `start()` to use it)
- Test: `test/test_run_assembly.gd` (create)

**Interfaces:**
- Consumes: `SkillPool.filter` (Task 2), `CharacterData.types`/`ultimate` (Task 1), `SkillData.is_signature`.
- Produces: `GameManager3D.assemble_run_skills(ultimate: SkillData, pool: Array, types: Array) -> Array` — pure; returns `[ultimate] + SkillPool.filter(pool, types)` (ultimate first; null ultimate omitted).

- [ ] **Step 1: Write the failing test**

Create `test/test_run_assembly.gd`:

```gdscript
extends GutTest
## Verifies GameManager3D assembles a run's skill list as
## [ultimate] + type-filtered shared pool, ultimate first.

func _stub(id: StringName, type: StringName, signature := false) -> SkillData:
	var sd := SkillData.new()
	sd.id = id
	sd.type = type
	sd.is_signature = signature
	return sd

func _ids(arr: Array) -> Array:
	var out := []
	for sd in arr:
		out.append(sd.id)
	return out

func test_assemble_puts_ultimate_first_then_filtered_pool() -> void:
	var ult := _stub(&"ziv_ult", &"charm", true)
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := GameManager3D.assemble_run_skills(ult, pool, [&"charm"])
	assert_eq(_ids(got), [&"ziv_ult", &"n", &"c"], "ultimate first, then natural + charm")

func test_assemble_null_ultimate_omitted() -> void:
	var pool := [_stub(&"n", &"natural")]
	var got := GameManager3D.assemble_run_skills(null, pool, [])
	assert_eq(_ids(got), [&"n"], "null ultimate is skipped")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_run_assembly.gd -gexit`
Expected: FAIL — `Invalid call. Nonexistent function 'assemble_run_skills'`.

- [ ] **Step 3: Add the static helper to `game/game_manager_3d.gd`**

Add near the top of the class body, after the `var` declarations (after line 46):

```gdscript
## Assemble a run's skill list: the character's exclusive ultimate first, then the
## type-filtered shared pool. Pure (no scene access) so it is unit-testable.
static func assemble_run_skills(ultimate: SkillData, pool: Array, types: Array) -> Array:
	var out: Array = []
	if ultimate != null:
		out.append(ultimate)
	out.append_array(SkillPool.filter(pool, types))
	return out
```

- [ ] **Step 4: Branch `start()` to use the new path when `types`/`ultimate` are set**

In `start()`, replace the `if char_data and not char_data.skills.is_empty():` block (lines 81-93) with a new-path-first version:

```gdscript
	if char_data and char_data.ultimate != null and not char_data.types.is_empty():
		# Type-gated pool path: ultimate + filtered shared pool.
		var run_skills := assemble_run_skills(char_data.ultimate, SkillPool.all(), char_data.types)
		skill_system = SkillSystem.new(run_skills, generic_pool)
		_skill_by_id.clear()
		for s in run_skills:
			_skill_by_id[s.id] = s
		# Acquire the signature (ultimate) weapon immediately.
		if _player:
			for s in run_skills:
				if s.is_signature:
					_player.acquire_skill(s.id, s.weapon_scene)
					break
	elif char_data and not char_data.skills.is_empty():
		# Legacy per-character roster path (still used until migration completes).
		skill_system = SkillSystem.new(char_data.skills, generic_pool)
		_skill_by_id.clear()
		for s in char_data.skills:
			_skill_by_id[s.id] = s
		if _player:
			for s in char_data.skills:
				if s.is_signature:
					_player.acquire_skill(s.id, s.weapon_scene)
					break
```

- [ ] **Step 5: Run the new test + full suite**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_run_assembly.gd -gexit`
Expected: PASS (2 tests).
Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: full suite green (no regressions; new path is dormant because no character has `types`/`ultimate` set yet).
Run: `godot --headless --quit`
Expected: boots `main_3d`/character-select with zero errors.

- [ ] **Step 6: Commit**

```bash
git add game/game_manager_3d.gd test/test_run_assembly.gd
git commit -m "feat: GameManager assembles type-filtered run pool + ultimate

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (foundation scope only):**
- Spec §4.1 `SkillData.type` → Task 1. ✓
- Spec §4.2 `CharacterData.types`/`ultimate` → Task 1. ✓
- Spec §4.3 `SkillPool` (`all`/`for_types`/filter) → Task 2. ✓
- Spec §5 offer filtering at GameManager construction → Task 4. ✓
- Spec §9 weapon-slot cap enforced in `_normal_pool` + constructor arg → Task 3. ✓
- Spec §6/§7 weapon & ultimate **content**, §8 character wiring, §10 co-op plumbing, §11 migration → **deferred to subsequent plans** (see roadmap below). Foundation deliberately ships them empty/dormant.

**Placeholder scan:** No "TBD"/"handle edge cases". `SkillPool.all()` returns `[]` by design (an empty registry content plans extend), with the extension pattern shown inline — this is real, runnable code, not a placeholder.

**Type consistency:** `assemble_run_skills(ultimate, pool, types)` uses `SkillPool.filter(pool, types)` from Task 2 (matching signature). `SkillSystem.new(skills, generic_pool, weapon_cap)` 3-arg form is used consistently in Tasks 3 and 4. `owned_weapon_count()` defined Task 3, not referenced elsewhere. `type` / `types` / `ultimate` field names consistent across Tasks 1, 2, 4. ✓

---

## Subsequent Plans (roadmap — not part of this plan)

Each is its own `docs/superpowers/plans/` file, built on this foundation, each independently testable:

1. **Natural weapons (10)** — author `SkillData` + 3 upgrades + `Weapon3D` scenes (mostly projectile/orbit archetypes); register in `SkillPool.all()`. Per-weapon TDD like existing `test_avihay_chat_spam_3d.gd`.
2. **Type weapons (10)** — same pattern, each tagged with its themed `type`.
3. **Ultimates (10)** — `is_signature` weapons with large `base_cooldown`; includes the `players`-group plumbing for the three team-effect ults (Buzzkill / Conference Call / Comic Relief), no-op in solo per spec §10.
4. **Migration & character wiring** — set `types` + `ultimate` on each `characters/<friend>_3d.tres`; remove the replaced bespoke skills, their upgrades, and now-unreferenced weapon scenes (spec §11); update/retire their tests.
5. **Balance pass** — cooldowns, final cap number, Buzzkill solo decision.
