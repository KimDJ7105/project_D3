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
## E (interact) *arms* equipped_skills[0] ("베기") on your turn — the skill
## doesn't fire until the next left-click picks a target point (or an
## adjacent dead enemy: loots; or the gold block: extracts). "2" ("skill_2")
## arms equipped_skills[1] ("강타") the same way. Right-click (or pressing
## the same skill key again) cancels aiming. This click-to-target step is
## what actually makes range/effect_radius testable — see
## Player.start_aiming_skill()/skill_aim_requested and
## CombatFormulas.skill_damage() (docs/06_skill_style_system.md). No skill
## slot/loadout UI exists yet, so these two are just hardcoded on Player.
## Dragging a throwable inventory item onto the world throws it there
## instead (see InventoryPanel.item_throw_requested).
## No real enemy AI exists — on its turn the enemy always uses its one
## attack_skill against the player, see docs/05_decisions_log.md.

const MonsterScript := preload("res://scripts/entities/Monster.gd")
const TurnQueueScript := preload("res://scripts/systems/TurnQueue.gd")
const CombatFormulasScript := preload("res://scripts/systems/CombatFormulas.gd")
const TargetingScript := preload("res://scripts/systems/Targeting.gd")

const INTERACT_RANGE := 1.5
const ENCOUNTER_RANGE := 2.5
const PLAYER_ID := "player"

## How close a click needs to land to the enemy to count as "you selected
## this as your target" for a single-target skill (effect_radius == 0).
## Not a gameplay radius (docs/03_combat_system.md "스킬 범위 구조": 0 means
## "the target itself") — just a generous target-select tolerance so this
## isn't pixel-precise mouse aiming in a turn-based (non-FPS) game. Missing
## with this doesn't cost anything: no valid target selected means the
## skill never fires at all (2026-09-17 — see 결정 로그, single-target no
## longer allowed to "whiff" against empty space the way AoE/throwing can).
const SINGLE_TARGET_SELECT_RADIUS := 1.0

@onready var _label: Label = $UI/Label
@onready var _movement_indicator: MeshInstance3D = $MovementRangeIndicator
@onready var _enemy: MonsterScript = $Enemy

var _turn_queue = null
var _current_turn_id: String = ""

func _ready() -> void:
	_enemy.died.connect(_on_enemy_died)
	var player = GameManager.player
	var inventory_panel = player.get_node("InventoryPanel")
	inventory_panel.item_throw_requested.connect(_on_item_thrown)
	player.skill_aim_requested.connect(_on_skill_aim_requested)
	# Every dungeon entry is a fresh run (docs/02_dungeon_town_structure.md
	# "층 스킵/지름길 없음") — snap to the entrance/extraction point rather
	# than wherever the player happened to be standing in town.
	player.position = Vector3($ExtractionPoint.global_position.x, 0.0, $ExtractionPoint.global_position.z)

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
	elif event.is_action_pressed("skill_2"):
		_arm_skill(1)
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
	if GameManager.in_combat and _current_turn_id == PLAYER_ID and _enemy.state == MonsterScript.State.ALIVE:
		_arm_skill(0)
		return
	var near_enemy: bool = player.global_position.distance_to(_enemy.global_position) <= INTERACT_RANGE
	if near_enemy and _enemy.state == MonsterScript.State.DEAD:
		_do_loot()
		return
	_try_extract()

## Arms equipped_skills[index] — it doesn't fire until the player
## left-clicks a target point (Player.skill_aim_requested ->
## _on_skill_aim_requested()). Pressing the same skill's key again while
## it's already armed cancels it instead (toggle).
func _arm_skill(index: int) -> void:
	if not (GameManager.in_combat and _current_turn_id == PLAYER_ID):
		return
	var player = GameManager.player
	if player.pending_skill_index == index:
		player.cancel_aim()
	else:
		player.start_aiming_skill(index)
	_update_label()

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

## The target point the player clicked after arming equipped_skills[index]
## (see _arm_skill()/Player.skill_aim_requested). Checks the skill's own
## range and stamina cost (docs/03_combat_system.md "스킬 범위 구조"),
## rejecting outright (nothing spent) if the aim point itself is beyond
## range. Beyond that, single-target and AoE skills differ on purpose:
## - **Single-target** (effect_radius == 0) needs an actual target — if
##   the click didn't land on a live enemy (within SINGLE_TARGET_SELECT_RADIUS),
##   nothing happens at all, no cost. This isn't a "miss": clicking empty
##   space just never selected anything to use the skill on.
## - **AoE** (effect_radius > 0) fires regardless of whether it actually
##   hits anything — ground-targeted skills (zones/traps/area denial) are
##   meant to be usable strategically at a location with no target
##   present, not just as a punishment for imprecise aim.
## Locks out undo_movement() for the rest of the turn once it actually
## fires — see Player.mark_acted().
func _on_skill_aim_requested(index: int, target_point: Vector3) -> void:
	if not (GameManager.in_combat and _current_turn_id == PLAYER_ID):
		return
	var player = GameManager.player
	var skill = player.equipped_skills[index]
	if player.current_stamina < skill.stamina_cost:
		return
	if TargetingScript.flat_distance(player.global_position, target_point) > skill.range:
		return
	var hit_radius: float = skill.effect_radius if skill.effect_radius > 0.0 else SINGLE_TARGET_SELECT_RADIUS
	var hits_enemy: bool = (
		_enemy.state == MonsterScript.State.ALIVE
		and TargetingScript.flat_distance(target_point, _enemy.global_position) <= hit_radius
	)
	if skill.effect_radius <= 0.0 and not hits_enemy:
		return  # single-target: no valid target under the click, nothing happens
	player.current_stamina -= skill.stamina_cost
	player.mark_acted()
	if hits_enemy:
		var damage: int = CombatFormulasScript.skill_damage(player.stats, skill)
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
	if player.current_stamina < CombatFormulasScript.THROW_STAMINA_COST:
		return
	if TargetingScript.flat_distance(player.global_position, target_point) > item.throw_range:
		return
	player.current_stamina -= CombatFormulasScript.THROW_STAMINA_COST
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
	var damage: int = CombatFormulasScript.skill_damage(_enemy.stats, _enemy.data.attack_skill)
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
		var aim_hint: String
		if player.is_aiming():
			var aimed_skill = player.equipped_skills[player.pending_skill_index]
			aim_hint = "AIMING %s (range %.1f) — click a target, right-click/press again to cancel" % [aimed_skill.display_name, aimed_skill.range]
		else:
			aim_hint = "click to move (stamina-limited), E: 베기, 2: 강타"
		_label.text = (
			"COMBAT (test) — %s, drag a throwable item onto the world to throw it, R to undo movement (until you act), F to end turn, Q to flee\n"
			% aim_hint
			+ "Player HP: %d/%d  Stamina: %d/%d   |   Skeleton HP: %d/%d   |   Turn: %s"
			% [player.current_hp, player.stats.vitality, roundi(player.current_stamina), player.stats.stamina, _enemy.current_hp, _enemy.stats.vitality, _current_turn_id]
		)
	else:
		_label.text = "DUNGEON — WASD to move, walk to the gold block and press E to extract back to town (Q: test combat mode)"
