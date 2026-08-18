extends RefCounted
class_name FacilityRoster
## Resolves which NPCs are present at a town facility right now — see
## docs/02_dungeon_town_structure.md "마을" for the confirmed priority order
## (quest state > condition met > random). v1 scope: only the random tier
## has real content; quest/condition are stubbed as pass-through hooks so
## the priority structure is in place before a quest/condition system exists.

const NPCDataScript := preload("res://scripts/data/NPCData.gd")

static func resolve_present_npcs(candidates: Array[NPCDataScript]) -> Array[NPCDataScript]:
	var present: Array[NPCDataScript] = []
	for npc in candidates:
		if _quest_requires_presence(npc):
			present.append(npc)
			continue
		if _condition_met(npc):
			present.append(npc)
			continue
		if randf() < npc.appearance_chance:
			present.append(npc)
	return present

## TODO: no quest system exists yet (docs/02_dungeon_town_structure.md 열린 질문).
## Always false until one does.
static func _quest_requires_presence(_npc: NPCDataScript) -> bool:
	return false

## TODO: condition types (time of day, affinity threshold, story flags, ...)
## not decided yet. Always false until a condition schema exists.
static func _condition_met(_npc: NPCDataScript) -> bool:
	return false
