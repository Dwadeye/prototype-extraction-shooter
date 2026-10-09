extends SceneTree

## Dev tool: verifies intel pickups increment the objective counter.

func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in 12:
		await process_frame
	var loots := get_nodes_in_group("loot")
	var intel := 0
	for l in loots:
		if bool(l.get("is_intel")):
			intel += 1
	print("INTEL total_loot=%d intel=%d gm_total=%d collected_before=%d" % [loots.size(), intel, main._loot_total, main._loot_collected])
	var got := 0
	for l in loots:
		if bool(l.get("is_intel")):
			l.call("_collect")
			got += 1
			await process_frame
	print("INTEL collected_intel=%d gm_collected=%d objective=%s" % [got, main._loot_collected, main._hud._objective_label.text if main._hud != null else "?"])
	quit()
