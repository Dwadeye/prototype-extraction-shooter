extends SceneTree

## Dev tool: verifies that death releases the mouse and freezes the player.
## Usage: godot --headless --path <proj> --script res://tools/test_death_mouse.gd

func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var player: Node = get_first_node_in_group("player")
	if player == null:
		print("DEATHMOUSE FAIL no player")
		quit(1)
		return
	print("DEATHMOUSE before paused=%s captured=%s" % [paused, player.get("mouse_captured")])
	main._on_player_died()
	await process_frame
	var captured: bool = player.get("mouse_captured")
	var pausable: bool = player.process_mode == Node.PROCESS_MODE_PAUSABLE
	var ok: bool = (captured == false) and pausable and paused
	print("DEATHMOUSE after paused=%s captured=%s pausable=%s" % [paused, captured, pausable])
	print("DEATHMOUSE %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
