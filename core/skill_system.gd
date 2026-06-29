# See docs/notes/skill-system.md
class_name SkillSystem extends RefCounted

## Run-time skill tracker for the 3D game.
## Tracks 4 skills per character: 1 signature (owned at start, level 1) +
## 3 acquirable (start at level 0 = not owned). Each skill has a SKILL upgrade
## (acquire / level-up), a PASSIVE upgrade (offered once owned), and a SYNERGY
## (golden) upgrade offered when skill is maxed (level 5) AND passive ≥ 1.
##
## Acquisition-detection contract (for GameManager / Task 3.2):
##   After calling apply(skill_upgrade), check
##     skill_level(skill_id_of(skill_upgrade)) == 1
##   to detect a first-time acquisition (0→1). SkillSystem does NOT instantiate
##   weapons; that is the GameManager's responsibility.
##
## See docs/notes/skill-system.md for full model description.

## StringName skill id → current level (int).
## Covers SKILL upgrade ids, PASSIVE upgrade ids, and GENERIC upgrade ids.
var levels: Dictionary = {}
## StringName skill id → true once that skill's synergy has been applied.
var synergized: Dictionary = {}

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


# ---------------------------------------------------------------------------
# Query API
# ---------------------------------------------------------------------------

## Returns true iff the skill's SKILL upgrade level is ≥ 1 (acquired).
func is_owned(skill: SkillData) -> bool:
	return levels.get(skill.skill_upgrade.id, 0) >= 1


## Count of owned (level ≥ 1), non-signature weapons — what the cap limits.
func owned_weapon_count() -> int:
	var n := 0
	for skill in _skills:
		if not skill.is_signature and levels.get(skill.skill_upgrade.id, 0) >= 1:
			n += 1
	return n


## Current level of the SKILL upgrade for `skill_id`. 0 = not owned.
func skill_level(skill_id: StringName) -> int:
	var skill := _find_skill(skill_id)
	if skill == null:
		return 0
	return levels.get(skill.skill_upgrade.id, 0)


## Current level of the PASSIVE upgrade for `skill_id`.
func passive_level(skill_id: StringName) -> int:
	var skill := _find_skill(skill_id)
	if skill == null:
		return 0
	return levels.get(skill.passive_upgrade.id, 0)


## Returns the skill_id StringName for SKILL / PASSIVE / SYNERGY upgrades, &"" otherwise.
func skill_id_of(u: Upgrade) -> StringName:
	if u.kind == Upgrade.Kind.SKILL or u.kind == Upgrade.Kind.PASSIVE or u.kind == Upgrade.Kind.SYNERGY:
		return u.skill_id
	return &""


## Returns true iff upgrade `u` is at or beyond its max_level.
func is_maxed(u: Upgrade) -> bool:
	return levels.get(u.id, 0) >= u.max_level


## True iff skill_level == 5 AND passive_level ≥ 1 AND not yet synergized.
func synergy_available(skill: SkillData) -> bool:
	return (
		levels.get(skill.skill_upgrade.id, 0) >= skill.skill_upgrade.max_level
		and levels.get(skill.passive_upgrade.id, 0) >= 1
		and not synergized.has(skill.id)
	)


# ---------------------------------------------------------------------------
# Pool / choice API
# ---------------------------------------------------------------------------

## Build a list of up to `count` upgrade choices.
## SYNERGY upgrades where synergy_available() is true are GUARANTEED (golden)
## slots; they are included first. Remaining slots come from the normal pool
## (non-maxed SKILL / PASSIVE / GENERIC, filtered for distinct ids), shuffled.
func build_choices(rng: RandomNumberGenerator, count: int = 3) -> Array[Upgrade]:
	var result: Array[Upgrade] = []
	var seen_ids: Dictionary = {}

	# --- Guaranteed synergy slots ---
	for skill in _skills:
		if synergy_available(skill):
			result.append(skill.synergy_upgrade)
			seen_ids[skill.synergy_upgrade.id] = true
			if result.size() >= count:
				return result

	# --- Normal pool ---
	var pool: Array[Upgrade] = _normal_pool()
	_shuffle_array(rng, pool)
	for u in pool:
		if seen_ids.has(u.id):
			continue
		result.append(u)
		seen_ids[u.id] = true
		if result.size() >= count:
			break

	return result


## True iff there is at least one upgrade still choosable (any synergy available
## OR the normal pool is non-empty). Returns false when fully exhausted.
func has_available_choices() -> bool:
	for skill in _skills:
		if synergy_available(skill):
			return true
	return not _normal_pool().is_empty()


## Apply upgrade `u` to state.
## SKILL / PASSIVE / GENERIC → increment levels[u.id], capped at u.max_level.
## SYNERGY → mark synergized[u.skill_id] = true and emit GameEvents.evolution_unlocked,
##           but only if the synergy is actually available for the skill.
##           (build_choices is the normal gate; this guard is a defensive backstop.)
func apply(u: Upgrade) -> void:
	match u.kind:
		Upgrade.Kind.SKILL, Upgrade.Kind.PASSIVE, Upgrade.Kind.GENERIC:
			levels[u.id] = min(levels.get(u.id, 0) + 1, u.max_level)
		Upgrade.Kind.SYNERGY:
			var skill := _find_skill(u.skill_id)
			if skill != null and synergy_available(skill):
				synergized[u.skill_id] = true
				GameEvents.evolution_unlocked.emit(u.skill_id)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Collect all non-maxed upgrades eligible for the normal (non-synergy) pool.
func _normal_pool() -> Array[Upgrade]:
	var pool: Array[Upgrade] = []
	var at_cap := _weapon_cap > 0 and owned_weapon_count() >= _weapon_cap
	for skill in _skills:
		var owned := is_owned(skill)
		# SKILL upgrade: acquire (level 0) or level-up (1-4). At cap, suppress
		# acquiring NEW non-signature weapons; owned level-ups always allowed.
		if not is_maxed(skill.skill_upgrade):
			var is_new_weapon: bool = not owned and not skill.is_signature
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


## Find a SkillData by its id StringName. Returns null if not found.
func _find_skill(skill_id: StringName) -> SkillData:
	for skill in _skills:
		if skill.id == skill_id:
			return skill
	return null


## Fisher-Yates in-place shuffle using the provided RNG.
func _shuffle_array(rng: RandomNumberGenerator, arr: Array) -> void:
	var n := arr.size()
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
