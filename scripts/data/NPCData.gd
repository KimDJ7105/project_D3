extends Resource
class_name NPCData
## Static/authored identity for a NAMED NPC (pre-authored table/trigger NPCs,
## or a random NPC that has been "promoted" — see docs/01_relationship_system.md).
## Anonymous random NPCs don't need this at all until/unless they're promoted;
## their relationship state alone lives in RelationshipManager.npc_relationships.

@export var npc_id: String = ""  # matches the key used in RelationshipManager
@export var display_name: String = ""
@export var faction_id: String = ""  # "" if unaffiliated — matches FactionData.faction_id

## True for pre-authored table/trigger NPCs and promoted random NPCs alike.
## (A plain false-by-default NPCData wouldn't make sense — anonymous NPCs
## simply don't get one — but kept explicit rather than assumed.)
@export var is_named: bool = true

@export var sprite: Texture2D  # in-game pixel sprite (billboard)
@export var portrait: Texture2D  # painted dialogue bust portrait — named NPCs only, see docs/09_aseprite_pixel_pipeline.md

## trait_name -> value. Exact trait list/value range not decided yet
## (docs/01_relationship_system.md "개인 특성" section) — left open on purpose.
@export var traits: Dictionary = {}
