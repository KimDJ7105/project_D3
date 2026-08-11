extends Node3D
## Placeholder town scene. Stand near the DungeonEntrance marker and press
## E (interact) to head into the dungeon.

const INTERACT_RANGE := 1.5

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	var player: Node3D = GameManager.player
	if player == null:
		return
	if player.global_position.distance_to($DungeonEntrance.global_position) <= INTERACT_RANGE:
		GameManager.goto_dungeon()
