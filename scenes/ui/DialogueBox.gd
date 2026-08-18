extends CanvasLayer
## Minimal dialogue stub — a real dialogue system (branching choices, quest
## hooks) doesn't exist yet (docs/02_dungeon_town_structure.md 열린 질문).
## This just proves the facility-roster interaction loop end to end: show
## who's here and their one canned greeting line, close on interact/cancel.

signal closed

@onready var _name_label: Label = $Panel/NameLabel
@onready var _body_label: Label = $Panel/BodyLabel

func _ready() -> void:
	visible = false

func show_npc(npc: Resource) -> void:
	_name_label.text = npc.display_name
	_body_label.text = npc.greeting if npc.greeting != "" else "..."
	visible = true

func show_empty(facility_display_name: String) -> void:
	_name_label.text = facility_display_name
	_body_label.text = "지금은 아무도 없다."
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible
