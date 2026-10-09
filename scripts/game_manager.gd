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
const CoopNetScript := preload("res://scripts/coop_net.gd")
const PauseMenuScript := preload("res://scripts/pause_menu.gd")
const InventoryPanelScript := preload("res://scripts/inventory_panel.gd")

var _player: Node3D
var _is_net: bool = false
var _is_host: bool = true
var _coop: CoopNet
var _pause_menu: PauseMenu
var _inventory_panel: InventoryPanel
var _stats_layer: CanvasLayer
var _stats_label: Label
var _loot_by_index: Dictionary = {}
var _weapon: WeaponManager
var _player_health: Health
var _hud: HUD
var _extractions: Array[ExtractionZone] = []
var _map_data: Dictionary = {}
var _inventory: Inventory

var _loot_total: int = 0
var _loot_collected: int = 0
var _kills: int = 0
var _game_over: bool = false

var _healing: bool = false
var _heal_timer: float = 0.0
var _heal_amount: float = 0.0
const HEAL_CHANNEL_TIME := 2.5
var _step_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_is_net = Net.active
	_is_host = not _is_net or multiplayer.is_server()

	_player = get_tree().get_first_node_in_group("player")
	_inventory = Inventory.new()

	_hud = HUDScript.new()
	add_child(_hud)

	_setup_player()
	_build_map()
	_spawn_extraction()
	_spawn_loot()
	_spawn_containers()
	if _is_host:
		_spawn_enemies()
	if _is_net:
		_coop = CoopNetScript.new() as CoopNet
		_coop.name = "CoopNet"
		add_child(_coop)
		_coop.setup(self)
		if not _is_host:
			multiplayer.server_disconnected.connect(_on_host_lost)

	_pause_menu = PauseMenuScript.new() as PauseMenu
	add_child(_pause_menu)
	_pause_menu.setup(_player)
	_pause_menu.quit_to_menu.connect(_return_to_menu)

	_inventory_panel = InventoryPanelScript.new() as InventoryPanel
	add_child(_inventory_panel)
	_inventory_panel.setup(_inventory)
	_inventory_panel.changed.connect(_apply_equipment)
	_apply_equipment()

	_build_stats()
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

	# This manager stays ALWAYS so it can drive the results screen while the
	# tree is paused. The player must NOT inherit that: if it keeps processing
	# while paused, proto_controller._unhandled_input() re-captures the mouse on
	# any left-click, leaving the cursor hidden and frozen after death.
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE

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

func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player != null and "mouse_captured" in _player:
		_player.set("mouse_captured", false)

func _spawn_extraction() -> void:
	var positions: Array = _map_data.get("extractions", [])
	if positions.is_empty():
		positions = [_map_data.get("extraction", Vector3(0, 0, 0))]
	for position in positions:
		var zone := ExtractionZoneScript.new() as ExtractionZone
		zone.position = position
		add_child(zone)
		zone.player_entered.connect(_on_extraction_entered)
		zone.player_exited.connect(_on_extraction_exited)
		zone.channel_progress.connect(_on_channel_progress)
		zone.extracted.connect(_win)
		_extractions.append(zone)

func _set_extractions_ready(value: bool) -> void:
	for zone in _extractions:
		zone.set_ready_state(value)

func _cancel_extractions() -> bool:
	var any := false
	for zone in _extractions:
		if zone.cancel():
			any = true
	return any

func _spawn_loot() -> void:
	var spawn: Vector3 = _map_data.get("player_spawn", Vector3.ZERO)
	var all_loot: Array = _map_data.get("loot", [])
	var intel_positions: Array = _map_data.get("intel", [])
	var loot_positions: Array = all_loot
	if intel_positions.is_empty():
		# Fallback: the first INTEL_TARGET loot spawns are the intel.
		intel_positions = all_loot.slice(0, INTEL_TARGET)
		loot_positions = all_loot.slice(INTEL_TARGET)
	var index := 0
	for position in intel_positions:
		_spawn_loot_item(index, position, true, 1)
		index += 1
	for position in loot_positions:
		var p: Vector3 = position
		var dist: float = p.distance_to(spawn)
		var tier := 0 if dist < 55.0 else (1 if dist < 100.0 else 2)
		_spawn_loot_item(index, position, false, tier)
		index += 1
	_loot_total = intel_positions.size()

func _spawn_loot_item(index: int, position: Vector3, is_intel: bool, tier: int) -> void:
	var loot := LootScript.new() as Loot
	loot.net_id = index
	loot.is_intel = is_intel
	loot.tier = tier
	loot.position = position
	add_child(loot)
	loot.collected.connect(_on_loot_collected.bind(index, is_intel, tier))
	_loot_by_index[index] = loot

