extends RefCounted
class_name WeaponDefs

## The player loadout. Slots: primary, secondary, melee, utility, sniper.
## Add more by adding dictionaries here (models are the CC0 Kenney kits).
## `gravity` (m/s^2) makes rounds arc — higher = more visible bullet drop.

const BLASTER_M := preload("res://assets/kenney/blaster-kit/blaster-m.glb")
const BLASTER_A := preload("res://assets/kenney/blaster-kit/blaster-a.glb")
const BLASTER_R := preload("res://assets/kenney/blaster-kit/blaster-r.glb")
const KNIFE := preload("res://assets/kenney/melee/knife_sharp.glb")
const PICKAXE := preload("res://assets/kenney/melee/tool-pickaxe.glb")
const GRENADE := preload("res://assets/kenney/blaster-kit/grenade-a.glb")
const SCOPE := preload("res://assets/kenney/blaster-kit/scope-small.glb")
const SCOPE_LARGE := preload("res://assets/kenney/blaster-kit/scope-large-b.glb")
const SILENCER := preload("res://assets/kenney/blaster-kit/silencer-small.glb")

static func loadout() -> Array:
	return [
		{
			"kind": "gun", "slot": "primary", "name": "Ranger AR",
			"model": BLASTER_M, "accessory": SCOPE,
			"damage": 24.0, "fire_interval": 0.09, "magazine": 30, "reload": 2.1, "reserve": 90,
			"sfx": "shot_ar",
			"automatic": true, "bullet_speed": 95.0, "spread": 1.1, "pellets": 1, "gravity": 5.0, "ads_fov": 45.0,
			"view_pos": Vector3(0.12, -0.44, -0.12), "view_rot": Vector3.ZERO, "view_size": 0.72,
		},
		{
			"kind": "gun", "slot": "secondary", "name": "Sidearm",
			"model": BLASTER_A, "accessory": SILENCER,
			"damage": 30.0, "fire_interval": 0.17, "magazine": 12, "reload": 1.3, "reserve": 48,
			"sfx": "shot_pistol",
			"automatic": false, "bullet_speed": 80.0, "spread": 0.7, "pellets": 1, "gravity": 6.0, "ads_fov": 55.0,
			"view_pos": Vector3(0.14, -0.40, -0.14), "view_rot": Vector3.ZERO, "view_size": 0.5,
		},
		{
			"kind": "melee", "slot": "melee", "name": "Combat Knife",
			"model": KNIFE,
			"damage": 55.0, "range": 2.6, "fire_interval": 0.4,
			"sfx": "swing",
			"view_pos": Vector3(0.34, -0.36, -0.44), "view_rot": Vector3(-34.0, -58.0, 0.0), "view_size": 0.7,
		},
		{
			"kind": "utility", "slot": "utility", "name": "Frag Grenade",
			"model": GRENADE,
			"count": 3, "damage": 120.0, "radius": 6.0, "min_speed": 9.0, "max_speed": 27.0, "charge_time": 1.2, "fuse": 1.9,
			"sfx": "throw",
			"view_pos": Vector3(0.30, -0.40, -0.55), "view_rot": Vector3.ZERO, "view_size": 0.3,
		},
		{
			"kind": "gun", "slot": "sniper", "name": "Marksman Rifle",
			"model": BLASTER_R, "accessory": SCOPE_LARGE,
			"damage": 95.0, "fire_interval": 1.1, "magazine": 5, "reload": 2.8, "reserve": 10,
			"sfx": "shot_sniper",
			"automatic": false, "bullet_speed": 130.0, "spread": 0.1, "pellets": 1, "gravity": 12.0, "ads_fov": 16.0, "scope": true,
			"view_pos": Vector3(0.12, -0.46, -0.24), "view_rot": Vector3.ZERO, "view_size": 1.0,
		},
	]

## Pickaxe is available as an alternate melee if you want to swap it in.
static func alternate_melee() -> PackedScene:
	return PICKAXE
