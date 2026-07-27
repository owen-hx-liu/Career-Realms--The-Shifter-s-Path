extends Node
#
# Offline visual harness for the remastered hospital ward (scenes/world_3.tscn).
# Loads the real ward as the current scene (so the player's camera sets itself
# up), frames the attending NPC, and screenshots the title card, the floating
# prompt pill, and the dialogue box (mid-reveal, full, page 2).
#
# Run windowed (needs rendering):
#     Godot --path . res://tools/hospital_shot.tscn
# PNGs -> <user_data>/hospital_shots/

const WORLD := "res://scenes/world_3.tscn"

var _dir: String


func _ready() -> void:
	_dir = OS.get_user_data_dir() + "/hospital_shots"
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	# safety net so the harness can never hang
	get_tree().create_timer(30.0).timeout.connect(get_tree().quit)

	var w: Node = load(WORLD).instantiate()
	# root is still setting up when _ready runs -> add deferred, then adopt it
	get_tree().root.add_child.call_deferred(w)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = w

	# let the player's deferred camera setup settle
	for _i in range(40):
		await get_tree().process_frame

	var npc: Node = w.get_node("NPC")
	var player: Node = w.get_node("player")

	# frame the camera on the attending by parking the player beside them
	player.global_position = npc.global_position + Vector2(0, 38)
	var cam: Camera2D = player.get_node_or_null("worldcamera")
	if cam:
		cam.enabled = true
		cam.make_current()
	for _i in range(20):
		await get_tree().process_frame

	# 01 — entry title card (still on screen early)
	await _shot("01_title")

	# wait for the title card to fade out, then show the floating prompt
	await _wait(3.4)
	npc.set("player_nearby", true)
	await _wait(0.4)
	await _shot("02_prompt")

	# 03 — dialogue, mid typewriter reveal
	npc.dialogue_box.start_dialogue(npc.dialogue_pages, "Dr. Almeida")
	await _wait(0.35)
	await _shot("03_dialogue_reveal")

	# 04 — dialogue fully revealed (continue chip pulsing)
	await _wait(2.6)
	await _shot("04_dialogue_full")

	# 05 — advance to page 2, fully revealed
	npc.dialogue_box._advance()
	await _wait(3.0)
	await _shot("05_dialogue_page2")

	print("HOSPITAL SHOTS DONE -> ", _dir)
	get_tree().quit()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir + "/" + name + ".png"
	img.save_png(path)
	print("shot: ", path)
