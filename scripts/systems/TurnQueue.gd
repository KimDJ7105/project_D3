extends RefCounted
class_name TurnQueue
## Speed-based initiative queue ("초리어티 큐", FF Tactics/Slay the Spire
## style — see docs/03_combat_system.md "턴 순서"). Each combatant
## accumulates CT (charge time) every tick proportional to their effective
## speed (see CombatFormulas.effective_speed); whoever crosses CT_THRESHOLD
## first acts. The winner keeps their overflow (ct -= threshold, not reset
## to 0), so speed differences smooth out over many turns instead of
## re-syncing every cycle.
##
## Not wired into an actual encounter yet — no combat scene/unit system
## exists. This is the isolated, independently-testable queue mechanism.

## TODO: balance value, tune via playtesting.
const CT_THRESHOLD := 100

var _speeds: Dictionary = {}  # id: String -> speed: int
var _ct: Dictionary = {}      # id: String -> ct: int


func add_combatant(id: String, speed: int) -> void:
	_speeds[id] = speed
	_ct[id] = 0


func remove_combatant(id: String) -> void:
	_speeds.erase(id)
	_ct.erase(id)


func has_combatant(id: String) -> bool:
	return _speeds.has(id)


## Advances time until exactly one combatant is ready, applies their CT
## deduction, and returns their id. Empty string if no combatants remain.
## If multiple combatants cross the threshold on the same tick, the fastest
## acts first; the others keep their overflow and go on a following call.
func advance() -> String:
	if _speeds.is_empty():
		return ""
	while true:
		var ready: Array = []
		for id in _speeds:
			_ct[id] += _speeds[id]
			if _ct[id] >= CT_THRESHOLD:
				ready.append(id)
		if not ready.is_empty():
			ready.sort_custom(func(a, b): return _speeds[a] > _speeds[b])
			var winner: String = ready[0]
			_ct[winner] -= CT_THRESHOLD
			return winner
	return ""  # unreachable — the loop above always returns once ct crosses the threshold


## Non-mutating look-ahead: simulates `count` future turns on a copy of the
## current state, without touching the real queue. For a turn-order preview UI later.
func peek_order(count: int) -> Array:
	var speeds_copy: Dictionary = _speeds.duplicate()
	var ct_copy: Dictionary = _ct.duplicate()
	var result: Array = []
	for _i in range(count):
		if speeds_copy.is_empty():
			break
		while true:
			var ready: Array = []
			for id in speeds_copy:
				ct_copy[id] += speeds_copy[id]
				if ct_copy[id] >= CT_THRESHOLD:
					ready.append(id)
			if not ready.is_empty():
				ready.sort_custom(func(a, b): return speeds_copy[a] > speeds_copy[b])
				var winner: String = ready[0]
				ct_copy[winner] -= CT_THRESHOLD
				result.append(winner)
				break
	return result
