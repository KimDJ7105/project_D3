extends Node3D
## Town scene. Walk to the DungeonEntrance marker and press E to head into
## the dungeon, or to a TownFacility marker and press E to see who's there
## right now — see docs/02_dungeon_town_structure.md "마을" (roster
## structure, NPCs aren't placed directly on the map).

const TownFacilityScript := preload("res://scenes/town/TownFacility.gd")
const FacilityRosterScript := preload("res://scripts/systems/FacilityRoster.gd")

const INTERACT_RANGE := 1.5

@onready var _dialogue = $DialogueBox

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _dialogue.is_open():
		_dialogue.close()
		return
	var player: Node3D = GameManager.player
	if player == null:
		return
	if player.global_position.distance_to($DungeonEntrance.global_position) <= INTERACT_RANGE:
		GameManager.goto_dungeon()
		return
	for facility in get_tree().get_nodes_in_group("town_facility"):
		if player.global_position.distance_to(facility.global_position) <= INTERACT_RANGE:
			_enter_facility(facility)
			return

func _enter_facility(facility: TownFacilityScript) -> void:
	var present := FacilityRosterScript.resolve_present_npcs(facility.candidates)
	if present.is_empty():
		_dialogue.show_empty(facility.display_name)
		return
	var npc = present[0]
	RelationshipManager.register_npc(npc.npc_id, npc.faction_id)
	_dialogue.show_npc(npc)
