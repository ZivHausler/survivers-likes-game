# See docs/notes/weapon-orbit-3d.md
class_name OrbitWeapon3D extends Weapon3D
## Reusable archetype: N orbiting Area3D hitboxes rotating around the player.
##
## Exported params control count, radius, speed, and damage.
## Subclasses override defaults in _ready() before calling super().
##
## Damage is dealt once per base_cooldown window (timer-driven fire()),
## with a per-enemy hit-cooldown of HIT_CD_MS ms to prevent every-frame spam.
## All positions are in XZ world units (Y = 0, 1 unit ≈ 16 px).

## Milliseconds between hits on the same enemy by any orbiter.
const HIT_CD_MS: int = 500
## World units an enemy is hopped radially outward (away from the character) when an
## orb touches it. Delivered as a short arc via Enemy3D.apply_knockback (throttled by
## HIT_CD_MS), not an instant teleport.
const ORB_KNOCKBACK_DIST: float = 2.5

## Number of orbiter nodes (Area3D) maintained around the player.
var orbit_count: int = 3
## Distance from weapon origin to each orbiter, in world units.
var orbit_radius: float = 3.0
## Angular velocity of the orbiter ring, in radians per second.
var orbit_speed: float = TAU / 3.0
## Base damage per hit (multiplied by stats.damage_mult).
var damage: float = 12.0

## Current rotation phase of the orbiter ring (radians).
var _phase: float = 0.0
## Live orbiter nodes — rebuilt whenever orbit_count changes.
var _orbiters: Array[Area3D] = []
## Per-enemy hit cooldown: instance_id → expiry tick (msec).
var _hit_cd: Dictionary = {}

func _init() -> void:
	base_cooldown = 2.5
	vfx_id = &"orbit_cast"
	vfx_color = VisualPalette.role(&"player_secondary")  # palette: gold/orbit glow

func _ready() -> void:
	super()
	_rebuild_orbiters()

func _process(dt: float) -> void:
	if _orbiters.is_empty():
		return
	_phase += orbit_speed * dt
	var offsets: Array = orbiter_offsets(orbit_count, orbit_radius, _phase)
	for i in range(_orbiters.size()):
		if i < offsets.size():
			_orbiters[i].position = offsets[i]

## Continuous grind: the orbiters are an always-on aura, so the damage scan runs
## every physics frame — NOT gated by base_cooldown. The per-enemy HIT_CD_MS window
## throttles repeat hits so a spinning orbiter grinds an enemy at a steady rate
## instead of every-frame spam. Damaging here (not only in the timer-driven fire())
## is what makes orbiters actually connect: enemies pass through the ring between
## cooldown ticks, so a once-per-cooldown scan almost never overlapped anyone.
func _physics_process(_dt: float) -> void:
	if _orbiters.is_empty():
		return
	_apply_orbit_damage(Time.get_ticks_msec())

## Timer-driven fire: kept for the cast-VFX pulse and direct test calls. The actual
## grinding is done continuously in _physics_process; this is a harmless extra scan
## (HIT_CD_MS dedupes it against the per-frame scan).
func fire() -> void:
	_apply_orbit_damage(Time.get_ticks_msec())

