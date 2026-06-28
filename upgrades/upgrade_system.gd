# See docs/notes/upgrade-system.md
class_name UpgradeSystem extends RefCounted

## Tracks upgrade levels for one character run and builds level-up choice pools.
## See docs/notes/upgrade-system.md for pool-generation rules.
## See docs/notes/evolution-rule.md for the evolution unlock condition.

var _character: CharacterData
var _generic_pool: Array          # Array[Upgrade]
var _signature: Upgrade
var _passive: Upgrade
var _evolution: Upgrade

## id (StringName) -> current level (int)
var levels: Dictionary = {}
## True once the evolution upgrade has been applied.
var evolved: bool = false


func _init(
    character: CharacterData,
    generic_pool: Array,
    signature_upgrade: Upgrade,
    passive_upgrade: Upgrade,
    evolution_upgrade: Upgrade
) -> void:
    _character = character
    _generic_pool = generic_pool
    _signature = signature_upgrade
    _passive = passive_upgrade
    _evolution = evolution_upgrade


## Returns true iff the signature is maxed, the passive is owned, and evolution
## has not yet happened. Full condition documented in [[evolution-rule]].
func evolution_available() -> bool:
    return (
        levels.get(_signature.id, 0) >= _character.max_signature_level
        and levels.get(_passive.id, 0) >= 1
        and not evolved
    )


## Returns true iff upgrade u is at or beyond its max_level.
func is_maxed(u: Upgrade) -> bool:
    return levels.get(u.id, 0) >= u.max_level


## Build a choice list of `count` upgrades for the player to pick from.
## If evolution_available(), the evolution is always included (guaranteed golden
## slot) and the remaining slots are filled with non-maxed non-duplicate picks.
## Otherwise draws `count` non-maxed upgrades from {signature, passive, generics},
## no duplicate ids.
func build_choices(rng: RandomNumberGenerator, count: int = 3) -> Array:
    if evolution_available():
        var result: Array = [_evolution]
        var filler := _non_maxed_pool()
        # remove evolution itself from filler candidates (shouldn't be there, but guard)
        filler = filler.filter(func(u): return u.id != _evolution.id)
        _shuffle_array(rng, filler)
        var needed := count - 1
        for i in min(needed, filler.size()):
            result.append(filler[i])
        return result

    # Normal path: draw count non-maxed upgrades without duplicate ids
    var pool := _non_maxed_pool()
    _shuffle_array(rng, pool)
    var result: Array = []
    var seen_ids: Dictionary = {}
    for u in pool:
        if seen_ids.has(u.id):
            continue
        result.append(u)
        seen_ids[u.id] = true
        if result.size() >= count:
            break
    return result


## Increment the level of upgrade u. If u is an EVOLUTION upgrade, mark evolved
## and emit GameEvents.evolution_unlocked with the character's evolution_id.
func apply(u: Upgrade) -> void:
    levels[u.id] = levels.get(u.id, 0) + 1
    if u.kind == Upgrade.Kind.EVOLUTION:
        evolved = true
        GameEvents.evolution_unlocked.emit(_character.evolution_id)


# --- private helpers ---

## Returns all candidate upgrades (signature + passive + generics) that are not maxed.
func _non_maxed_pool() -> Array:
    var pool: Array = []
    if not is_maxed(_signature):
        pool.append(_signature)
    if not is_maxed(_passive):
        pool.append(_passive)
    for g in _generic_pool:
        if not is_maxed(g):
            pool.append(g)
    return pool


## Fisher-Yates shuffle using the provided RNG.
func _shuffle_array(rng: RandomNumberGenerator, arr: Array) -> void:
    var n := arr.size()
    for i in range(n - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = arr[i]
        arr[i] = arr[j]
        arr[j] = tmp
