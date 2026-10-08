extends Node

## Persistent meta-progression, saved to user://save.json.
## Registered as the "Meta" autoload singleton.

const SAVE_PATH := "user://save.json"

var currency: int = 0
var extractions: int = 0
var deaths: int = 0
var best_extract: int = 0
var stash: Array = []

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		currency = int(data.get("currency", 0))
		extractions = int(data.get("extractions", 0))
		deaths = int(data.get("deaths", 0))
		best_extract = int(data.get("best_extract", 0))
		stash = data.get("stash", [])

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"currency": currency,
		"extractions": extractions,
		"deaths": deaths,
		"best_extract": best_extract,
		"stash": stash,
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

func reset() -> void:
	currency = 0
	extractions = 0
	deaths = 0
	best_extract = 0
	stash = []
	save_game()
