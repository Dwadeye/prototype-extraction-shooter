extends Control

## Title screen. Deploy into a raid; progress is stored by the Meta autoload.

var _stats: Label

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
	vbox.add_theme_constant_override("separation", 14)
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
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_stats)
	_refresh()

	var deploy := Button.new()
	deploy.text = "DEPLOY"
	deploy.custom_minimum_size = Vector2(240, 44)
	deploy.pressed.connect(_on_deploy)
	vbox.add_child(deploy)

	var wipe := Button.new()
	wipe.text = "Reset progress"
	wipe.pressed.connect(_on_reset)
	vbox.add_child(wipe)

	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)

func _refresh() -> void:
	_stats.text = "Credits  $%d\nExtractions  %d          Deaths  %d\nStash value  $%d          Best haul  $%d" % [
		Meta.currency, Meta.extractions, Meta.deaths, Meta.stash_value(), Meta.best_extract,
	]

func _on_deploy() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_reset() -> void:
	Meta.reset()
	_refresh()
