extends Node
# Offline screenshots + smoke test for the cinematic pixel-art INTRO CUTSCENE.
# Instances IntroCutscene.tscn, advances through all three beats and captures each.
# Run windowed:  Godot --path . res://tools/intro_shot.tscn

const INTRO := preload("res://scenes/intro/IntroCutscene.tscn")

var cut
var out_dir: String


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	out_dir = OS.get_user_data_dir() + "/intro_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	cut = INTRO.instantiate()
	add_child(cut)

	# Beat enum on the cutscene: golden=0, fracture=1, shifter=2
	await _wait_beat(0, 14.0)
	await _shot("01_golden_age")

	_press_accept()
	await _wait_beat(1, 14.0)
	await _shot("02_fracture")

	_press_accept()
	await _wait_beat(2, 14.0)
	await _shot("03_last_shifter")

	print("SHOT_DONE")
	get_tree().quit()


func _wait_beat(expected: int, timeout: float) -> void:
	var t := 0.0
	while t < timeout and is_instance_valid(cut):
		if cut.beat == expected and cut.prompt_ready and not cut.busy:
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().create_timer(0.6).timeout


func _press_accept() -> void:
	var down := InputEventAction.new()
	down.action = "ui_accept"; down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = "ui_accept"; up.pressed = false
	Input.parse_input_event(up)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SHOT_SAVED ", name, " err=", err)
