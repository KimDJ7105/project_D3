extends CanvasLayer
## Minimal placeholder inventory display — plain text list, no icons/art.
## Bound to a Player's Inventory via bind(), refreshes on contents_changed.
## Deliberately dumb/swappable: the moment real UI resources exist, this
## whole scene gets replaced without touching Inventory itself at all.

@onready var _panel: Panel = $Panel
@onready var _list_label: Label = $Panel/ItemList

var _inventory: Resource

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
	var lines: Array = []
	for slot in _inventory.get_contents():
		lines.append("%s x%d" % [slot.item.display_name, slot.quantity])
	_list_label.text = "\n".join(lines) if not lines.is_empty() else "(empty)"
