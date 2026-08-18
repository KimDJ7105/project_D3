extends Node3D
class_name TownFacility
## A town facility marker (e.g. tavern) — see docs/02_dungeon_town_structure.md
## "마을": NPCs aren't placed on the map here, this node just answers "who's
## here right now" via FacilityRoster when the player interacts with it.

const NPCDataScript := preload("res://scripts/data/NPCData.gd")

@export var facility_id: String = ""
@export var display_name: String = ""
@export var candidates: Array[NPCDataScript] = []