func _spawn_containers() -> void:
	for position in _map_data.get("containers", []):
		var container := LootContainerScript.new() as LootContainer
		container.position = position
		add_child(container)
		container.opened.connect(_on_container_opened)

const HUMAN_VARIANTS: Array[String] = ["raider", "raider", "raider", "hunter"]
const BEAST_VARIANTS: Array[String] = ["wolf", "wolf", "wolf", "boar", "brute"]

## Only this many of the loot spawns are objective intel; the rest are optional loot.
const INTEL_TARGET := 3
## Raid time limit (seconds). When it runs out you're MIA and lose the haul.
const RAID_TIME := 600.0

var _raid_time_left: float = RAID_TIME

func _spawn_enemies() -> void:
	var net_id := 1
	for position in _map_data.get("enemies", []):
		var enemy := EnemyScript.new() as Enemy
		enemy.net_id = net_id
		net_id += 1
		enemy.variant = HUMAN_VARIANTS[randi() % HUMAN_VARIANTS.size()]
		enemy.position = position
		add_child(enemy)
		if enemy.health != null:
			enemy.health.died.connect(_on_enemy_died.bind(enemy))
	for position in _map_data.get("beasts", []):
		var beast := EnemyScript.new() as Enemy
		beast.net_id = net_id
		net_id += 1
		beast.variant = BEAST_VARIANTS[randi() % BEAST_VARIANTS.size()]
		beast.position = position
		add_child(beast)
		if beast.health != null:
			beast.health.died.connect(_on_enemy_died.bind(beast))

func _process(delta: float) -> void:
	_update_stats()
	if _game_over:
		return
	_raid_time_left -= delta
	if _hud != null:
		_hud.set_timer(_raid_time_left)
	if _raid_time_left <= 0.0:
		_on_raid_timeout()
		return
	if _player_health != null and _hud != null:
		_hud.set_health(_player_health.current_health, _player_health.max_health)
	_update_healing(delta)
	_update_footsteps(delta)
	_update_compass()

func _update_healing(delta: float) -> void:
	if not _healing:
		return
	_heal_timer += delta
	if _hud != null:
		_hud.set_charge(clampf(_heal_timer / HEAL_CHANNEL_TIME, 0.0, 1.0))
	if _heal_timer >= HEAL_CHANNEL_TIME:
		_healing = false
		if _player_health != null:
			_player_health.heal(_heal_amount)
		Sfx.play("heal")
		if _hud != null:
			_hud.set_charge(0.0)
			_hud.set_hint("Healed +%d HP" % int(_heal_amount))
			_hud.set_carried(_inventory.total_value())

func _update_footsteps(delta: float) -> void:
	_step_timer -= delta
	if _step_timer > 0.0 or _player == null:
		return
	if not _player.has_method("is_on_floor") or not _player.call("is_on_floor"):
		return
	var v: Vector3 = _player.get("velocity") if "velocity" in _player else Vector3.ZERO
	v.y = 0.0
	if v.length() > 2.0:
		Sfx.play("step", -9.0, randf_range(0.94, 1.06))
		_step_timer = 0.38

func _update_compass() -> void:
	if _extractions.is_empty() or _hud == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var best: ExtractionZone = null
	var best_score := INF
	for zone in _extractions:
		var d := zone.global_position.distance_to(camera.global_position)
		# Prefer a ready zone, otherwise the nearest one.
		var score := d if zone.is_ready else d + 100000.0
		if score < best_score:
			best_score = score
			best = zone
	if best == null:
		return
	var to_extraction := best.global_position - camera.global_position
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
		if code == KEY_ESCAPE:
			_toggle_pause()
			return
		if code == KEY_F3:
			_stats_label.visible = not _stats_label.visible
			return
		if code == KEY_M:
			switch_map()
			return
		if code == KEY_H:
			_try_heal()
			return
		if code == KEY_TAB or code == KEY_I:
			_toggle_inventory()
			return

func switch_map() -> void:
	if _is_net:
		if _hud != null:
			_hud.set_hint("Map switching is disabled in co-op")
		return
	MapBuilder.cycle()
	get_tree().paused = false
	get_tree().reload_current_scene()

# --- Inventory ---------------------------------------------------------------

func _add_item(item: Dictionary) -> void:
	# Ammo boxes never enter the bag — they restock weapon reserve directly.
	if String(item.get("id", "")) == "ammo":
		if _weapon != null:
			_weapon.add_ammo_pack()
		_hud.set_hint("Ammo restocked")
		return
	# Weapons unlock a slot instead of taking bag space.
	if String(item.get("type", "")) == "weapon":
		if _weapon != null:
			_weapon.unlock(String(item.get("weapon", "")), int(item.get("reserve", 0)))
			_hud.set_hint("Picked up %s — press its number to equip" % String(item.get("name", "weapon")))
		return
	if _inventory.is_full():
		_hud.set_hint("Bag full — extract to bank your loot")
		return
	_inventory.add(item)
	Meta.quest_event("collect", String(item.get("id", "")))
	_hud.set_carried(_inventory.total_value())

