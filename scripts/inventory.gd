extends RefCounted
class_name Inventory

## Simple carried-loot inventory. Loot is lost on death, banked on extraction.

var items: Array[Dictionary] = []
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
	return total

func is_full() -> bool:
	return items.size() >= capacity

## How many items with the given id are carried.
func count_by_id(id: String) -> int:
	var n := 0
	for item in items:
		if String(item.get("id", "")) == id:
			n += 1
	return n

## Remove and return the first item with the given id, or {} if none.
func remove_first_by_id(id: String) -> Dictionary:
	for i in items.size():
		if String(items[i].get("id", "")) == id:
			return items.pop_at(i)
	return {}

func clear() -> void:
	items.clear()
