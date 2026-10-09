extends Control

## Title screen. Deploy solo, host a co-op raid, or join a friend.

var _stats: Label
var _status: Label
var _ip_field: LineEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "EXTRACTION"
	title.add_theme_font_size_override("font_size", 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a prototype extraction shooter"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_stats)
	_refresh()

	var deploy := Button.new()
	deploy.text = "DEPLOY (solo)"
	deploy.custom_minimum_size = Vector2(260, 42)
	deploy.pressed.connect(_on_deploy)
	vbox.add_child(deploy)

	var host := Button.new()
	host.text = "HOST CO-OP"
	host.custom_minimum_size = Vector2(260, 42)
	host.pressed.connect(_on_host)
	vbox.add_child(host)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	join_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(join_row)

	_ip_field = LineEdit.new()
	_ip_field.placeholder_text = "host IP (e.g. 127.0.0.1)"
	_ip_field.text = "127.0.0.1"
	_ip_field.custom_minimum_size = Vector2(160, 42)
	join_row.add_child(_ip_field)

	var join := Button.new()
	join.text = "JOIN"
	join.custom_minimum_size = Vector2(92, 42)
	join.pressed.connect(_on_join)
	join_row.add_child(join)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	vbox.add_child(_status)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	var wipe := Button.new()
	wipe.text = "Reset progress"
	wipe.pressed.connect(_on_reset)
	vbox.add_child(wipe)

	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)

	Net.connect_failed.connect(_on_connect_failed)
	Net.connected_to_host.connect(_on_connected)
	Net.lobby_changed.connect(_refresh_status)

	# Headless testing: `-- host` / `-- join` auto-start from the command line.
	var args := OS.get_cmdline_user_args()
	if "host" in args:
		_on_host.call_deferred()
	elif "join" in args:
		_on_join.call_deferred()

func _refresh() -> void:
	_stats.text = "Credits  $%d\nExtractions  %d          Deaths  %d\nStash value  $%d          Best haul  $%d" % [
		Meta.currency, Meta.extractions, Meta.deaths, Meta.stash_value(), Meta.best_extract,
	]

func _refresh_status() -> void:
	if Net.active and Net.players.size() > 1:
		_status.text = "Players: %d" % Net.players.size()

func _on_deploy() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_host() -> void:
	var err := Net.host()
	if err != "":
		_status.text = err
		return
	_status.text = "Hosting on port %d — waiting for players…" % Net.DEFAULT_PORT
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_join() -> void:
	var ip := _ip_field.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var err := Net.join(ip)
	if err != "":
		_status.text = err
		return
	_status.text = "Connecting to %s…" % ip

func _on_connected() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_connect_failed() -> void:
	_status.text = "Connection failed."

func _on_reset() -> void:
	Meta.reset()
	_refresh()