## Press H: channel a bandage (+30) or medkit (+75), interrupted by damage.
func _try_heal() -> void:
	if _game_over or _player_health == null or _hud == null or _healing:
		return
	if _player_health.current_health >= _player_health.max_health:
		_hud.set_hint("Health already full")
		return
	if _weapon != null and _weapon.is_busy():
		_hud.set_hint("Can't heal while reloading or throwing")
		return
	var item := {}
	if _player_health.max_health - _player_health.current_health >= 60.0 \
			and _inventory.count_by_id("medkit") > 0:
		item = _inventory.remove_first_by_id("medkit")
	elif _inventory.count_by_id("bandage") > 0:
		item = _inventory.remove_first_by_id("bandage")
	elif _inventory.count_by_id("medkit") > 0:
		item = _inventory.remove_first_by_id("medkit")
	if item.is_empty():
		_hud.set_hint("No bandages or medkits in your bag")
		return
	_healing = true
	_heal_timer = 0.0
	_heal_amount = 75.0 if String(item.get("id", "")) == "medkit" else 30.0
	_hud.set_hint("Using %s…" % String(item.get("name", "medical item")))
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
	Sfx.play("hurt", -6.0)
	if _hud != null:
		_hud.set_health(current, maximum)
	if _healing:
		_healing = false
		if _hud != null:
			_hud.set_charge(0.0)
			_hud.set_hint("Healing interrupted!")
	if _cancel_extractions() and _hud != null:
		_hud.set_hint("Extraction interrupted!")

func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	Sfx.stop_loop()
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
	_release_mouse()
	get_tree().paused = true

func _on_weapon_changed(weapon_name: String, kind: String, ammo: int, maximum: int) -> void:
	if _hud != null:
		_hud.set_weapon(weapon_name, kind, ammo, maximum)

func _on_ammo_changed(current: int, maximum: int, reserve := -1) -> void:
	if _hud != null:
		_hud.set_ammo(current, maximum, reserve)

func _on_reload_changed(reloading: bool) -> void:
	if _hud != null:
		_hud.set_reloading(reloading)

func _on_hit_confirmed() -> void:
	Sfx.play("hit_tick", -6.0)
	if _hud != null:
		_hud.flash_hit()

func _on_charge_changed(ratio: float) -> void:
	if _hud != null:
		_hud.set_charge(ratio)

func _on_ads_changed(scoped: bool) -> void:
	if _hud != null:
		_hud.set_scope_visible(scoped)

func _on_loot_collected(index: int, is_intel: bool, tier: int) -> void:
	_loot_by_index.erase(index)
	if is_intel:
		_loot_collected += 1
		_update_objective()
		if _loot_collected >= _loot_total:
			_set_extractions_ready(true)
			_hud.set_hint("Intel secured. Reach the extraction marker!")
		else:
			_hud.set_hint("INTEL %d / %d secured" % [_loot_collected, _loot_total])
	else:
		_add_item(ItemDefs.random_item(tier))
	if _coop != null:
		_coop.broadcast_loot_taken(index)
		_coop.broadcast_intel(_loot_collected)

func _on_enemy_died(enemy: Enemy) -> void:
	_kills += 1
	Meta.quest_event("kill")
	if enemy.variant == "wolf":
		Meta.quest_event("kill_wolf")
	_drop_from_enemy(enemy)

