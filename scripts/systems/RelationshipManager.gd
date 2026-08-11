extends Node
## Autoload singleton. Tracks relationship values between the player and
## NPCs/factions, and exposes lookups other systems (dialogue, dungeon
## events, combat) query to react to relationship state.
##
## Structure (see docs/01_relationship_system.md for the full reasoning):
## - Single scalar affinity per relationship for now (v1) — kept simple on
##   purpose, but callers should treat "affinity" as an opaque relationship
##   value rather than assuming it's the only axis that will ever exist, so
##   a later move to multiple axes (trust/fear/etc.) doesn't force a rewrite.
## - An NPC's individual affinity is seeded from their faction's reputation
##   on first encounter, then evolves mostly independently — but continues
##   to get dragged (dampened) by later faction reputation changes. The drag
##   shrinks the further the individual affinity already is from neutral, so
##   a strongly-held personal bond resists being swept by faction politics.
##   At the extremes (+-100) the drag hits zero — intentional, AS LONG AS
##   reaching +-100 is actually hard/rare in practice; revisit if balancing
##   makes that too easy.
## - Individual traits (greed, altruism, etc.) are NOT stored here — they're
##   a property of the NPC itself (data/npcs/), independent of whether the
##   player has any relationship with them at all.

const AFFINITY_MIN := -100
const AFFINITY_MAX := 100

## TODO: balance value, tune via playtesting once there's real NPC/faction
## content to test against. Portion of faction reputation a newly-met NPC's
## starting affinity inherits.
const FACTION_SEED_WEIGHT := 0.5

var faction_reputation: Dictionary = {}  # faction_id: String -> affinity: int
var npc_relationships: Dictionary = {}  # npc_id: String -> {affinity, faction_id, memory, is_named}


func get_faction_reputation(faction_id: String) -> int:
	return faction_reputation.get(faction_id, 0)


func change_faction_reputation(faction_id: String, delta: int) -> void:
	var current: int = get_faction_reputation(faction_id)
	faction_reputation[faction_id] = clampi(current + delta, AFFINITY_MIN, AFFINITY_MAX)

	for npc_id: String in npc_relationships:
		var rel: Dictionary = npc_relationships[npc_id]
		if rel.get("faction_id", "") != faction_id:
			continue
		var dragged: float = _compute_faction_drag(rel.affinity, delta)
		rel.affinity = clampi(rel.affinity + roundi(dragged), AFFINITY_MIN, AFFINITY_MAX)


## TODO: balance formula, tune via playtesting — see docs/01_relationship_system.md.
## Currently: the further an NPC's individual affinity already is from
## neutral (0), the less a faction reputation change drags it.
func _compute_faction_drag(current_affinity: int, faction_delta: int) -> float:
	var resistance: float = abs(current_affinity) / float(AFFINITY_MAX)
	return faction_delta * (1.0 - resistance)


func register_npc(npc_id: String, faction_id: String = "") -> void:
	if npc_relationships.has(npc_id):
		return
	var seed_affinity: int = 0
	if faction_id != "":
		seed_affinity = roundi(get_faction_reputation(faction_id) * FACTION_SEED_WEIGHT)
	npc_relationships[npc_id] = {
		"affinity": clampi(seed_affinity, AFFINITY_MIN, AFFINITY_MAX),
		"faction_id": faction_id,
		"memory": [],
		"is_named": false,
	}


func get_npc_affinity(npc_id: String) -> int:
	if not npc_relationships.has(npc_id):
		return 0
	return npc_relationships[npc_id].affinity


func change_npc_affinity(npc_id: String, delta: int) -> void:
	if not npc_relationships.has(npc_id):
		register_npc(npc_id)
	var rel: Dictionary = npc_relationships[npc_id]
	rel.affinity = clampi(rel.affinity + delta, AFFINITY_MIN, AFFINITY_MAX)


func add_npc_memory(npc_id: String, tag: String) -> void:
	if not npc_relationships.has(npc_id):
		register_npc(npc_id)
	npc_relationships[npc_id].memory.append(tag)
