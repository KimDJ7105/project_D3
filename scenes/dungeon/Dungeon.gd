extends Node3D
## Placeholder dungeon scene. Walking near the Enemy marker automatically
## triggers combat — a placeholder stand-in for the real encounter trigger
## (see docs/02_dungeon_town_structure.md). Q manually toggles combat mode
## too, for testing.
##
## Combat uses free movement + stamina, not a grid (docs/03_combat_system.md
## "전투 중 이동과 스테미나", 2026-08-18). A turn no longer ends
## automatically after one action — the player explicitly ends their turn
## (F / "end_turn") once they're done moving/acting within their stamina
## budget. Movement can be freely undone (R / "undo_movement") until the
## player attacks or throws something — see Player.mark_acted().
##
## E (interact) is context-sensitive: attack a living enemy in range on
## your turn, loot an adjacent dead one, or extract at the gold block.
## Dragging a throwable inventory item onto the world throws it there
## instead (see InventoryPanel.item_throw_requested).
## No real enemy AI exists — on its turn the enemy always attacks the
## player (the only behavior it has), see docs/05_decisions_log.md.

const MonsterScript := preload("res://scripts/entities/Monster.gd")
const TurnQueueScript := preload("res://scripts/systems/TurnQueue.gd")
const CombatFormulasScript := preload("res://scripts/systems/CombatFormulas.gd")
const TargetingScript := preload("res://scripts/systems/Targeting.gd")

const INTERACT_RANGE := 1.5
const ENCOUNTER_RANGE := 2.5
const PLAYER_ID := "player"

@onready var _label: Label = $UI/Label
@onready var _movement_indicator: MeshInstance3D = $MovementRangeIndicator
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
	elif event.is_action_pressed("end_turn"):
		_end_turn()
	elif event.is_action_pressed("undo_movement"):
		_undo_movement()
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
	_turn_queue = TurnQueueScript.new()
	_turn_queue.add_combatant(PLAYER_ID, CombatFormulasScript.effective_speed(GameManager.player.stats))
	_turn_queue.add_combatant(_enemy.data.monster_id, CombatFormulasScript.effective_speed(_enemy.stats))
	_current_turn_id = _turn_queue.advance()
	_resolve_enemy_turns()
	_update_label()

func _exit_combat() -> void:
	GameManager.end_combat()
	_movement_indicator.visible = false
	_turn_queue = null
	_current_turn_id = ""
	_update_label()

## Costs stamina and requires being in range — no more free unlimited
## attacks regardless of position now that positioning actually matters
## (docs/03_combat_system.md). Locks out undo_movement() for the rest of
## the turn once it lands — see Player.mark_acted().
func _do_attack() -> void:
	var player = GameManager.player
	if player.current_stamina < CombatFormulasScript.BASIC_ATTACK_STAMINA_COST:
		return
	var damage: int = CombatFormulasScript.basic_attack_damage(player.stats)
	player.current_stamina -= CombatFormulasScript.BASIC_ATTACK_STAMINA_COST
	player.mark_acted()
	_enemy.take_damage(damage)
	_update_label()

## Undoes all movement done this turn — resets position and stamina back to
## how they were at the start of the turn. Free (costs nothing, doesn't end
## the turn) but only available before the player has attacked or thrown
## anything this turn — see Player.can_undo_movement().
func _undo_movement() -> void:
	if not (GameManager.in_combat and _current_turn_id == PLAYER_ID):
		return
	GameManager.player.undo_movement()
	_update_label()

## Ends the player's turn: no more actions from them until it cycles back
## around. Runs the enemy's turn(s) immediately after, same as combat entry.
func _end_turn() -> void:
	if not (GameManager.in_combat and _current_turn_id == PLAYER_ID):
		return
	GameManager.player.end_turn()
	_movement_indicator.visible = false
	_current_turn_id = _turn_queue.advance()
	_resolve_enemy_turns()
	_update_label()

## Dragging a throwable item from the inventory and dropping it on the world
## during combat calls this (via InventoryPanel's item_throw_requested
## signal). A target beyond the item's throw_range is rejected outright
## (nothing spent); within range but missing the enemy (outside
## effect_radius) still spends the item and stamina — "던지면 못 무른다"
## (docs/10_inventory_system.md "전투 중 투척"). Does not end the turn —
## only an explicit end_turn() does now (docs/03_combat_system.md).
func _on_item_thrown(item: Resource, target_point: Vector3) -> void:
	if not (GameManager.in_combat and _current_turn_id == PLAYER_ID):
		return
	var player = GameManager.player
	if player.current_stamina < CombatFormulasScript.BASIC_ATTACK_STAMINA_COST:
		return
	if TargetingScript.flat_distance(player.global_position, target_point) > item.throw_range:
		return
	player.current_stamina -= CombatFormulasScript.BASIC_ATTACK_STAMINA_COST
	player.mark_acted()
	player.inventory.remove_item(item, 1)
	if _enemy.state == MonsterScript.State.ALIVE:
		if TargetingScript.flat_distance(target_point, _enemy.global_position) <= item.effect_radius:
			_enemy.take_damage(item.throw_damage)
	_update_label()

## Runs any leading enemy turns (including the case where the enemy acts
## first right out of _enter_combat()) until it's the player's turn again,
## then starts it for them (refills stamina, shows the movement range).
## Shared by _enter_combat() and _end_turn() so both go through the same
## logic instead of duplicating it.
func _resolve_enemy_turns() -> void:
	while _current_turn_id != PLAYER_ID and _enemy.state == MonsterScript.State.ALIVE:
		if _current_turn_id == _enemy.data.monster_id:
			if _enemy_attack():
				return  # player was defeated; combat already ended and scene changed
		_current_turn_id = _turn_queue.advance()
	if _current_turn_id == PLAYER_ID:
		GameManager.player.start_turn()
		_movement_indicator.visible = true

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
		var player = GameManager.player
		_label.text = (
			"COMBAT (test) — click to move (stamina-limited), E to attack, drag a throwable item onto the world to throw it, R to undo movement (until you act), F to end turn, Q to flee\n"
			+ "Player HP: %d/%d  Stamina: %d/%d   |   Skeleton HP: %d/%d   |   Turn: %s"
			% [player.current_hp, player.stats.vitality, roundi(player.current_stamina), player.stats.stamina, _enemy.current_hp, _enemy.stats.vitality, _current_turn_id]
		)
	else:
		_label.text = "DUNGEON — WASD to move, walk to the gold block and press E to extract back to town (Q: test combat mode)"
