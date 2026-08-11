extends Node3D
## Placeholder dungeon scene. Stand near the ExtractionPoint marker and press
## E (interact) to extract back to town.

const INTERACT_RANGE := 1.5

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	var player: Node3D = GameManager.player
	if player == null:
		return
	if player.global_position.distance_to($ExtractionPoint.global_position) <= INTERACT_RANGE:
		GameManager.goto_town()
