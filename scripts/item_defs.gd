extends RefCounted
class_name ItemDefs

## Loot table. Each item has a name, a value in credits and a UI color.

const ITEMS: Array[Dictionary] = [
	{"id": "bandage", "name": "Bandage", "value": 45, "color": Color(0.90, 0.90, 0.95)},
	{"id": "ammo", "name": "Ammo Box", "value": 90, "color": Color(0.85, 0.75, 0.30)},
	{"id": "medkit", "name": "Medkit", "value": 220, "color": Color(0.90, 0.30, 0.30)},
	{"id": "part", "name": "Weapon Part", "value": 300, "color": Color(0.70, 0.70, 0.75)},
	{"id": "cpu", "name": "Graphics Card", "value": 420, "color": Color(0.40, 0.80, 0.50)},
	{"id": "gold", "name": "Gold Chain", "value": 650, "color": Color(1.00, 0.85, 0.30)},
	{"id": "watch", "name": "Luxury Watch", "value": 900, "color": Color(0.80, 0.85, 0.95)},
	{"id": "intel", "name": "Encrypted Drive", "value": 1100, "color": Color(0.50, 0.70, 1.00)},
]

static func random_item() -> Dictionary:
	return ITEMS[randi() % ITEMS.size()].duplicate()

static func by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item.duplicate()
	return {}