## Scan every orbiter's overlapping bodies and deal damage, respecting the per-enemy
## hit cooldown so the same enemy is only hit once per HIT_CD_MS regardless of how
## many orbiters (or how many frames) touch it.
func _apply_orbit_damage(now: int) -> void:
	if not stats:
		return
	_expire_hit_cd(now)
	var dmg: float = damage * stats.damage_mult
	for orbiter: Area3D in _orbiters:
		for body in orbiter.get_overlapping_bodies():
			if not body.is_in_group("enemies"):
				continue
			var eid: int = body.get_instance_id()
			if _hit_cd.has(eid):
				continue
			_hit_cd[eid] = now + HIT_CD_MS
			if body.has_method("take_damage"):
				body.take_damage(dmg)
				GameEvents.skill_hit.emit(vfx_id, vfx_color, (body as Node3D).global_position)
			# Knockback: hop the enemy radially OUTWARD from the character (XZ plane).
			# `global_position` is this weapon's origin, which sits on the player, so the
			# ring's centre = the character. Pushing outward from there (rather than away
			# from the orb) keeps enemies from being flung sideways in the orb's travel
			# direction. Prefer the enemy's animated hop; fall back to a direct nudge for
			# bodies without it. Only happens on an actual orb overlap.
			var enemy3d := body as Node3D
			if enemy3d:
				var away: Vector3 = enemy3d.global_position - global_position
				away.y = 0.0
				if away.length_squared() < 0.0001:
					away = Vector3(1.0, 0.0, 0.0)
				if enemy3d.has_method("apply_knockback"):
					enemy3d.apply_knockback(away, ORB_KNOCKBACK_DIST)
				else:
					enemy3d.global_position += away.normalized() * ORB_KNOCKBACK_DIST

## Level up: +1 orbiter, +4 damage, rebuild ring.
func level_up() -> void:
	super()
	orbit_count += 1
	damage += 4.0
	_rebuild_orbiters()

## Evolve: double orbit_count and increase orbit_speed (synergy bonus).
func evolve() -> void:
	super()
	orbit_count *= 2
	orbit_speed *= 1.5
	_rebuild_orbiters()

## Passive bonus: boosts damage directly.
func apply_passive(value: float) -> void:
	damage += value

# ─────────────────────────────────────────────────────────────────────────────
# Pure / testable helpers
# ─────────────────────────────────────────────────────────────────────────────

## Return XZ positions for `count` orbiters evenly distributed at `radius`
## starting at `phase` radians.  Y is always 0.
## Exposed as a static pure function so tests can verify geometry without
## instantiating any scene or physics.
static func orbiter_offsets(count: int, radius: float, phase: float) -> Array:
	var result: Array = []
	if count <= 0:
		return result
	for i: int in range(count):
		var angle: float = TAU * float(i) / float(count) + phase
		result.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return result

# ─────────────────────────────────────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────────────────────────────────────

## Remove and re-add all orbiter Area3D children to match orbit_count.
func _rebuild_orbiters() -> void:
	# Remove old orbiters.
	for o: Area3D in _orbiters:
		if is_instance_valid(o):
			o.queue_free()
	_orbiters.clear()
	# Add new orbiters.
	var offsets: Array = orbiter_offsets(orbit_count, orbit_radius, _phase)
	for i: int in range(orbit_count):
		var area: Area3D = Area3D.new()
		area.collision_layer = 0
		area.collision_mask  = 8  # physics layer 8 = enemies
		area.monitoring  = true
		area.monitorable = false
		# Collision shape.
		var col: CollisionShape3D = CollisionShape3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.6
		col.shape = sphere
		area.add_child(col)
		# Visible emissive sphere so players can see the orbiters circling.
		# Raised to torso height (y=1.0 local) so it does not clip into the ground;
		# the Area3D collision stays at Y=0 for reliable hit detection.
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.4
		sphere_mesh.height  = 0.8
		mi.mesh = sphere_mesh
		mi.position = Vector3(0.0, 1.0, 0.0)
		# Fresh material per orbiter — never share a resource across instances.
		var mat := StandardMaterial3D.new()
		mat.albedo_color = vfx_color
		mat.emission_enabled = true
		mat.emission = vfx_color
		mat.emission_energy_multiplier = 2.0
		mi.material_override = mat
		area.add_child(mi)
		area.position = offsets[i]
		add_child(area)
		_orbiters.append(area)

## Purge expired hit-cooldown entries older than `now`.
func _expire_hit_cd(now: int) -> void:
	var to_remove: Array = []
	for k: int in _hit_cd:
		if _hit_cd[k] <= now:
			to_remove.append(k)
	for k: int in to_remove:
		_hit_cd.erase(k)
