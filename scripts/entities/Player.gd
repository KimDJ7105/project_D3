extends CharacterBody3D
class_name Player
## Free 8-directional movement on the XZ plane (Y is height/elevation, used
## later for the confirmed cover/elevation combat mechanic — see
## docs/03_combat_system.md) while exploring. Combat also uses free
## movement (no grid), but click-to-move is turn-gated and limited by
## remaining stamina — see docs/03_combat_system.md "전투 중 이동과
## 스테미나" (2026-08-18, replaced the old grid-based click-to-move).
##
## Left-click normally moves. Pressing a skill key arms it
## (start_aiming_skill()) so the next left-click targets it instead —
## see pending_skill_index/skill_aim_requested. Right-click cancels aim.
##
## CharacterBody3D (not a plain Node3D) since exploration needs to collide
## with real dungeon walls (2026-09-17, first real dungeon layout) —
## free-roam movement uses move_and_slide(). Gravity was added 2026-09-19
## (motion_mode GROUNDED) so the player can walk up ramps/onto platforms
## for the elevation system. Combat click-movement (_move_toward())
## deliberately still bypasses physics and sets position directly —
## pathfinding/collision for that is intentionally deferred until it's
## actually needed (docs/03_combat_system.md); it just snaps to the ground
## height at the destination.

## Referenced via preload rather than the bare class_name — see the note on
## PlayerScript in scripts/core/GameManager.gd for why.
const TargetingScript := preload("res://scripts/systems/Targeting.gd")
const StatsScript := preload("res://scripts/data/Stats.gd")
const InventoryScript := preload("res://scripts/systems/Inventory.gd")
const CombatFormulasScript := preload("res://scripts/systems/CombatFormulas.gd")
const SkillDataScript := preload("res://scripts/data/SkillData.gd")

enum MovementMode { FREE, COMBAT }

const SPEED := 4.0  # free-roam movement units/sec — unrelated to the 속도 combat stat below
const GRAVITY := 20.0  # placeholder feel value — units/sec^2, pulls the player onto platforms/ramps/floor

signal died

## Fired when the player has an equipped skill "armed" (see
## start_aiming_skill()) and then left-clicks a world point to confirm the
## target — the combat scene (Dungeon.gd) resolves what that hits, same
## split as InventoryPanel.item_throw_requested.
## `picked` is the enemy the click landed on (physics pick, ignores walls —
## see Targeting.pick_enemy()), or null if the click wasn't on one.
signal skill_aim_requested(index: int, target: Vector3, picked: Node3D)

var movement_mode: MovementMode = MovementMode.FREE
var stats: StatsScript = StatsScript.new()
var inventory: InventoryScript = InventoryScript.new()
var current_hp: int
var current_stamina: float

## Fixed for now — no skill slot/loadout UI exists yet
## (docs/06_skill_style_system.md 열린 질문). Combat input maps index 0 to
## "interact" (E) and index 1 to "skill_2" — see Dungeon.gd._try_use_skill().
var equipped_skills: Array[SkillDataScript] = [
	preload("res://data/skills/slash.tres"),
	preload("res://data/skills/heavy_strike.tres"),
]

## Whether it's currently this player's turn in combat — set by the combat
## scene script (e.g. Dungeon.gd), not decided here. Click-to-move only
## works while this is true; see start_turn()/end_turn().
var is_my_turn: bool = false

## Movement can be freely undone (position + stamina both reset to how they
## were at the start of this turn) up until the player attacks or throws —
## once that happens undo locks for the rest of the turn, so "move, attack,
## then reposition risk-free" isn't a thing. See mark_acted()/undo_movement()
## and docs/03_combat_system.md.
var _turn_start_position: Vector3 = Vector3.ZERO
var _has_acted_this_turn: bool = false

## >= 0 while a skill is "armed" and waiting for the player to click a
## world point/target to confirm it — see start_aiming_skill(). While
## armed, left-click stops meaning "move here" and means "use this skill
## here/on this" instead (docs/03_combat_system.md "스킬 범위 구조" — this
## is what actually lets a click express a target/aim point, instead of
## a skill just auto-resolving against whatever's nearby).
var pending_skill_index: int = -1

