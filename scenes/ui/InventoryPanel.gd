extends CanvasLayer
## Freeform-placement inventory display (Ultima Online style — no grid, no
## overlap prevention). Bound to a Player's Inventory via bind(), rebuilds
## its icons on contents_changed. See docs/10_inventory_system.md.
##
## Drag-drop is fully custom (not Godot's built-in Control drag API)
## because a later step needs the same drag to also end over the 3D combat
## grid (throwing an item at a tile), not just other Controls — see
## _on_icon_drag_ended's TODO.

const SlotIconScene := preload("res://scenes/ui/InventorySlotIcon.tscn")

@onready var _panel: Panel = $Panel
@onready var _bag: Control = $Panel/Bag

var _inventory: Resource
var _positions: Dictionary = {}  # slot_id: int -> Vector2 (local to _bag)
var _icons: Dictionary = {}      # slot_id: int -> InventorySlotIcon

func _ready() -> void:
	_panel.visible = false

func bind(inventory: Resource) -> void:
	if _inventory and _inventory.contents_changed.is_connected(_refresh):
		_inventory.contents_changed.disconnect(_refresh)
	_inventory = inventory
	_inventory.contents_changed.connect(_refresh)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_panel.visible = not _panel.visible

func _refresh() -> void:
	if _inventory == null:
		return
	var current_ids := {}
	for slot in _inventory.get_contents():
		var id: int = slot.slot_id
		current_ids[id] = true
		if _icons.has(id):
			_icons[id].set_quantity(slot.quantity)
		else:
			_spawn_icon(id, slot)
	for id in _icons.keys().duplicate():
		if not current_ids.has(id):
			_icons[id].queue_free()
			_icons.erase(id)
			_positions.erase(id)

func _spawn_icon(id: int, slot: Dictionary) -> void:
	var icon = SlotIconScene.instantiate()
	icon.slot_id = id
	_bag.add_child(icon)
	icon.set_item(slot.item, slot.quantity)
	if not _positions.has(id):
		_positions[id] = _default_position(_icons.size())
	icon.position = _positions[id]
	icon.drag_ended.connect(_on_icon_drag_ended)
	_icons[id] = icon

func _default_position(index: int) -> Vector2:
	var per_row := 6
	var spacing := 44.0
	return Vector2(8 + (index % per_row) * spacing, 8 + (index / per_row) * spacing)

func _on_icon_drag_ended(icon, _global_drop_pos: Vector2) -> void:
	# TODO: this is where a future "drop icon on a combat grid tile ->
	# throw the item there" branch hooks in (check whether _global_drop_pos
	# lands outside _bag's rect and route to a throw instead of a
	# reposition). For now: no overlap prevention (docs/10_inventory_system.md
	# "형태" — free placement, deliberately no collision check), just clamp
	# inside the bag so items can't be dragged off-panel and lost.
	var clamped: Vector2 = icon.position.clamp(Vector2.ZERO, _bag.size - icon.size)
	icon.position = clamped
	_positions[icon.slot_id] = clamped
