extends CanvasLayer
## Facility roster UI + a minimal dialogue stub — a real dialogue system
## (branching choices, quest hooks) doesn't exist yet
## (docs/02_dungeon_town_structure.md 열린 질문). Shows every present NPC as
## a clickable list so the player doesn't have to hunt for them in a scene
## with no positioned NPC art yet; picking one shows their one canned
## greeting line. Purely presentational — like InventoryPanel, it signals
## intent (npc_selected) and lets the scene script (Town.gd) own side
## effects like RelationshipManager registration.

const NPCDataScript := preload("res://scripts/data/NPCData.gd")

signal closed
signal npc_selected(npc: NPCDataScript)

@onready var _roster_title: Label = $Panel/RosterTitle
@onready var _roster_list: VBoxContainer = $Panel/RosterList
@onready var _name_label: Label = $Panel/NameLabel
@onready var _body_label: Label = $Panel/BodyLabel
@onready var _back_button: Button = $Panel/BackButton
@onready var _hint_label: Label = $Panel/HintLabel

var _cached_roster: Array[NPCDataScript] = []
var _cached_facility_name: String = ""

func _ready() -> void:
	visible = false
	_back_button.pressed.connect(_show_roster_view)

## present.size() == 0 shows an "empty" message; == 1 skips straight to
## that NPC's greeting (no point listing a single name to click); >1 shows
## the clickable list.
func show_roster(present: Array[NPCDataScript], facility_display_name: String) -> void:
	_cached_roster = present
	_cached_facility_name = facility_display_name
	if present.is_empty():
		_show_empty_view()
		return
	if present.size() == 1:
		npc_selected.emit(present[0])
		return
	_show_roster_view()

func show_greeting(npc: NPCDataScript) -> void:
	_roster_title.visible = false
	_roster_list.visible = false
	_name_label.visible = true
	_body_label.visible = true
	_back_button.visible = _cached_roster.size() > 1
	_name_label.text = npc.display_name
	_body_label.text = npc.greeting if npc.greeting != "" else "..."
	_hint_label.text = "(E: 닫기)"
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

func _show_roster_view() -> void:
	for child in _roster_list.get_children():
		child.queue_free()
	_roster_title.text = "%s — %d명이 있다" % [_cached_facility_name, _cached_roster.size()]
	_roster_title.visible = true
	_roster_list.visible = true
	_name_label.visible = false
	_body_label.visible = false
	_back_button.visible = false
	_hint_label.text = "(E: 닫기)"
	for npc in _cached_roster:
		var button := Button.new()
		button.text = npc.display_name
		button.pressed.connect(func() -> void: npc_selected.emit(npc))
		_roster_list.add_child(button)
	visible = true

func _show_empty_view() -> void:
	_roster_title.visible = false
	_roster_list.visible = false
	_back_button.visible = false
	_name_label.visible = true
	_body_label.visible = true
	_name_label.text = _cached_facility_name
	_body_label.text = "지금은 아무도 없다."
	_hint_label.text = "(E: 닫기)"
	visible = true
