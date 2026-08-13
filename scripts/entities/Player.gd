extends Node3D
class_name Player
## Free 8-directional movement on the XZ plane (Y is height/elevation, used
## later for the confirmed cover/elevation combat mechanic — see
## docs/03_combat_system.md), or grid-snapped movement while in combat.

## Referenced via preload rather than the bare class_name — see the note on
## PlayerScript in scripts/core/GameManager.gd for why.
const GridScript := preload("res://scripts/systems/Grid.gd")
const StatsScript := preload("res://scripts/data/Stats.gd")
const InventoryScript := preload("res://scripts/systems/Inventory.gd")

enum MovementMode { FREE, GRID }

const SPEED := 4.0  # free-roam movement units/sec — unrelated to the 속도 combat stat below
const GRID_MOVE_COOLDOWN := 0.15  # seconds between grid steps while a direction is held

var movement_mode: MovementMode = MovementMode.FREE
var stats: StatsScript = StatsScript.new()
var inventory: InventoryScript = InventoryScript.new()
var _grid_move_timer := 0.0

func _process(delta: float) -> void:
	if movement_mode == MovementMode.FREE:
		_process_free_movement(delta)
	else:
		_process_grid_movement(delta)

func _process_free_movement(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
	position.x += input_dir.x * SPEED * _delta
	position.z += input_dir.y * SPEED * _delta

func _process_grid_movement(delta: float) -> void:
	_grid_move_timer -= delta
	if _grid_move_timer > 0.0:
		return
	var input_dir := Vector2i(
		int(Input.get_action_strength("move_right")) - int(Input.get_action_strength("move_left")),
		int(Input.get_action_strength("move_down")) - int(Input.get_action_strength("move_up"))
	)
	if input_dir == Vector2i.ZERO:
		return
	var target_cell := GridScript.world_to_cell(position) + input_dir
	position = GridScript.cell_to_world(target_cell, position.y)
	_grid_move_timer = GRID_MOVE_COOLDOWN

func enter_grid_mode() -> void:
	movement_mode = MovementMode.GRID
	position = GridScript.cell_to_world(GridScript.world_to_cell(position), position.y)
	_grid_move_timer = 0.0

func enter_free_mode() -> void:
	movement_mode = MovementMode.FREE
