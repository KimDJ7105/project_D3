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

## Town facility roster fields — see docs/02_dungeon_town_structure.md "마을".
## v1 scope: only the random tier is implemented (see FacilityRoster.gd);
## quest/condition tiers are stubbed to always pass through to random.
@export var home_facility_id: String = ""  # matches TownFacility.facility_id
@export_range(0.0, 1.0) var appearance_chance: float = 0.5  # random-tier "단골" chance — placeholder, balancing TBD
@export_multiline var greeting: String = ""  # stand-in for a real dialogue system, which doesn't exist yet
