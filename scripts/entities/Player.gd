extends Node3D
class_name Player
## Free 8-directional movement on the XZ plane (Y is height/elevation, used
## later for the confirmed cover/elevation combat mechanic — see
## docs/03_combat_system.md) while exploring, or click-to-move grid
## movement while in combat.

## Referenced via preload rather than the bare class_name — see the note on
## PlayerScript in scripts/core/GameManager.gd for why.
const GridScript := preload("res://scripts/systems/Grid.gd")
const StatsScript := preload("res://scripts/data/Stats.gd")
const InventoryScript := preload("res://scripts/systems/Inventory.gd")

enum MovementMode { FREE, GRID }

const SPEED := 4.0  # free-roam movement units/sec — unrelated to the 속도 combat stat below

signal died

var movement_mode: MovementMode = MovementMode.FREE
var stats: StatsScript = StatsScript.new()
var inventory: InventoryScript = InventoryScript.new()
var current_hp: int

@onready var _camera: Camera3D = $Camera3D
@onready var _inventory_panel: CanvasLayer = $InventoryPanel
@onready var _hud: CanvasLayer = $PlayerHUD

func _ready() -> void:
	current_hp = stats.vitality
	_inventory_panel.bind(inventory)
	_hud.bind(self)

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	if current_hp <= 0:
		died.emit()

## Placeholder for the "survive and retreat" outcome on defeat — real death
## consequences belong to the "세계 충돌" system (docs/07_progression_death_system.md),
## not built yet.
func heal_to_full() -> void:
	current_hp = stats.vitality

func _process(delta: float) -> void:
	if movement_mode == MovementMode.FREE:
		_process_free_movement(delta)
	# GRID mode movement is event-driven (mouse click, see _unhandled_input),
	# not polled here.

func _process_free_movement(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
	position.x += input_dir.x * SPEED * _delta
	position.z += input_dir.y * SPEED * _delta

func _unhandled_input(event: InputEvent) -> void:
	if movement_mode != MovementMode.GRID:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# TODO: no movement-range/이동력 budget exists yet (docs/03_combat_system.md
	# 열린 질문) — this teleports to any clicked cell with no distance limit.
	var cell = GridScript.raycast_to_cell(_camera, event.position)
	if cell != null:
		position = GridScript.cell_to_world(cell, position.y)

func enter_grid_mode() -> void:
	movement_mode = MovementMode.GRID
	position = GridScript.cell_to_world(GridScript.world_to_cell(position), position.y)

func enter_free_mode() -> void:
	movement_mode = MovementMode.FREE
