class_name EnemySnapshot
extends RefCounted

# Entry layout (9 bytes): u16 id, u16 x, u16 z, u16 yaw, u8 state. Header: u16 tick, u16 count.
static func pack(entries: Array, origin: Vector3, inv_scale: float, tick: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4 + entries.size() * 9)
	b.encode_u16(0, tick & 0xFFFF)
	b.encode_u16(2, entries.size() & 0xFFFF)
	var off := 4
	for e in entries:
		var p: Vector3 = e["pos"]
		var qx := clampi(int((p.x - origin.x) * inv_scale), 0, 65535)
		var qz := clampi(int((p.z - origin.z) * inv_scale), 0, 65535)
		var yaw: float = fposmod(float(e["yaw"]), TAU)
		var qy := clampi(int(yaw / TAU * 65535.0), 0, 65535)
		b.encode_u16(off, int(e["id"]) & 0xFFFF); off += 2
		b.encode_u16(off, qx); off += 2
		b.encode_u16(off, qz); off += 2
		b.encode_u16(off, qy); off += 2
		b.encode_u8(off, int(e["state"]) & 0xFF); off += 1
	return b

static func unpack(bytes: PackedByteArray, origin: Vector3, scale: float) -> Dictionary:
	var tick := bytes.decode_u16(0)
	var count := bytes.decode_u16(2)
	var entries := []
	var off := 4
	for i in range(count):
		var id := bytes.decode_u16(off); off += 2
		var qx := bytes.decode_u16(off); off += 2
		var qz := bytes.decode_u16(off); off += 2
		var qy := bytes.decode_u16(off); off += 2
		var st := bytes.decode_u8(off); off += 1
		entries.append({
			"id": id,
			"pos": Vector3(origin.x + qx * scale, 0.0, origin.z + qz * scale),
			"yaw": float(qy) / 65535.0 * TAU,
			"state": st,
		})
	return {"tick": tick, "entries": entries}
