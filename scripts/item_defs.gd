extends RefCounted
class_name ItemDefs

## Loot + gear table. Each item has a name, value, UI colour and a `type`.
## `type` drives which equipment slot it can be equipped to:
##   loot / med / ammo -> bag only;  helmet / armor / rig / backpack -> equippable.

const ITEMS: Array[Dictionary] = [
	{"id": "bandage", "name": "Bandage", "value": 45, "color": Color(0.90, 0.90, 0.95), "type": "med", "rarity": 0},
	{"id": "ammo", "name": "Ammo Box", "value": 90, "color": Color(0.85, 0.75, 0.30), "type": "ammo", "rarity": 0},
	{"id": "medkit", "name": "Medkit", "value": 220, "color": Color(0.90, 0.30, 0.30), "type": "med", "rarity": 1},
	{"id": "part", "name": "Weapon Part", "value": 300, "color": Color(0.70, 0.70, 0.75), "type": "loot", "rarity": 1},
	{"id": "cpu", "name": "Graphics Card", "value": 420, "color": Color(0.40, 0.80, 0.50), "type": "loot", "rarity": 2},
	{"id": "gold", "name": "Gold Chain", "value": 650, "color": Color(1.00, 0.85, 0.30), "type": "loot", "rarity": 2},
	{"id": "watch", "name": "Luxury Watch", "value": 900, "color": Color(0.80, 0.85, 0.95), "type": "loot", "rarity": 3},
	{"id": "intel", "name": "Encrypted Drive", "value": 1100, "color": Color(0.50, 0.70, 1.00), "type": "loot", "rarity": 3},
	{"id": "helmet_1", "name": "Light Helmet", "value": 380, "color": Color(0.55, 0.60, 0.68), "type": "helmet", "armor": 0.10, "rarity": 1},
	{"id": "helmet_2", "name": "Combat Helmet", "value": 720, "color": Color(0.45, 0.52, 0.60), "type": "helmet", "armor": 0.16, "rarity": 2},
	{"id": "armor_1", "name": "Kevlar Vest", "value": 520, "color": Color(0.40, 0.55, 0.45), "type": "armor", "armor": 0.20, "armor_points": 60.0, "rarity": 1},
	{"id": "armor_2", "name": "Plate Carrier", "value": 980, "color": Color(0.35, 0.45, 0.55), "type": "armor", "armor": 0.30, "armor_points": 110.0, "rarity": 2},
	{"id": "rig_1", "name": "Tactical Rig", "value": 420, "color": Color(0.55, 0.45, 0.35), "type": "rig", "capacity": 4, "rarity": 1},
	{"id": "backpack_1", "name": "Assault Backpack", "value": 640, "color": Color(0.45, 0.40, 0.35), "type": "backpack", "capacity": 8, "rarity": 2},
	{"id": "wep_ar", "name": "Ranger AR", "value": 700, "color": Color(0.45, 0.60, 0.75), "type": "weapon", "weapon": "primary", "reserve": 60, "rarity": 2},
	{"id": "wep_sniper", "name": "Marksman Rifle", "value": 1200, "color": Color(0.60, 0.50, 0.70), "type": "weapon", "weapon": "sniper", "reserve": 8, "rarity": 3},
	{"id": "wep_grenade", "name": "Frag Grenades", "value": 180, "color": Color(0.35, 0.45, 0.30), "type": "weapon", "weapon": "utility", "reserve": 2, "rarity": 1},
]

## Higher loot tiers bias toward higher-rarity items.
static func random_item(tier: int = 0) -> Dictionary:
	var pool: Array = []
	for item in ITEMS:
		var weight := 1 + int(item.get("rarity", 0)) * tier
		for i in weight:
			pool.append(item)
	if pool.is_empty():
		return ITEMS[0].duplicate()
	return pool[randi() % pool.size()].duplicate()

static func by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item.duplicate()
	return {}
