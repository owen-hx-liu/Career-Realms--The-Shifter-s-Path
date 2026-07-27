extends Node
# Offline screenshot harness for the reworked Dyson Swarm quest.
# Run windowed:  Godot --path . res://tools/shot_dyson.tscn
# Captures each phase: briefing card, controls card, live playfield, debrief.

const QUEST := preload("res://scenes/dyson_swarm.tscn")
const STATES := ["briefing", "controls", "play", "result"]

func _capture(name: String, out_dir: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	print("SHOT_SAVED ", name, " err=", img.save_png(path))

func _ready() -> void:
	var out_dir := OS.get_user_data_dir() + "/dyson_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	for st in STATES:
		var q = QUEST.instantiate()
		q.record_on_win = false
		q.auto_return_delay = 0.0
		add_child(q)
		await get_tree().process_frame
		await get_tree().process_frame

		if st == "briefing":
			pass  # _ready() shows the first briefing card automatically
		elif q.has_method("debug_setup"):
			q.debug_setup(st)

		if st == "play":
			# Deploy a spread of mirrors and throw in some debris for the shot.
			var ship = q.ship
			ship.mirrors_left = 60   # temporary stock so we can fill every ring
			for ring in range(3):
				ship.selected_ring = ring
				var n: int = ship.MAX_MIRRORS_PER_RING[ring]
				for k in range(n):
					ship.angle = (TAU / n) * k + 0.2 * ring
					ship.drop_mirror()
			ship.mirrors_left = 4    # restore a believable reserve for the HUD
			ship.selected_ring = 2
			for i in range(4):
				q._spawn_debris()

		await get_tree().create_timer(0.8).timeout
		await _capture(st, out_dir)
		q.queue_free()
		await get_tree().process_frame

	print("SHOT_DONE")
	get_tree().quit()
