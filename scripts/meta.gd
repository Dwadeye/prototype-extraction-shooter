extends Node

## Persistent meta-progression, saved to user://save.json.
## Registered as the "Meta" autoload singleton.

const SAVE_PATH := "user://save.json"

var currency: int = 0
var extractions: int = 0
var deaths: int = 0
var best_extract: int = 0
var stash: Array = []
## Weapon slots the player owns (start with pistol + knife; buy or extract more).
var owned_weapons: Array = ["secondary", "melee"]

var settings: Dictionary = {}
## Trader tasks. Each: {id, type, desc, target, progress, done, reward, payload?}
var quests: Array = []
const DEFAULT_QUESTS := [
	{"id": "kill5", "type": "kill", "desc": "Eliminate 5 enemies", "target": 5, "progress": 0, "done": false, "reward": 400},
	{"id": "wolves", "type": "kill_wolf", "desc": "Kill 3 wolves", "target": 3, "progress": 0, "done": false, "reward": 600},
	{"id": "extract3", "type": "extract", "desc": "Extract successfully 3 times", "target": 3, "progress": 0, "done": false, "reward": 500},
	{"id": "watch", "type": "collect", "payload": "watch", "desc": "Find a Luxury Watch", "target": 1, "progress": 0, "done": false, "reward": 800},
]
const DEFAULT_SETTINGS := {
	"master_volume": 0.9,
	"sfx_volume": 0.9,
	"sensitivity": 0.002,
	"fov": 75.0,
	"invert_y": false,
}
const SAVE_VERSION := 2

func _ready() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	quests = DEFAULT_QUESTS.duplicate(true)
	load_game()

func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		# Corrupt save: keep a backup and start fresh instead of crashing.
		var backup := FileAccess.open(SAVE_PATH + ".corrupt", FileAccess.WRITE)
		if backup != null:
			backup.store_string(text)
		push_warning("Save file corrupt; backed up to save.json.corrupt and reset.")
		return
	currency = int(data.get("currency", 0))
	extractions = int(data.get("extractions", 0))
	deaths = int(data.get("deaths", 0))
	best_extract = int(data.get("best_extract", 0))
	stash = data.get("stash", [])
	owned_weapons = data.get("owned_weapons", ["secondary", "melee"])
	quests = data.get("quests", DEFAULT_QUESTS.duplicate(true))
	if data.get("settings") is Dictionary:
		settings.merge(data["settings"], true)
	_migrate(int(data.get("save_version", 1)))

func _migrate(from_version: int) -> void:
	# v1 predates the version field and settings; defaults already applied above.
	if from_version < SAVE_VERSION:
		save_game()

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"save_version": SAVE_VERSION,
		"currency": currency,
		"extractions": extractions,
		"deaths": deaths,
		"best_extract": best_extract,
		"stash": stash,
		"owned_weapons": owned_weapons,
		"quests": quests,
		"settings": settings,
	}))

func deposit(items: Array) -> int:
	var value := 0
	for item in items:
		stash.append(item)
		value += int(item.get("value", 0))
	currency += value
	extractions += 1
	best_extract = maxi(best_extract, value)
	save_game()
	return value

func register_death() -> void:
	deaths += 1
	save_game()

func stash_value() -> int:
	var value := 0
	for item in stash:
		value += int(item.get("value", 0))
	return value

func owns_weapon(slot: String) -> bool:
	return owned_weapons.has(slot)

## Returns true if the purchase went through.
func buy_weapon(slot: String, price: int) -> bool:
	if owns_weapon(slot):
		return false
	if currency < price:
		return false
	currency -= price
	owned_weapons.append(slot)
	save_game()
	return true

func reset() -> void:
	currency = 0
	extractions = 0
	deaths = 0
	best_extract = 0
	stash = []
	owned_weapons = ["secondary", "melee"]
	quests = DEFAULT_QUESTS.duplicate(true)
	save_game()

## Advance any quest matching `type` (and optional `payload`); grants rewards.
func quest_event(type: String, payload: String = "") -> void:
	var changed := false
	for quest in quests:
		if bool(quest.get("done", false)) or String(quest.get("type", "")) != type:
			continue
		if quest.has("payload") and String(quest["payload"]) != payload:
			continue
		quest["progress"] = int(quest.get("progress", 0)) + 1
		if int(quest["progress"]) >= int(quest.get("target", 1)):
			quest["done"] = true
			currency += int(quest.get("reward", 0))
		changed = true
	if changed:
		save_game()
