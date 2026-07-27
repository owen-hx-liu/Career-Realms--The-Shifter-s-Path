extends Node
# Offline screenshots + smoke test of the NANOBOT SURGEON quest.
# Drives intro -> gameplay -> interstitial -> victory and saves PNGs, printing
# any runtime errors along the way.
# Run windowed:  Godot --path . res://tools/nanobot_shot.tscn

const QUEST := preload("res://scenes/nanobot_quest.tscn")

var quest
var out_dir: String


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	out_dir = OS.get_user_data_dir() + "/nanobot_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	quest = QUEST.instantiate()
	quest.record_on_win = false
	add_child(quest)
	for i in range(12):
		await get_tree().process_frame
	await _shot("01_intro")

	# begin run -> patient 1 gameplay
	quest._start_run()
	for i in range(20):
		await get_tree().process_frame
	# stage a nice in-progress repair shot: park the bot on a breach mid-seal
	if quest.sites.size() > 0:
		var s = quest.sites[0]
		quest.bot.position = s.pos
		quest.bot_glow.position = s.pos
		s.progress = 0.62
		quest.gauge.queue_redraw()
	for i in range(4):
		await get_tree().process_frame
	await _shot("02_play")

	# exercise the collision / damage / knockback path once (no real input
	# in headless, so this is the only way to smoke-test _hit)
	if quest.hazards.size() > 0:
		quest._hit(quest.hazards[0])
		for i in range(4):
			await get_tree().process_frame
		print("AFTER_HIT  stability=", int(quest.stability), " phase=", quest.phase)

	# seal everyone, screenshotting an interstitial along the way
	await _seal_all()
	await get_tree().create_timer(0.4).timeout
	await _shot("03_interstitial")
	quest._next_patient()
	for i in range(8):
		await get_tree().process_frame
	await _seal_all()
	await get_tree().create_timer(0.3).timeout
	quest._next_patient()
	for i in range(8):
		await get_tree().process_frame
	await _seal_all()
	await get_tree().create_timer(0.8).timeout
	await _shot("04_victory")

	print("SHOT_DONE  phase=", quest.phase, " score=", quest.score, " stability=", int(quest.stability))
	get_tree().quit()


func _seal_all() -> void:
	for s in quest.sites.duplicate():
		if not s.healed:
			quest._seal(s)
			await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SHOT_SAVED ", name, " err=", err)
