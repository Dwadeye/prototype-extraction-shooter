extends RefCounted
class_name Inventory

## Carried inventory: a bag of loose items plus worn equipment slots.
## Loot is lost on death, banked on extraction.

const EQUIP_SLOTS: Array[String] = ["helmet", "armor", "rig", "backpack"]

var items: Array[Dictionary] = []
var equipment: Dictionary = {}
var base_capacity: int = 18
var capacity: int = 18

func add(item: Dictionary) -> bool:
	if items.size() >= capacity:
		return false
	items.append(item)
	return true

func total_value() -> int:
	var total := 0
	for item in items:
		total += int(item.get("value", 0))
	for slot in equipment:
		total += int(equipment[slot].get("value", 0))
	return total

func is_full() -> bool:
	return items.size() >= capacity

## How many items with the given id are carried (bag only).
func count_by_id(id: String) -> int:
	var n := 0
	for item in items:
		if String(item.get("id", "")) == id:
			n += 1
	return n

## Remove and return the first bag item with the given id, or {} if none.
func remove_first_by_id(id: String) -> Dictionary:
	for i in items.size():
		if String(items[i].get("id", "")) == id:
			return items.pop_at(i)
	return {}

# --- Equipment ---------------------------------------------------------------

func recompute_capacity() -> void:
	capacity = base_capacity
	for slot in equipment:
		capacity += int(equipment[slot].get("capacity", 0))

func equip(bag_index: int, slot: String) -> bool:
	if bag_index < 0 or bag_index >= items.size():
		return false
	if not EQUIP_SLOTS.has(slot):
		return false
	var item: Dictionary = items[bag_index]
	if String(item.get("type", "")) != slot:
		return false
	var previous: Dictionary = equipment.get(slot, {})
	equipment[slot] = item
	items.remove_at(bag_index)
	if not previous.is_empty():
		items.insert(bag_index, previous)
	recompute_capacity()
	return true

func unequip(slot: String, bag_index: int = -1) -> bool:
	if not equipment.has(slot):
		return false
	if items.size() >= capacity:
		return false
	var item: Dictionary = equipment[slot]
	equipment.erase(slot)
	if bag_index >= 0 and bag_index <= items.size():
		items.insert(bag_index, item)
	else:
		items.append(item)
	recompute_capacity()
	return true

## Swap two bag positions (drag within the bag).
func move_item(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= items.size() or to >= items.size():
		return
	var tmp: Dictionary = items[from]
	items[from] = items[to]
	items[to] = tmp

func drop(bag_index: int) -> Dictionary:
	if bag_index < 0 or bag_index >= items.size():
		return {}
	return items.pop_at(bag_index)

func sort_by_value() -> void:
	items.sort_custom(func(a, b): return int(a.get("value", 0)) > int(b.get("value", 0)))

func clear() -> void:
	items.clear()
	equipment.clear()
	recompute_capacity()
