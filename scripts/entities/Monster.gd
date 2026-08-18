extends Node3D
class_name Monster
## Runtime monster instance. Lifecycle: ALIVE (has HP, can be attacked) ->
## DEAD (HP hit 0 — becomes a lootable corpse, loot table already rolled)
## -> looted (loot handed to whoever interacted, corpse removed).
##
## No enemy AI exists yet — this only tracks state/HP/loot, it doesn't act
## on its own turn in combat (see Dungeon.gd, which just passes the turn
## straight back to the player).

const StatsScript := preload("res://scripts/data/Stats.gd")
const MonsterDataScript := preload("res://scripts/data/MonsterData.gd")

enum State { ALIVE, DEAD }

signal died(monster: Monster)
signal looted(monster: Monster)

@export var data: MonsterDataScript

var stats: StatsScript
var current_hp: int
var state: State = State.ALIVE
var dropped_loot: Array = []  # populated on death: [{"item": ItemData, "quantity": int}, ...]

@onready var _sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	stats = data.base_stats.duplicate() if data and data.base_stats else StatsScript.new()
	current_hp = stats.vitality
	if data and data.sprite and _sprite:
		_sprite.texture = data.sprite


func take_damage(amount: int) -> void:
	if state != State.ALIVE:
		return
	current_hp = max(0, current_hp - amount)
	if current_hp <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	dropped_loot = _roll_loot()
	died.emit(self)


func _roll_loot() -> Array:
	var result: Array = []
	if data == null:
		return result
	for entry in data.loot_table:
		if randf() <= entry.get("chance", 1.0):
			var qty: int = randi_range(entry.get("min_qty", 1), entry.get("max_qty", 1))
			result.append({"item": entry.item, "quantity": qty})
	return result


## Called when the player interacts with this corpse. Returns the rolled
## loot for the caller to add to their own inventory.
func loot() -> Array:
	if state != State.DEAD:
		return []
	var taken := dropped_loot
	dropped_loot = []
	looted.emit(self)
	return taken
