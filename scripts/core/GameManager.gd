extends Node
## Autoload singleton. Owns high-level game state and switches the active
## town/dungeon scene inside Main's scene container. Combat is not a separate
## scene here — per docs/02_dungeon_town_structure.md, field encounters turn
## the current dungeon scene into a combat grid in place, no scene load.
##
## The player node is created once and reparented into each new scene on
## switch (not recreated), so its position/state carries over.

## Referenced via preload (not the bare `Player` class_name) so type
## resolution doesn't depend on Godot's global script class cache being
## warm — that cache is only rebuilt by an editor project scan, and an
## autoload failing to parse takes the whole game down with it.
const PlayerScript := preload("res://scripts/entities/Player.gd")

enum GameState { TOWN, DUNGEON }

const TOWN_SCENE := "res://scenes/town/Town.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/Dungeon.tscn"
const PLAYER_SCENE := "res://scenes/entities/Player.tscn"

var current_state: GameState = GameState.TOWN
var scene_container: Node = null
var player: PlayerScript = null
var in_combat: bool = false


func register_scene_container(container: Node) -> void:
	scene_container = container
	if player == null:
		player = load(PLAYER_SCENE).instantiate() as PlayerScript


func goto_town() -> void:
	if in_combat:
		end_combat()
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


## Temporary stand-in for the real encounter trigger (field contact with an
## enemy — see docs/02_dungeon_town_structure.md). Only switches player
## movement mode for now; no actual grid/turn/combat systems exist yet.
func start_combat() -> void:
	in_combat = true
	if player:
		player.enter_grid_mode()


func end_combat() -> void:
	in_combat = false
	if player:
		player.enter_free_mode()
