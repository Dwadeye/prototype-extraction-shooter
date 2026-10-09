extends RefCounted
class_name ItemDefs

## Loot + gear table. Each item has a name, value, UI colour and a `type`.
## `type` drives which equipment slot it can be equipped to:
##   loot / med / ammo -> bag only;  helmet / armor / rig / backpack -> equippable.

const ITEMS: Array[Dictionary] = [
	{"id": "bandage", "name": "Bandage", "value": 45, "color": Color(0.90, 0.90, 0.95), "type": "med"},
	{"id": "ammo", "name": "Ammo Box", "value": 90, "color": Color(0.85, 0.75, 0.30), "type": "ammo"},
	{"id": "medkit", "name": "Medkit", "value": 220, "color": Color(0.90, 0.30, 0.30), "type": "med"},
	{"id": "part", "name": "Weapon Part", "value": 300, "color": Color(0.70, 0.70, 0.75), "type": "loot"},
	{"id": "cpu", "name": "Graphics Card", "value": 420, "color": Color(0.40, 0.80, 0.50), "type": "loot"},
	{"id": "gold", "name": "Gold Chain", "value": 650, "color": Color(1.00, 0.85, 0.30), "type": "loot"},
	{"id": "watch", "name": "Luxury Watch", "value": 900, "color": Color(0.80, 0.85, 0.95), "type": "loot"},
	{"id": "intel", "name": "Encrypted Drive", "value": 1100, "color": Color(0.50, 0.70, 1.00), "type": "loot"},
	{"id": "helmet_1", "name": "Light Helmet", "value": 380, "color": Color(0.55, 0.60, 0.68), "type": "helmet", "armor": 0.10},
	{"id": "helmet_2", "name": "Combat Helmet", "value": 720, "color": Color(0.45, 0.52, 0.60), "type": "helmet", "armor": 0.16},
	{"id": "armor_1", "name": "Kevlar Vest", "value": 520, "color": Color(0.40, 0.55, 0.45), "type": "armor", "armor": 0.20, "armor_points": 60.0},
	{"id": "armor_2", "name": "Plate Carrier", "value": 980, "color": Color(0.35, 0.45, 0.55), "type": "armor", "armor": 0.30, "armor_points": 110.0},
	{"id": "rig_1", "name": "Tactical Rig", "value": 420, "color": Color(0.55, 0.45, 0.35), "type": "rig", "capacity": 4},
	{"id": "backpack_1", "name": "Assault Backpack", "value": 640, "color": Color(0.45, 0.40, 0.35), "type": "backpack", "capacity": 8},
]

static func random_item() -> Dictionary:
	return ITEMS[randi() % ITEMS.size()].duplicate()

static func by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item.duplicate()
	return {}
