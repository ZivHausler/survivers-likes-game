extends GutTest

const ORIGIN := Vector3(-100, 0, -100)
const SPAN := 200.0
var _inv := 65535.0 / SPAN
var _scale := SPAN / 65535.0

func test_roundtrip_preserves_ids_and_positions():
	var entries := [
		{"id": 1, "pos": Vector3(-100, 0, -100), "yaw": 0.0, "state": 0},
		{"id": 2, "pos": Vector3(0, 0, 50), "yaw": PI, "state": 1},
		{"id": 300, "pos": Vector3(99, 0, -20), "yaw": TAU * 0.75, "state": 2},
	]
	var bytes := EnemySnapshot.pack(entries, ORIGIN, _inv, 42)
	var out := EnemySnapshot.unpack(bytes, ORIGIN, _scale)
	assert_eq(out["tick"], 42)
	assert_eq(out["entries"].size(), 3)
	for i in range(3):
		var a: Dictionary = entries[i]
		var b: Dictionary = out["entries"][i]
		assert_eq(b["id"], a["id"])
		assert_eq(b["state"], a["state"])
		assert_almost_eq(b["pos"].x, a["pos"].x, 0.02)   # ~1/65535 * 200 ≈ 0.003 quantization
		assert_almost_eq(b["pos"].z, a["pos"].z, 0.02)
		assert_almost_eq(b["yaw"], a["yaw"], 0.01)

func test_byte_length_is_header_plus_9_per_entry():
	var entries := [{"id": 1, "pos": Vector3.ZERO, "yaw": 0.0, "state": 0}]
	var bytes := EnemySnapshot.pack(entries, ORIGIN, _inv, 0)
	assert_eq(bytes.size(), 4 + 9)   # u16 tick + u16 count + one 9-byte entry
