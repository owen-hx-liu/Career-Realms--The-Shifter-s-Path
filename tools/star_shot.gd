extends Node
# Offline screenshots for the STAR CODEX remaster:
#   01_menu        - the press-R codex menu (seeded with sample stars)
#   02_place_pop   - a star mid pop-in (glow flash + shockwave ring)
#   03_place_burst - the sparkle burst as stars settle
#   04_settled     - all stars placed + a "PRESS C" ghost-preview hint
# Run windowed:  Godot --path . res://tools/star_shot.tscn

const PED := preload("res://scripts/enviorment/StarPedastal.gd")
const UI  := preload("res://scripts/core/StarStatsUI.gd")

var out_dir: String


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	out_dir = OS.get_user_data_dir() + "/star_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	_seed_stars()
	await _menu_phase()
	await _pedestal_phase()
	await _room_phase()

	print("SHOT_DONE")
	get_tree().quit()


func _seed_stars() -> void:
	StarManager.quest_stars.clear()
	StarManager.quest_metadata.clear()
	StarManager.record_quest_stars("med_q1", "Medicine", 4, 5)
	StarManager.record_quest_stars("med_q2", "Medicine", 5, 5)
	StarManager.record_quest_stars("eng_q1", "Engineering", 3, 5)
	StarManager.record_quest_stars("farm_q1", "Farming", 5, 5)
	StarManager.record_quest_stars("farm_q2", "Farming", 2, 5)
	StarManager.record_quest_stars("art_q1", "Art", 4, 5)
	StarManager.record_quest_stars("lead_q1", "Leadership", 1, 5)


# ---------------------------------------------------------------- menu
func _menu_phase() -> void:
	var bg := _bg_layer(Color(0.06, 0.09, 0.16))
	add_child(bg)

	var ui = UI.new()
	add_child(ui)
	await get_tree().process_frame
	ui.toggle_stats()
	await get_tree().create_timer(0.5).timeout
	await _shot("01_menu")

	ui.queue_free()
	bg.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- pedestals
func _pedestal_phase() -> void:
	var bg := _bg_layer(Color(0.07, 0.06, 0.13))
	add_child(bg)

	var cam := Camera2D.new()
	cam.position = Vector2(0, -6)
	cam.zoom = Vector2(5, 5)
	add_child(cam)
	cam.make_current()

	var domains := ["Medicine", "Engineering", "Farming", "Art"]
	var xs := [-90, -30, 30, 90]
	var peds := []
	for i in range(4):
		var p = PED.new()
		p.position = Vector2(xs[i], 10)
		p.domain = domains[i]
		# give it a collision shape so it's a valid Area2D (not strictly needed)
		add_child(p)
		peds.append(p)

	# let _ready + deferred load_star_state run
	for i in range(8):
		await get_tree().process_frame

	# show the ghost "PRESS C" hint on the last pedestal
	peds[3].show_placement_hint()

	# fire the placement spectacle on the first three
	for i in range(3):
		peds[i].debug_force_place(StarManager.get_domain_color(domains[i]))

	await get_tree().create_timer(0.18).timeout
	await _shot("02_place_pop")

	await get_tree().create_timer(0.32).timeout
	await _shot("03_place_burst")

	await get_tree().create_timer(0.9).timeout
	await _shot("04_settled")


# ---------------------------------------------------------------- real room
func _room_phase() -> void:
	var room = load("res://scenes/maps/starcontainerroom.tscn").instantiate()
	add_child(room)
	# drop the room's own player so it can't wander into frame
	var pl = room.get_node_or_null("player")
	if pl:
		pl.queue_free()
	for i in range(10):
		await get_tree().process_frame

	var cam := Camera2D.new()
	cam.position = Vector2(168, 120)
	cam.zoom = Vector2(3, 3)
	add_child(cam)
	cam.make_current()

	# force-place a few stars across the ring of pedestals, varied domains
	var targets := {
		"StarPedastal3": "Farming", "StarPedastal4": "Medicine",
		"StarPedastal10": "Engineering", "StarPedastal1": "Art",
		"StarPedastal13": "Leadership",
	}
	for ped_name in targets:
		var ped = room.get_node_or_null(ped_name)
		if ped:
			ped.domain = targets[ped_name]
			ped.debug_force_place(StarManager.get_domain_color(targets[ped_name]))
	# leave one empty pedestal showing the hint
	var empty = room.get_node_or_null("StarPedastal11")
	if empty:
		empty.domain = "Engineering"
		empty.show_placement_hint()

	await get_tree().create_timer(1.3).timeout
	await _shot("05_room_placed")
	room.queue_free()


# ---------------------------------------------------------------- helpers
func _bg_layer(col: Color) -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = -10
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(r)
	return cl

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SHOT_SAVED ", name, " err=", err)