## Enemies drop ammo, or sometimes a weapon, where they fell.
func _drop_from_enemy(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	var drop := LootScript.new() as Loot
	drop.drop_item = _random_drop()
	drop.position = enemy.global_position + Vector3(0, 0.2, 0)
	add_child(drop)
	drop.collected.connect(_on_drop_collected.bind(drop.drop_item))

func _random_drop() -> Dictionary:
	var table := ["ammo", "ammo", "ammo", "wep_ar", "wep_grenade", "wep_sniper"]
	return ItemDefs.by_id(table[randi() % table.size()])

func _on_drop_collected(item: Dictionary) -> void:
	if not item.is_empty():
		_add_item(item)

func _on_extraction_entered() -> void:
	if _game_over:
		return
	if _loot_collected >= _loot_total:
		if _hud != null:
			_hud.set_hint("Hold position — extracting…")
	else:
		if _hud != null:
			_hud.set_hint("Collect all intel before extracting (%d / %d)" % [_loot_collected, _loot_total])

func _on_extraction_exited() -> void:
	if _hud != null:
		_hud.set_channel(0.0)

func _on_channel_progress(ratio: float) -> void:
	if _hud != null:
		_hud.set_channel(ratio)

func _update_objective() -> void:
	if _hud == null:
		return
	if _loot_collected >= _loot_total:
		_hud.set_objective("All intel secured — reach the extraction marker")
	else:
		_hud.set_objective("Collect intel: %d / %d" % [_loot_collected, _loot_total])

func _win() -> void:
	if _game_over:
		return
	_game_over = true
	if _hud != null:
		_hud.set_channel(0.0)
	var value := _inventory.total_value()
	if Meta != null:
		Meta.deposit(_inventory.items)
		Meta.quest_event("extract")
		# Weapons found during the raid are kept on a successful extraction.
		if _weapon != null:
			for slot in ["primary", "utility", "sniper"]:
				if _weapon.has_weapon(slot) and not Meta.owns_weapon(slot):
					Meta.owned_weapons.append(slot)
			Meta.save_game()
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
	_release_mouse()
	get_tree().paused = true

func _return_to_menu() -> void:
	get_tree().paused = false
	if _is_net:
		Net.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _toggle_pause() -> void:
	if _pause_menu == null or _game_over:
		return
	if _inventory_panel != null and _inventory_panel.is_open():
		_inventory_panel.close()
		return
	if _pause_menu.is_open():
		_pause_menu.close()
	else:
		_pause_menu.open()

func _toggle_inventory() -> void:
	if _inventory_panel == null or _game_over:
		return
	if _inventory_panel.is_open():
		_inventory_panel.close()
		return
	if _pause_menu != null and _pause_menu.is_open():
		_pause_menu.close()
	_inventory_panel.open()

## Push worn gear onto the player: armour absorbs damage; rig/backpack add slots.
func _apply_equipment() -> void:
	if _player_health == null:
		return
	var armor_points := 0.0
	var armor_fraction := 0.0
	var armor: Dictionary = _inventory.equipment.get("armor", {})
	if not armor.is_empty():
		armor_points = float(armor.get("armor_points", 0.0))
		armor_fraction = float(armor.get("armor", 0.0))
	var helmet: Dictionary = _inventory.equipment.get("helmet", {})
	if not helmet.is_empty():
		armor_fraction = maxf(armor_fraction, float(helmet.get("armor", 0.0)))
	_player_health.armor_points = armor_points
	_player_health.armor_fraction = armor_fraction

func _build_stats() -> void:
	_stats_layer = CanvasLayer.new()
	_stats_layer.layer = 40
	add_child(_stats_layer)
	_stats_label = Label.new()
	_stats_label.position = Vector2(12, 64)
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	_stats_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_stats_label.add_theme_constant_override("shadow_offset_x", 1)
	_stats_label.add_theme_constant_override("shadow_offset_y", 1)
	_stats_layer.add_child(_stats_label)
	_stats_label.visible = false

func _update_stats() -> void:
	if _stats_label == null or not _stats_label.visible:
		return
	_stats_label.text = "FPS %d   enemies %d   draws %d   nodes %d" % [
		Engine.get_frames_per_second(),
		get_tree().get_nodes_in_group("enemies").size(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	]

func _on_raid_timeout() -> void:
	if _game_over:
		return
	_game_over = true
	Sfx.stop_loop()
	var lost := _inventory.total_value()
	if Meta != null:
		Meta.register_death()
	_hud.show_results(
		"MISSING IN ACTION",
		Color(1.0, 0.5, 0.3),
		PackedStringArray([
			"The raid timer ran out.",
			"Lost loot:  $%d" % lost,
			"",
			"Press Enter to return to base",
		])
	)
	_release_mouse()
	get_tree().paused = true

func _on_host_lost() -> void:
	if _game_over:
		return
	_game_over = true
	Sfx.stop_loop()
	_hud.show_results(
		"HOST DISCONNECTED",
		Color(1.0, 0.6, 0.3),
		PackedStringArray([
			"The host left the raid.",
			"",
			"Press Enter to return to base",
		])
	)
	_release_mouse()
	get_tree().paused = true

# --- Co-op hooks -------------------------------------------------------------

func get_local_player() -> Node3D:
	return _player

## Host: a client asked to pick up loot `index`; validate range, then collect.
func host_try_pickup(index: int, from_position: Vector3) -> void:
	var loot = _loot_by_index.get(index)
	if loot == null or not is_instance_valid(loot):
		return
	if from_position.distance_to(loot.global_position) > 3.5:
		return
	loot.collect_remote()

## Everyone: the host removed loot `index` (remote pickup or its own).
func on_loot_taken_remote(index: int) -> void:
	var loot = _loot_by_index.get(index)
	if loot != null and is_instance_valid(loot):
		loot.queue_free()
	_loot_by_index.erase(index)

## Client: the host's shared intel count changed.
func on_intel_remote(count: int) -> void:
	_loot_collected = count
	_update_objective()
	if _loot_collected >= _loot_total:
		_set_extractions_ready(true)
