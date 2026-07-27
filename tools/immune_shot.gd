extends Node
# Offline screenshots of the IMMUNE DEFENSE card quest: initial draft board,
# a full 5-cell team, and the results screen. Also doubles as a smoke test —
# it drives the quest through a full round and prints any runtime errors.
# Run windowed:  Godot --path . res://tools/immune_shot.tscn

const QUEST := preload("res://scenes/immune_card_quest.tscn")

var quest
var out_dir: String


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	out_dir = OS.get_user_data_dir() + "/immune_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("SHOT_DIR=", out_dir)

	quest = QUEST.instantiate()
	add_child(quest)
	for i in range(12):
		await get_tree().process_frame
	await _shot("01_initial")

	# Draft the first five immune cells (deterministic for the screenshot).
	for i in range(5):
		if i < quest.deck_card_nodes.size():
			quest._on_immune_card_clicked(quest.deck_card_nodes[i])
		for j in range(4):
			await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	await _shot("02_drafted")

	# Deploy → results screen.
	quest._on_start_battle()
	await get_tree().create_timer(0.7).timeout
	await _shot("03_results")

	print("SHOT_DONE")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png(out_dir + "/" + name + ".png")
	print("SHOT_SAVED ", name, " err=", err)
