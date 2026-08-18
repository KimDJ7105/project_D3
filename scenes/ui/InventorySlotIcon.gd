extends Control
## A single draggable item icon in the freeform inventory. No art assets
## exist yet — falls back to a plain colored rectangle when item.icon is
## unset, so this automatically starts using real icons the moment
## ItemData.icon gets populated, no code changes needed.

signal drag_ended(icon, global_drop_pos)

const ICON_SIZE := Vector2(36, 36)
const PLACEHOLDER_COLOR := Color(0.85, 0.8, 0.7)  # bone-ish tan, generic placeholder

@onready var _qty_label: Label = $QtyLabel

var slot_id: int = -1
var _dragging := false

func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE

func set_item(item: Resource, quantity: int) -> void:
	var visual: Control
	if item.icon:
		var tex_rect := TextureRect.new()
		tex_rect.texture = item.icon
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		visual = tex_rect
	else:
		var rect := ColorRect.new()
		rect.color = PLACEHOLDER_COLOR
		visual = rect
	visual.size = ICON_SIZE
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks go to this Control, not the visual
	add_child(visual)
	move_child(visual, 0)  # keep QtyLabel drawn on top
	set_quantity(quantity)
	tooltip_text = item.display_name

func set_quantity(quantity: int) -> void:
	_qty_label.text = ("x%d" % quantity) if quantity > 1 else ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			accept_event()
		elif _dragging:
			_dragging = false
			drag_ended.emit(self, get_global_mouse_position())
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		global_position += event.relative
