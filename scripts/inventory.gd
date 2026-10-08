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

func clear() -> void:
	items.clear()
