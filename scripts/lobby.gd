extends Control
class_name Lobby

## Pre-raid lobby. Solo players can pick a map and deploy; in co-op the host
## chooses the map and everyone deploys together.

var _map_label: Label
var _players_label: Label
var _status: Label
var _deploy: Button
var _map_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)

	var title := Label.new()
	title.text = "LOBBY"
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_map_label = Label.new()
	_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_map_label)

	_map_button = Button.new()
	_map_button.text = "Change map"
	_map_button.custom_minimum_size = Vector2(240, 38)
	_map_button.pressed.connect(_cycle_map)
	vb.add_child(_map_button)

	_players_label = Label.new()
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_players_label)

	_deploy = Button.new()
	_deploy.text = "DEPLOY"
	_deploy.custom_minimum_size = Vector2(260, 46)
	_deploy.pressed.connect(_deploy_now)
	vb.add_child(_deploy)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	vb.add_child(_status)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_back)
	vb.add_child(back)

	_refresh()

	# Headless co-op test: the host auto-deploys after peers have joined.
	if "test" in OS.get_cmdline_user_args():
		get_tree().create_timer(4.0).timeout.connect(func():
			if _is_authority():
				_deploy_now())

func _process(_delta: float) -> void:
	_refresh_players()

func _is_authority() -> bool:
	return not Net.active or Net.is_host()

func _refresh() -> void:
	_map_label.text = "Map:  %s" % MapBuilder.title(MapBuilder.current_map)
	_map_button.disabled = not _is_authority()
	_deploy.disabled = not _is_authority()
	_deploy.text = "DEPLOY" if _is_authority() else "Waiting for host…"
	_status.text = "" if _is_authority() else "The host will start the raid."
	_refresh_players()

func _refresh_players() -> void:
	if not Net.active:
		_players_label.text = "Solo raid"
		return
	var lines := PackedStringArray()
	for id in Net.peer_ids():
		lines.append("  %s   (peer %d)" % [String(Net.players.get(id, "?")), int(id)])
	_players_label.text = "Players:\n" + "\n".join(lines)

func _cycle_map() -> void:
	if not _is_authority():
		return
	MapBuilder.cycle()
	_refresh()

func _deploy_now() -> void:
	if not _is_authority():
		return
	if Net.active:
		start_raid.rpc(MapBuilder.current_map)
	else:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")

## Host -> everyone: load the chosen map together.
@rpc("authority", "reliable", "call_local")
func start_raid(map_id: String) -> void:
	MapBuilder.current_map = map_id
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _back() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
