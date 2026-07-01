class_name RespawnRules
extends RefCounted

const DOWNED_TIME: float = 10.0
const REVIVE_HP_FRACTION: float = 0.5
const REVIVE_INVULN: float = 4.0
const RESPAWN_BASE: float = 15.0
const RESPAWN_PER_DEATH: float = 9.0
const RESPAWN_CAP: float = 60.0

static func respawn_delay(deaths: int) -> float:
	return minf(RESPAWN_BASE + RESPAWN_PER_DEATH * float(deaths), RESPAWN_CAP)
