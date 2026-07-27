extends Resource

class_name Inv

@export var slots: Array[InvSlot] = []
const DEFAULT_SLOT_COUNT: int = 12

signal update

func _init() -> void:
	ensure_slot_count(DEFAULT_SLOT_COUNT)

func ensure_slot_count(required_count: int = DEFAULT_SLOT_COUNT) -> void:
	var target_count: int = maxi(required_count, 0)
	_normalize_slots()
	while slots.size() < target_count:
		slots.append(InvSlot.new())

func _normalize_slots() -> void:
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = InvSlot.new()

func insert(item: InvItem):
	ensure_slot_count(DEFAULT_SLOT_COUNT)
	
	for slot: InvSlot in slots:
		if slot and slot.item == item:
			slot.amount += 1
			update.emit()
			return
	
	for slot: InvSlot in slots:
		if slot and slot.item == null:
			slot.item = item
			slot.amount = 1
			update.emit()
			return
	
	# If all slots are full, add one more so pickup never silently fails.
	var new_slot: InvSlot = InvSlot.new()
	new_slot.item = item
	new_slot.amount = 1
	slots.append(new_slot)
	update.emit()
	
func get_count(item_name: String) -> int:
	_normalize_slots()
	var total: int = 0
	for slot: InvSlot in slots:
		if slot.item and slot.item.name == item_name:
			total += slot.amount
	return total
	
func remove(item_name: String, amount: int):
	_normalize_slots()
	for slot: InvSlot in slots:
		if slot.item and slot.item.name == item_name:
			var to_remove: int = mini(slot.amount, amount)
			slot.amount -= to_remove
			amount -= to_remove
			if slot.amount <= 0:
				slot.item = null
			if amount <= 0:
				break
	update.emit()

func has_item(item_name: String) -> bool:
	return get_count(item_name) > 0
	
	
func get_all_potion_items() -> Array[InvItem]:
	var potions: Array[InvItem] = []

	for slot in slots:
		if slot.item and ("elixir" in slot.item.name or "potion" in slot.item.name):
			potions.append(slot.item)

	return potions
