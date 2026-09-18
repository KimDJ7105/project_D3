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
## for the elevation system. Combat click-movement (start_walk()) walks a
## navmesh path with the same physics body (2026-09-19; it used to
## teleport, straight through walls) — see docs/03_combat_system.md.

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
const COMBAT_MOVE_SPEED := 5.0  # walking speed during a combat move — placeholder feel value
## How far a path's end may fall short of the (snapped) goal before it counts
## as "not connected" — the navmesh returns a partial path in that case.
const PATH_CONNECT_TOLERANCE := 0.25
const STUCK_TIMEOUT := 0.5  # seconds of barely moving before a walk gives up

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

## True while walking a combat move (see start_walk()). The combat scene
## blocks other actions (skills, ending the turn, undo, throwing) while this
## is set; a click stops the walk instead.
var is_moving: bool = false
var _walk_path: PackedVector3Array = PackedVector3Array()
var _walk_index: int = 0
var _stuck_time: float = 0.0

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
	if is_moving:
		return
	pending_skill_index = index

func cancel_aim() -> void:
	pending_skill_index = -1

func is_aiming() -> bool:
	return pending_skill_index >= 0

## Resets position and stamina back to how they were at the start of this
## turn, as if no movement happened yet. No-op if an attack/throw has
## already happened this turn (see can_undo_movement()).
func undo_movement() -> void:
	if not can_undo_movement() or is_moving:
		return
	position = _turn_start_position
	current_stamina = stats.stamina

func _physics_process(delta: float) -> void:
	if movement_mode == MovementMode.FREE:
		_process_free_movement(delta)
	else:
		_process_combat_movement(delta)

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
	if is_moving:
		# Any click while walking just stops — it doesn't start a new move or
		# fire a skill, so a stray click can't do something unintended.
		stop_walking()
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
		start_walk(target)

## Starts walking toward `target` along a navmesh path (docs/03_combat_system.md
## "전투 중 이동과 스테미나"):
## - the target is snapped to the nearest walkable point, so clicking a
##   wall (or anything unwalkable) walks you up to it;
## - if that point isn't connected to where you're standing, nothing
##   happens at all;
## - the path is cut where stamina runs out, so a click beyond your budget
##   walks as far as you can afford.
## Stamina is spent as you actually walk (see _process_combat_movement), so
## stopping early only costs what you walked.
func start_walk(target: Vector3) -> void:
	if is_moving:
		return
	var nav_map: RID = get_world_3d().navigation_map
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, target)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, position, goal, true)
	if path.size() < 2:
		return
	if TargetingScript.flat_distance(path[path.size() - 1], goal) > PATH_CONNECT_TOLERANCE:
		return  # not connected — the path only got partway toward the goal
	var budget: float = CombatFormulasScript.max_move_distance(current_stamina)
	_walk_path = _truncate_path(path, budget)
	if _walk_path.size() < 2:
		return
	_walk_index = 1
	_stuck_time = 0.0
	is_moving = true

## Cancels an in-progress walk right where the player is.
func stop_walking() -> void:
	is_moving = false
	_walk_path = PackedVector3Array()
	_walk_index = 0

## The part of `path` within `budget` horizontal distance from its start
## (cutting the last segment partway if needed). Horizontal only — extra
## stamina for climbing isn't implemented yet.
func _truncate_path(path: PackedVector3Array, budget: float) -> PackedVector3Array:
	var result := PackedVector3Array([path[0]])
	var remaining: float = budget
	for i in range(1, path.size()):
		var segment: float = TargetingScript.flat_distance(path[i - 1], path[i])
		if segment <= remaining:
			result.append(path[i])
			remaining -= segment
		else:
			if remaining > 0.001:
				result.append(path[i - 1].lerp(path[i], remaining / segment))
			break
	return result

## COMBAT-mode physics step: walks along _walk_path if a walk is active,
## otherwise just lets gravity keep the player on the ground.
func _process_combat_movement(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_moving:
		_apply_gravity(delta)
		move_and_slide()
		return

	var waypoint: Vector3 = _walk_path[_walk_index]
	var to_waypoint := Vector2(waypoint.x - position.x, waypoint.z - position.z)
	var distance: float = to_waypoint.length()
	var speed: float = minf(COMBAT_MOVE_SPEED, distance / delta)  # don't overshoot the waypoint
	if distance > 0.001:
		var direction: Vector2 = to_waypoint / distance
		velocity.x = direction.x * speed
		velocity.z = direction.y * speed
	_apply_gravity(delta)
	var before := position
	move_and_slide()
	var walked: float = TargetingScript.flat_distance(before, position)
	current_stamina = maxf(0.0, current_stamina - CombatFormulasScript.movement_stamina_cost(walked))

	# Stuck against something the path didn't account for: give up rather
	# than push against it forever.
	if walked < COMBAT_MOVE_SPEED * delta * 0.2:
		_stuck_time += delta
		if _stuck_time > STUCK_TIMEOUT:
			stop_walking()
			return
	else:
		_stuck_time = 0.0

	if TargetingScript.flat_distance(position, waypoint) < 0.05:
		_walk_index += 1
		if _walk_index >= _walk_path.size():
			stop_walking()
	if current_stamina <= 0.001:
		stop_walking()

func enter_combat_mode() -> void:
	movement_mode = MovementMode.COMBAT

func enter_free_mode() -> void:
	movement_mode = MovementMode.FREE
	is_my_turn = false
	pending_skill_index = -1
	stop_walking()
