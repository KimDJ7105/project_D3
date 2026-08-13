extends Node3D
## Placeholder dungeon scene. Stand near the ExtractionPoint marker and press
## E (interact) to extract back to town. Walking near the Enemy marker
## automatically triggers grid-based combat mode — a placeholder stand-in
## for the real encounter trigger (field contact with an enemy, see
## docs/02_dungeon_town_structure.md). Q manually toggles combat mode too,
## for testing without needing to walk back to the enemy.

const INTERACT_RANGE := 1.5
const ENCOUNTER_RANGE := 2.5

@onready var _label: Label = $UI/Label
@onready var _grid_overlay: MeshInstance3D = $GridOverlay
@onready var _enemy: Node3D = $Enemy

func _process(_delta: float) -> void:
	if GameManager.in_combat:
		return
	var player: Node3D = GameManager.player
	if player == null or _enemy == null:
		return
	if player.global_position.distance_to(_enemy.global_position) <= ENCOUNTER_RANGE:
		_enter_combat()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_extract()
	elif event.is_action_pressed("debug_toggle_combat"):
		if GameManager.in_combat:
			_exit_combat()
		else:
			_enter_combat()

func _try_extract() -> void:
	var player: Node3D = GameManager.player
	if player == null:
		return
	if player.global_position.distance_to($ExtractionPoint.global_position) <= INTERACT_RANGE:
		GameManager.goto_town()

func _enter_combat() -> void:
	GameManager.start_combat()
	_grid_overlay.visible = true
	_label.text = "GRID COMBAT MODE (test) — press Q to return to free movement"

func _exit_combat() -> void:
	GameManager.end_combat()
	_grid_overlay.visible = false
	_label.text = "DUNGEON — WASD to move, walk to the gold block and press E to extract back to town (Q: test grid mode)"
