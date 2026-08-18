extends Resource
class_name Inventory
## Pure data/logic inventory container — no UI dependencies whatsoever.
## Emits `contents_changed` whenever slots change; any future UI connects to
## that signal to refresh itself, rather than Inventory knowing anything
## about how (or whether) it's displayed. Owned per-character (e.g.
## Player.inventory), not a global singleton.
##
## Item loss on death ([[07_progression_death_system]] "소지 아이템 전부
## 상실") is just `clear()`. Recovering items at the death point later is
## future work (needs a save/persistence system that doesn't exist yet —
## see [[godot-gdscript-gotchas]]-adjacent gap noted for RelationshipManager).

signal contents_changed

## TODO: placeholder value — capacity is meant to become weight-based, not
## slot-count-based (see docs/10_inventory_system.md), not switched over yet.
@export var capacity: int = 20

## Each entry: {"slot_id": int, "item": ItemData, "quantity": int}. slot_id
## is a stable identity for this particular stack (array index isn't —
## it shifts as slots are added/removed) — a freeform-placement UI keys its
## per-item screen position off this rather than array position.
var slots: Array = []
var _next_slot_id: int = 0


func add_item(item: Resource, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false
	var remaining := quantity
	if item.stackable:
		for slot in slots:
			if slot.item == item and slot.quantity < item.max_stack:
				var space: int = item.max_stack - slot.quantity
				var take: int = min(space, remaining)
				slot.quantity += take
				remaining -= take
				if remaining <= 0:
					contents_changed.emit()
					return true
	while remaining > 0:
		if slots.size() >= capacity:
			# Partial add: whatever fit is already applied, rest is dropped.
			# No overflow/"can't carry more" UX exists yet — future work.
			contents_changed.emit()
			return false
		var take: int = remaining if not item.stackable else min(remaining, item.max_stack)
		slots.append({"slot_id": _next_slot_id, "item": item, "quantity": take})
		_next_slot_id += 1
		remaining -= take
	contents_changed.emit()
	return true


func remove_item(item: Resource, quantity: int = 1) -> bool:
	if item == null or quantity <= 0 or get_quantity(item) < quantity:
		return false
	var remaining := quantity
	for i in range(slots.size() - 1, -1, -1):
		var slot = slots[i]
		if slot.item != item:
			continue
		var take: int = min(slot.quantity, remaining)
		slot.quantity -= take
		remaining -= take
		if slot.quantity <= 0:
			slots.remove_at(i)
		if remaining <= 0:
			break
	contents_changed.emit()
	return true


func has_item(item: Resource, quantity: int = 1) -> bool:
	return get_quantity(item) >= quantity


func get_quantity(item: Resource) -> int:
	var total := 0
	for slot in slots:
		if slot.item == item:
			total += slot.quantity
	return total


## For the "사망 시 소지 아이템 전부 상실" mechanic.
func clear() -> void:
	slots.clear()
	contents_changed.emit()


## Read-only snapshot for a future UI to render — returns a duplicate so
## callers can't mutate internal state directly.
func get_contents() -> Array:
	return slots.duplicate(true)
