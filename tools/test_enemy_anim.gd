extends SceneTree

## Dev tool: verifies enemy models are rigged and clips are mapped/playing.
## Usage: godot --headless --path <proj> --script res://tools/test_enemy_anim.gd

func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in 12:
		await process_frame
	var enemies := get_nodes_in_group("enemies")
	print("ENEMYANIM enemies=%d" % enemies.size())
	var seen: Dictionary = {}
	var ok := true
	for enemy in enemies:
		var variant := String(enemy.variant)
		if seen.has(variant):
			continue
		seen[variant] = true
		var anim: AnimationPlayer = enemy._anim
		var keys: Array = enemy._clips.keys()
		keys.sort()
		var scale_v: Vector3 = enemy._model.scale
		print("ENEMYANIM variant=%s anim=%s clips=%s current=%s scale=%.3f" % [
			variant, anim != null, keys, enemy._current_clip, scale_v.y])
		if anim == null or keys.is_empty():
			ok = false
		if scale_v.y < 0.001 or scale_v.y > 1000.0:
			ok = false
	print("ENEMYANIM %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
