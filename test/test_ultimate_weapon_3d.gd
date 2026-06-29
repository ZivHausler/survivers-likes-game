extends GutTest
## Manual ultimate: activate() gates on cooldown; tick() advances it.

# Minimal concrete subclass that records activations without a scene.
class _ProbeUlt extends UltimateWeapon3D:
	var fired := 0
	func _do_ult() -> void:
		fired += 1

func _make() -> _ProbeUlt:
	var u := _ProbeUlt.new()
	u.ult_cooldown = 10.0
	return u

func test_starts_ready() -> void:
	var u := _make()
	assert_true(u.is_ready(), "ult starts ready")
	assert_eq(u.cooldown_fraction(), 1.0)

func test_activate_fires_and_starts_cooldown() -> void:
	var u := _make()
	assert_true(u.activate(), "activate succeeds when ready")
	assert_eq(u.fired, 1, "_do_ult ran once")
	assert_false(u.is_ready(), "on cooldown after activate")

func test_activate_blocked_while_on_cooldown() -> void:
	var u := _make()
	u.activate()
	assert_false(u.activate(), "second activate blocked")
	assert_eq(u.fired, 1, "no extra _do_ult while on cooldown")

func test_tick_recovers_then_ready() -> void:
	var u := _make()
	u.activate()
	u.tick(10.0)               # full cooldown elapses
	assert_true(u.is_ready(), "ready after cooldown elapses")
	assert_true(u.activate(), "can fire again")
	assert_eq(u.fired, 2)

func test_fraction_midway() -> void:
	var u := _make()
	u.activate()
	u.tick(5.0)                # half of 10s
	assert_almost_eq(u.cooldown_fraction(), 0.5, 0.0001)
