extends Node
# Offline screenshots + smoke test for the pixel-art ending cutscene.
# Seeds a representative run IN MEMORY ONLY (never calls save_*), instances
# EndingCutscene.tscn, advances through all three slides and saves a PNG of each.
# Run windowed:  Godot --path . res://tools/ending_shot.tscn

const ENDING := preload("res://scenes/ending/EndingCutscene.tscn")

# stars per quest, per domain (sums to a strong "excellent"-tier run = 66/75)
const SEED := {
	"Engineering": [5, 4, 5],
	"Farming":     [4, 5, 4],
	"Leadership":  [5, 5, 4],
	"Medicine":    [4, 4, 5],
	"Art":         [5, 4, 3],
}

var cut
var out_dir: String


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	out_dir = OS.get_user_data_dir() + "/ending_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	_seed_in_memory()

	cut = ENDING.instantiate()
	add_child(cut)
	print("ENDING_TIER=", EndingManager.get_ending_info().get("tier"),
		" STARS=", StarManager.get_total_stars())

	# Slide enum on the cutscene: FADE_IN=0 RENAISSANCE=1 LEGACY=2 FAREWELL=3
	await _wait_slide(1, 16.0)
	await _shot("01_renaissance")

	_press_accept()
	await _wait_slide(2, 16.0)
	await _shot("02_legacy")

	_press_accept()
	await _wait_slide(3, 16.0)
	await _shot("03_farewell")

	print("SHOT_DONE")
	get_tree().quit()


func _seed_in_memory() -> void:
	# Populate the autoload dictionaries directly so get_ending_*() return rich
	# data — without writing to the player's real save files.
	for domain in SEED.keys():
		var defs = EndingManager.QUEST_DEFINITIONS.get(domain, [])
		if not StarManager.quest_stars.has(domain):
			StarManager.quest_stars[domain] = {}
		if not EndingManager.completed_quests.has(domain):
			EndingManager.completed_quests[domain] = {}
		for i in defs.size():
			var qid = defs[i].id
			var stars = SEED[domain][i] if i < SEED[domain].size() else 4
			StarManager.quest_stars[domain][qid] = stars
			StarManager.quest_metadata[qid] = {"domain": domain, "max_stars": 5, "completed": true}
			EndingManager.completed_quests[domain][qid] = {
				"completed": true, "stars": stars, "completion_date": 0,
			}


func _wait_slide(expected: int, timeout: float) -> void:
	# Wait until the cutscene has reached `expected` slide AND its prompt is up.
	var t := 0.0
	while t < timeout and is_instance_valid(cut):
		if cut.slide == expected and cut.prompt_ready and not cut.busy:
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
