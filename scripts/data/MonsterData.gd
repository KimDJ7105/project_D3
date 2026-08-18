extends Resource
class_name MonsterData
## Static/authored definition of a monster type. Instances live as .tres
## files under data/monsters/ (or embedded as sub_resources in a scene for
## quick placeholder testing, as Dungeon.tscn currently does).

const StatsScript := preload("res://scripts/data/Stats.gd")

@export var monster_id: String = ""
@export var display_name: String = ""
@export var sprite: Texture2D

## Base stats for this monster type. Monster.gd duplicates this on spawn so
## damaging one instance never mutates the shared authored resource.
@export var base_stats: StatsScript

## Each entry: {"item": ItemData, "chance": float (0-1), "min_qty": int, "max_qty": int}.
## Drop chances/quantities are unbalanced placeholders — see docs/05_decisions_log.md.
@export var loot_table: Array = []
