extends Node
## Autoload singleton. Owns high-level game state and switches the active
## town/dungeon scene inside Main's scene container. Combat is not a separate
## scene here — per docs/02_dungeon_town_structure.md, field encounters turn
## the current dungeon scene into a combat grid in place, no scene load.
##
## The player node is created once and reparented into each new scene on
## switch (not recreated), so its position/state carries over.

enum GameState { TOWN, DUNGEON }

const TOWN_SCENE := "res://scenes/town/Town.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/Dungeon.tscn"
const PLAYER_SCENE := "res://scenes/entities/Player.tscn"

var current_state: GameState = GameState.TOWN
var scene_container: Node = null
var player: Node3D = null


func register_scene_container(container: Node) -> void:
	scene_container = container
	if player == null:
		player = load(PLAYER_SCENE).instantiate()


func goto_town() -> void:
	_change_scene(TOWN_SCENE, GameState.TOWN)


func goto_dungeon() -> void:
	_change_scene(DUNGEON_SCENE, GameState.DUNGEON)


func _change_scene(path: String, state: GameState) -> void:
	if scene_container == null:
		push_error("GameManager: no scene_container registered")
		return
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	for child in scene_container.get_children():
		child.queue_free()
	var new_scene: Node = load(path).instantiate()
	scene_container.add_child(new_scene)
	new_scene.add_child(player)
	current_state = state
