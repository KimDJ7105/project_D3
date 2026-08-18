extends Node3D
## Placeholder dungeon scene. Walking near the Enemy marker automatically
## triggers grid-based combat — a placeholder stand-in for the real
## encounter trigger (see docs/02_dungeon_town_structure.md). Q manually
## toggles combat mode too, for testing.
##
## E (interact) is context-sensitive: attack an adjacent living enemy on
## your turn, loot an adjacent dead one, or extract at the gold block.
## Dragging a throwable inventory item onto a grid tile throws it there
## instead (see InventoryPanel.item_throw_requested).
## No real enemy AI exists — on its turn the enemy always attacks the
## player (the only behavior it has), see docs/05_decisions_log.md.

const MonsterScript := preload("res://scripts/entities/Monster.gd")
const TurnQueueScript := preload("res://scripts/systems/TurnQueue.gd")
const CombatFormulasScript := preload("res://scripts/systems/CombatFormulas.gd")
const GridScript := preload("res://scripts/systems/Grid.gd")

const INTERACT_RANGE := 1.5
const ENCOUNTER_RANGE := 2.5
const PLAYER_ID := "player"

@onready var _label: Label = $UI/Label
@onready var _grid_overlay: MeshInstance3D = $GridOverlay
@onready var _enemy: MonsterScript = $Enemy

var _turn_queue = null
var _current_turn_id: String = ""

func _ready() -> void:
	_enemy.died.connect(_on_enemy_died)
	var inventory_panel = GameManager.player.get_node("InventoryPanel")
	inventory_panel.item_throw_requested.connect(_on_item_thrown)

func _process(_delta: float) -> void:
	if GameManager.in_combat:
		return
	var player: Node3D = GameManager.player
	if player == null or _enemy == null or _enemy.state != MonsterScript.State.ALIVE:
		return
	if player.global_position.distance_to(_enemy.global_position) <= ENCOUNTER_RANGE:
		_enter_combat()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_on_interact()
	elif event.is_action_pressed("debug_toggle_combat"):
		if GameManager.in_combat:
			_exit_combat()
		else:
			_enter_combat()

func _on_interact() -> void:
	var player: Node3D = GameManager.player
	if player == null:
		return
	var near_enemy: bool = player.global_position.distance_to(_enemy.global_position) <= INTERACT_RANGE

	if GameManager.in_combat and near_enemy and _enemy.state == MonsterScript.State.ALIVE:
		if _current_turn_id == PLAYER_ID:
			_do_attack()
		return
	if near_enemy and _enemy.state == MonsterScript.State.DEAD:
		_do_loot()
		return
	_try_extract()

func _try_extract() -> void:
	var player: Node3D = GameManager.player
	if player.global_position.distance_to($ExtractionPoint.global_position) <= INTERACT_RANGE:
		GameManager.goto_town()

func _enter_combat() -> void:
	GameManager.start_combat()
	_grid_overlay.visible = true
	_turn_queue = TurnQueueScript.new()
	_turn_queue.add_combatant(PLAYER_ID, CombatFormulasScript.effective_speed(GameManager.player.stats))
	_turn_queue.add_combatant(_enemy.data.monster_id, CombatFormulasScript.effective_speed(_enemy.stats))
	_current_turn_id = _turn_queue.advance()
	_update_label()

func _exit_combat() -> void:
	GameManager.end_combat()
	_grid_overlay.visible = false
	_turn_queue = null
	_current_turn_id = ""
	_update_label()

func _do_attack() -> void:
	var player = GameManager.player
	var damage: int = CombatFormulasScript.basic_attack_damage(player.stats)
	_enemy.take_damage(damage)
	_advance_past_enemy_turn()
	_update_label()

## Dragging a throwable item from the inventory onto a grid tile during
## combat calls this (via InventoryPanel's item_throw_requested signal).
## The item is spent and the turn passes regardless of whether it actually
## hit anything — missing still costs you the item and the turn, same as a
## real throw would. See docs/10_inventory_system.md "전투 중 투척".
func _on_item_thrown(item: Resource, cell: Vector2i) -> void:
	if not (GameManager.in_combat and _current_turn_id == PLAYER_ID):
		return
	GameManager.player.inventory.remove_item(item, 1)
	if _enemy.state == MonsterScript.State.ALIVE:
		var enemy_cell: Vector2i = GridScript.world_to_cell(_enemy.global_position)
		if enemy_cell == cell:
			_enemy.take_damage(item.throw_damage)
	_advance_past_enemy_turn()
	_update_label()

## Shared by _do_attack() and _on_item_thrown(): consumes the player's own
## turn, then runs the enemy's only behavior ("attack the player") for
## however many CT cycles it gets, until control returns to the player.
func _advance_past_enemy_turn() -> void:
	if _enemy.state != MonsterScript.State.ALIVE:
		return
	# _current_turn_id is still "player" at this point (advance() hasn't run
	# since _enter_combat() or the last action) — consume it first, or the
	# loop below would never run.
	_current_turn_id = _turn_queue.advance()
	while _current_turn_id != PLAYER_ID:
		if _current_turn_id == _enemy.data.monster_id:
			if _enemy_attack():
				return  # player was defeated; combat already ended and scene changed
		_current_turn_id = _turn_queue.advance()

## Returns true if this attack defeated the player — caller must stop
## touching combat state immediately afterward, since _handle_player_defeat
## already exits combat and switches scenes.
func _enemy_attack() -> bool:
	var player = GameManager.player
	var damage: int = CombatFormulasScript.basic_attack_damage(_enemy.stats)
	player.take_damage(damage)
	if player.current_hp <= 0:
		_handle_player_defeat()
		return true
	return false

## Placeholder "survive and retreat" outcome — real death/extraction
## consequences belong to the "세계 충돌" system
## (docs/07_progression_death_system.md), which isn't built yet.
func _handle_player_defeat() -> void:
	_exit_combat()
	GameManager.player.heal_to_full()
	GameManager.goto_town()

func _do_loot() -> void:
	var loot: Array = _enemy.loot()
	for entry in loot:
		GameManager.player.inventory.add_item(entry.item, entry.quantity)
	_update_label()

func _on_enemy_died(_monster: MonsterScript) -> void:
	_exit_combat()

func _update_label() -> void:
	if _enemy.state == MonsterScript.State.DEAD and not _enemy.dropped_loot.is_empty():
		_label.text = "DUNGEON — the skeleton's corpse has loot. Walk up and press E to loot it."
	elif GameManager.in_combat:
		_label.text = "GRID COMBAT MODE (test) — click a cell to move, E to attack, drag a throwable item onto a tile to throw it, Q to flee"
	else:
		_label.text = "DUNGEON — WASD to move, walk to the gold block and press E to extract back to town (Q: test grid mode)"
