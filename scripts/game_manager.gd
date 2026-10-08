extends Node3D
class_name GameManager

## Raid controller. Loop:
##   1. Collect intel and search containers (loot goes into your bag).
##   2. Reach the extraction marker with the intel to bank your haul.
##   3. Die and you lose everything you were carrying.
## Press M to switch maps, Tab to view your bag.

const LootScript := preload("res://scripts/loot.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ExtractionZoneScript := preload("res://scripts/extraction_zone.gd")
const HUDScript := preload("res://scripts/hud.gd")
const LootContainerScript := preload("res://scripts/loot_container.gd")

var _player: Node3D
var _weapon: WeaponManager
var _player_health: Health
var _hud: HUD
var _extraction: ExtractionZone
var _map_data: Dictionary = {}
var _inventory: Inventory

var _loot_total: int = 0
var _loot_collected: int = 0
var _kills: int = 0
var _game_over: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = get_tree().get_first_node_in_group("player")
	_inventory = Inventory.new()

	_hud = HUDScript.new()
	add_child(_hud)

	_setup_player()
	_build_map()
	_spawn_extraction()
	_spawn_loot()
	_spawn_containers()
	_spawn_enemies()
	_capture_mouse()

	if _player_health != null:
		_hud.setup(_player_health.max_health)
		_hud.set_health(_player_health.current_health, _player_health.max_health)
	if _weapon != null:
		_hud.set_weapon_summary(_weapon.current_summary())
	_hud.set_map_name(String(_map_data.get("title", "?")))
	_hud.set_carried(0)

	_update_objective()

func _setup_player() -> void:
	if _player == null:
		push_error("GameManager: no node in group 'player' was found.")
		return

	_player_health = _player.get_node_or_null("Health") as Health
	_weapon = _player.get_node_or_null("Head/Weapon Pivot/WeaponManager") as WeaponManager

	if _player_health != null:
		_player_health.damaged.connect(_on_player_damaged)
		_player_health.died.connect(_on_player_died)
	if _weapon != null:
		_weapon.weapon_changed.connect(_on_weapon_changed)
		_weapon.ammo_changed.connect(_on_ammo_changed)
		_weapon.reload_state_changed.connect(_on_reload_changed)
		_weapon.hit_confirmed.connect(_on_hit_confirmed)
		_weapon.charge_changed.connect(_on_charge_changed)
		_weapon.ads_changed.connect(_on_ads_changed)

func _build_map() -> void:
	_map_data = MapBuilder.build(MapBuilder.current_map, self)
	if _player != null:
		var spawn: Vector3 = _map_data.get("player_spawn", Vector3(0, 1, 0))
		_player.global_position = spawn
		_player.rotation.y = 0.0
		_player.set("look_rotation", Vector2(0.0, 0.0))

func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player != null and "mouse_captured" in _player:
		_player.set("mouse_captured", true)

func _spawn_extraction() -> void:
	var position: Vector3 = _map_data.get("extraction", Vector3(0, 0, 0))
	_extraction = ExtractionZoneScript.new() as ExtractionZone
	_extraction.position = position
	add_child(_extraction)
	_extraction.player_entered.connect(_on_extraction_entered)

func _spawn_loot() -> void:
	for position in _map_data.get("loot", []):
		var loot := LootScript.new() as Loot
		loot.position = position
		add_child(loot)
		loot.collected.connect(_on_loot_collected)
		_loot_total += 1

func _spawn_containers() -> void:
	for position in _map_data.get("containers", []):
		var container := LootContainerScript.new() as LootContainer
		container.position = position
		add_child(container)
		container.opened.connect(_on_container_opened)

func _spawn_enemies() -> void:
	for position in _map_data.get("enemies", []):
		var enemy := EnemyScript.new() as Enemy
		enemy.position = position
		add_child(enemy)
		if enemy.health != null:
			enemy.health.died.connect(_on_enemy_died.bind(enemy))

func _process(_delta: float) -> void:
	if _game_over:
		return
	if _player_health != null and _hud != null:
		_hud.set_health(_player_health.current_health, _player_health.max_health)
	_update_compass()

func _update_compass() -> void:
	if _extraction == null or _hud == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_extraction := _extraction.global_position - camera.global_position
	to_extraction.y = 0.0
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	var angle := forward.signed_angle_to(to_extraction, Vector3.UP)
	_hud.set_compass(-angle, to_extraction.length(), true)

func _unhandled_input(event: InputEvent) -> void:
	if _game_over:
		if event.is_action_pressed("ui_accept"):
			_return_to_menu()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var code := (event as InputEventKey).physical_keycode
		if code == KEY_M:
			switch_map()
			return
		if code == KEY_TAB or code == KEY_I:
			_hud.toggle_inventory(_inventory_text())

func switch_map() -> void:
	MapBuilder.cycle()
	get_tree().paused = false
	get_tree().reload_current_scene()

# --- Inventory ---------------------------------------------------------------

func _add_item(item: Dictionary) -> void:
	if _inventory.is_full():
		_hud.set_hint("Bag full — extract to bank your loot")
		return
	_inventory.add(item)
	_hud.set_carried(_inventory.total_value())

func _inventory_text() -> String:
	var counts: Dictionary = {}
	var order: Array = []
	for item in _inventory.items:
		var key := String(item.get("name", "?"))
		if not counts.has(key):
			counts[key] = {"count": 0, "value": int(item.get("value", 0))}
			order.append(key)
		counts[key]["count"] += 1

	var lines := PackedStringArray()
	lines.append("BAG   %d / %d        VALUE  $%d" % [_inventory.items.size(), _inventory.capacity, _inventory.total_value()])
	lines.append("")
	if order.is_empty():
		lines.append("   (empty)")
	else:
		for key in order:
			lines.append("   %s  x%d    $%d" % [key, counts[key]["count"], counts[key]["value"] * counts[key]["count"]])
	lines.append("")
	lines.append("Loot is banked when you extract. Die and it's lost.")
	return "\n".join(lines)

func _on_container_opened(_container: LootContainer, items: Array) -> void:
	var picked := 0
	for item in items:
		if _inventory.is_full():
			break
		_add_item(item)
		picked += 1
	if picked > 0:
		_hud.set_hint("Picked up %d item(s)" % picked)

# --- Signal handlers ---------------------------------------------------------

func _on_player_damaged(_amount: float, current: float, maximum: float) -> void:
	if _hud != null:
		_hud.set_health(current, maximum)

func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	var lost := _inventory.total_value()
	if Meta != null:
		Meta.register_death()
	_hud.show_results(
		"KILLED IN ACTION",
		Color(1.0, 0.35, 0.3),
		PackedStringArray([
			"Lost loot:  $%d" % lost,
			"",
			"Credits:  $%d          Deaths:  %d" % [Meta.currency, Meta.deaths],
			"",
			"Press Enter to return to base",
		])
	)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func _on_weapon_changed(weapon_name: String, kind: String, ammo: int, maximum: int) -> void:
	if _hud != null:
		_hud.set_weapon(weapon_name, kind, ammo, maximum)

func _on_ammo_changed(current: int, maximum: int) -> void:
	if _hud != null:
		_hud.set_ammo(current, maximum)

func _on_reload_changed(reloading: bool) -> void:
	if _hud != null:
		_hud.set_reloading(reloading)

func _on_hit_confirmed() -> void:
	if _hud != null:
		_hud.flash_hit()

func _on_charge_changed(ratio: float) -> void:
	if _hud != null:
		_hud.set_charge(ratio)

func _on_ads_changed(scoped: bool) -> void:
	if _hud != null:
		_hud.set_scope_visible(scoped)

func _on_loot_collected() -> void:
	_loot_collected += 1
	_add_item(ItemDefs.random_item())
	_update_objective()
	if _loot_collected >= _loot_total and _extraction != null:
		_extraction.set_ready_state(true)
		_hud.set_hint("Intel secured. Reach the extraction marker!")

func _on_enemy_died(_enemy: Enemy) -> void:
	_kills += 1

func _on_extraction_entered() -> void:
	if _game_over:
		return
	if _loot_collected >= _loot_total:
		_win()
	else:
		if _hud != null:
			_hud.set_hint("Collect all intel before extracting (%d / %d)" % [_loot_collected, _loot_total])

func _update_objective() -> void:
	if _hud == null:
		return
	if _loot_collected >= _loot_total:
		_hud.set_objective("All intel secured — reach the extraction marker")
	else:
		_hud.set_objective("Collect intel: %d / %d" % [_loot_collected, _loot_total])

func _win() -> void:
	_game_over = true
	var value := _inventory.total_value()
	if Meta != null:
		Meta.deposit(_inventory.items)
	_inventory.clear()
	_hud.set_carried(0)
	_hud.show_results(
		"EXTRACTED",
		Color(0.4, 1.0, 0.5),
		PackedStringArray([
			"Haul banked:  $%d" % value,
			"",
			"Credits:  $%d          Extractions:  %d" % [Meta.currency, Meta.extractions],
			"Best haul:  $%d" % Meta.best_extract,
			"",
			"Press Enter to return to base",
		])
	)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
