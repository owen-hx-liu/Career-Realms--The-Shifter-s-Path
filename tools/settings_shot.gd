extends Node
# Offline screenshots of the global SETTINGS / accessibility overlay, rendered
# over a faux game backdrop so the dim + vignette + pixel panel read correctly.
# Doubles as a smoke test for scripts/core/GlobalSettingsMenu.gd.
# Run windowed:  Godot --path . res://tools/settings_shot.tscn

var out_dir: String
var gsm: Node


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	out_dir = OS.get_user_data_dir() + "/settings_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	_build_backdrop()

	gsm = get_node_or_null("/root/GlobalSettingsMenu")
	if gsm == null:
		push_error("GlobalSettingsMenu autoload not found")
		get_tree().quit()
		return

	for i in range(8):
		await get_tree().process_frame

	# open (animated) and let the pop-in settle
	gsm._set_menu_open(true)
	await get_tree().create_timer(0.6).timeout
	await _shot("01_open")

	# drive the sliders to show fills, glows, value punch + sparkle bursts
	gsm._music_slider.value = 82.0
	gsm._brightness_slider.value = 28.0
	await get_tree().process_frame
	await _shot("02_adjust")

	# let the ambient animation breathe (gear spun, sun pulsed, sparkles drifted)
	await get_tree().create_timer(1.2).timeout
	await _shot("03_ambient")

	print("SHOT_DONE")
	get_tree().quit()


func _build_backdrop() -> void:
	# a simple representative "realm" behind the overlay
	var cl := CanvasLayer.new()
	cl.layer = 0
	add_child(cl)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color("3a6b4a"))
	grad.set_color(1, Color("1d3a2a"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 64
	gt.height = 64
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	cl.add_child(tr)
	# a few blocky "props" so the dim/vignette has something to sit over
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(60):
		var p := ColorRect.new()
		var s := rng.randf_range(24, 80)
		p.size = Vector2(s, s)
		p.position = Vector2(rng.randf_range(0, 1152), rng.randf_range(0, 648))
		p.color = Color.from_hsv(rng.randf_range(0.25, 0.42), 0.4, rng.randf_range(0.3, 0.6), 1.0)
		cl.add_child(p)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SHOT_SAVED ", name, " err=", err)
