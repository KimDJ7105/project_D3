extends Node
## Root of the game. Holds the CurrentScene container that GameManager swaps
## between world scenes (2D or 3D — town/dungeon aren't required to share a
## rendering pipeline, so this stays a plain Node rather than Node2D/Node3D).

func _ready() -> void:
	GameManager.register_scene_container($CurrentScene)
	GameManager.goto_town()