@onready var _camera: Camera3D = $Camera3D
@onready var _inventory_panel: CanvasLayer = $InventoryPanel
@onready var _hud: CanvasLayer = $PlayerHUD

func _ready() -> void:
	current_hp = stats.vitality
	current_stamina = stats.stamina
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

## Called by the combat scene whenever it becomes this player's turn
## (combat entry and every time the turn cycles back to them) — refills
## stamina to the max every turn, no carryover (docs/03_combat_system.md).
func start_turn() -> void:
	is_my_turn = true
	current_stamina = stats.stamina
	_turn_start_position = position
	_has_acted_this_turn = false

func end_turn() -> void:
	is_my_turn = false

## Called by the combat scene once an attack/throw actually lands (not on a
## rejected attempt, e.g. insufficient stamina or out of range) — permanently
## locks out undo_movement() for the rest of this turn.
func mark_acted() -> void:
	_has_acted_this_turn = true

func can_undo_movement() -> bool:
	return is_my_turn and not _has_acted_this_turn

## Arms equipped_skills[index] — the next left-click (or right-click to
## cancel) resolves it instead of moving. Called by the combat scene when
## a skill key is pressed (e.g. E, "2").
func start_aiming_skill(index: int) -> void:
	pending_skill_index = index

func cancel_aim() -> void:
	pending_skill_index = -1

func is_aiming() -> bool:
	return pending_skill_index >= 0

## Resets position and stamina back to how they were at the start of this
## turn, as if no movement happened yet. No-op if an attack/throw has
## already happened this turn (see can_undo_movement()).
func undo_movement() -> void:
	if not can_undo_movement():
		return
	position = _turn_start_position
	current_stamina = stats.stamina

func _physics_process(delta: float) -> void:
	if movement_mode == MovementMode.FREE:
		_process_free_movement(delta)
	else:
		# COMBAT horizontal movement is event-driven (mouse click, see
		# _unhandled_input) — this just keeps gravity settling the player
		# onto the ground between/after those position jumps.
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()

func _process_free_movement(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
	velocity.x = input_dir.x * SPEED
	velocity.z = input_dir.y * SPEED
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

func _unhandled_input(event: InputEvent) -> void:
	if movement_mode != MovementMode.COMBAT or not is_my_turn:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if is_aiming() and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_aim()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var target = TargetingScript.raycast_to_ground(_camera, event.position, position.y)
	if is_aiming():
		var picked: Node3D = TargetingScript.pick_enemy(_camera, event.position)
		if target == null:
			if picked == null:
				return
			target = picked.global_position
		var index := pending_skill_index
		pending_skill_index = -1
		skill_aim_requested.emit(index, target, picked)
	elif target != null:
		_move_toward(target)

## Moves as far toward `target` as remaining stamina allows (clamped, not
## rejected outright, so a far click still moves you your full range —
## matches how the movement-range indicator previews it).
func _move_toward(target: Vector3) -> void:
	var to_target: Vector3 = target - position
	to_target.y = 0.0
	var distance: float = to_target.length()
	if distance <= 0.001:
		return
	var affordable: float = CombatFormulasScript.max_move_distance(current_stamina)
	var actual_distance: float = min(distance, affordable)
	if actual_distance <= 0.001:
		return
	position += to_target.normalized() * actual_distance
	# Combat movement sets position directly (no physics, no pathfinding),
	# so match the ground height at the destination ourselves — otherwise
	# a move off a platform would leave the player hovering/embedded until
	# gravity catches up. Extra stamina for climbing isn't implemented yet.
	var ground = TargetingScript.ground_height(get_world_3d(), position.x, position.z, position.y + 5.0)
	if ground != null:
		position.y = ground
	current_stamina -= CombatFormulasScript.movement_stamina_cost(actual_distance)

func enter_combat_mode() -> void:
	movement_mode = MovementMode.COMBAT

func enter_free_mode() -> void:
	movement_mode = MovementMode.FREE
	is_my_turn = false
	pending_skill_index = -1
