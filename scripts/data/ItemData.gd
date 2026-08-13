extends Resource
class_name ItemData
## Static/authored definition of an item type. Instances live as .tres files
## under data/items/. item_id is the key other systems (quests, shops) will
## reference this item by.

@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D  # for a future inventory UI — unused until one exists

@export var stackable: bool = true
@export var max_stack: int = 99

## For equipment-type items: stat_name -> bonus. Empty for non-equipment.
## Feeds into the `equipment_modifier` argument of
## CombatFormulas.effective_speed and similar future stat calculations —
## exact equipment-slot rules aren't decided yet (see docs/05_decisions_log.md
## "장비 커스터마이징"), so this stays a loose Dictionary rather than a
## rigid slot/type system for now.
@export var stat_modifiers: Dictionary = {}
