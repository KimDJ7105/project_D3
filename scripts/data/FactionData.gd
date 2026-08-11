extends Resource
class_name FactionData
## Static/authored definition of a faction. faction_id is the key used by
## RelationshipManager.faction_reputation and NPCData.faction_id — see
## docs/08_world_and_factions.md for the (not-yet-final) example faction list.

@export var faction_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
