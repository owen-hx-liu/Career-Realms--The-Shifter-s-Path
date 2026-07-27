extends Node
# Offline screenshots + smoke test for the dynamic pixel-art TITLE SCREEN.
# Instances the title scene, lets the intro animation settle, then captures the
# idle menu, a different selection, and the Controls panel.
# Run windowed:  Godot --path . res://tools/title_shot.tscn

const TITLE := preload("res://scenes/titlescreenreal.tscn")

var scr
var out_dir: String


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	out_dir = OS.get_user_data_dir() + "/title_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	scr = TITLE.instantiate()
	add_child(scr)

	# let the staged intro animation finish
	await _wait_ready(8.0)
	await _settle(0.6)
	await _shot("01_title")

	# move the selection down to "Credits"
	_press("ui_down"); await _settle(0.25)
	_press("ui_down"); await _settle(0.4)
	await _shot("02_selected")

	# open the Controls panel
	scr._on_controls()
	await _settle(0.6)
	await _shot("03_controls")

	# close it, then open the About panel
	scr._hide_info()
	await _settle(0.5)
	scr._on_credits()
	await _settle(0.6)
	await _shot("04_about")

	print("SHOT_DONE")
	get_tree().quit()


func _wait_ready(timeout: float) -> void:
	var t := 0.0
	while t < timeout and is_instance_valid(scr):
		if scr.ready_for_input:
			break
		await get_tree().process_frame
		t += get_process_delta_time()


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action; down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action; up.pressed = false
	Input.parse_input_event(up)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SHOT_SAVED ", name, " err=", err)
