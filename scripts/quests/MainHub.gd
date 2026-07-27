extends Node

@export var spawn_position_in_house: Vector2 = Vector2(49.26121, 135.0)
@export var spawn_position_in_house2: Vector2 = Vector2(142.5945, 153.3334)
@export var spawn_position_in_house3: Vector2 = Vector2(46.82861, 196.38)
@export var spawn_position_in_house4: Vector2 = Vector2(170.162, 196.38)
@export var spawn_position_in_house5: Vector2 = Vector2(143.0, 146)
@export var spawn_position_in_house6: Vector2 = Vector2(143.0, 146)


func _ready():
	print("[MainHub] ========== MAINHUB STARTING ==========")
	
	# CLEAR OLD PEDESTAL DATA FIRST - This fixes the yellow stars issue!
	global.clear_all_pedestal_stars()
	print("[MainHub] ✓ Cleared all old pedestal data")
	
	# Give test stars
	test_give_stars()
	
	# Set the current scene
	global.current_scene = "MainHub"
	print("Set global.current_scene to:", global.current_scene)

	# Position the player
	call_deferred("position_player")

	# One-time welcome tutorial (flag set by the intro cutscene). Consume the
	# flag so it shows only on the first arrival, not when returning from a house.
	if global.show_hub_tutorial:
		global.show_hub_tutorial = false
		call_deferred("_start_hub_tutorial")

func _start_hub_tutorial():
	var tut_script = load("res://scripts/core/HubTutorial.gd")
	if tut_script == null:
		push_warning("[MainHub] HubTutorial.gd not found; skipping tutorial")
		return
	var tut = tut_script.new()
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(tut)

# In MainHub.gd
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		_debug_complete_all_quests()

func _debug_complete_all_quests():
	# Complete only the quests that currently exist
	EndingManager.complete_quest("flood_egypt_1", "Engineering", 5)
	EndingManager.complete_quest("village_farming", "Farming", 5)
	EndingManager.complete_quest("laser_quest", "Art", 5)
	
	# Give dummy stars
	StarManager.record_quest_stars("flood_egpyt_1", "Engineering", 5, 5)
	StarManager.record_quest_stars("village_farming", "Farming", 5, 5)
	StarManager.record_quest_stars("laser_quest", "Art", 5, 5)
	
	# Mark incomplete quests as done (for testing)
	for domain in EndingManager.QUEST_DEFINITIONS.keys():
		for quest in EndingManager.QUEST_DEFINITIONS[domain]:
			if not EndingManager.is_quest_completed(quest.id, domain):
				EndingManager.complete_quest(quest.id, domain, 3)  # 3 stars each
				StarManager.record_quest_stars(quest.id, domain, 3, 5)
	
	print("DEBUG: All quests marked complete")
	get_tree().reload_current_scene()  # Reload to activate portal
func test_give_stars():
	#print("[MainHub] ========== GIVING TEST STARS ==========")
	
	# Give 5 Engineering stars
	#StarManager.record_quest_stars("test_engineering_1", "Engineering", 5, 5)
	#print("[MainHub] Gave Engineering stars")
	
	# Give 5 Farming stars
	#StarManager.record_quest_stars("test_farming_1", "Farming", 5, 5)
	#print("[MainHub] Gave Farming stars")
	
	# Check star count
	#print("[MainHub] Total stars: ", StarManager.get_total_stars())
	#print("[MainHub] Engineering stars: ", StarManager.get_domain_stars("Engineering"))
	#print("[MainHub] Farming stars: ", StarManager.get_domain_stars("Farming"))
	
	# Force update inventory
	if StarInventoryManager:
		StarInventoryManager.update_all_domain_stars()
		print("[MainHub] Forced inventory update")
	
	print("[MainHub] ======================================")

func position_player():
	var player = get_tree().current_scene.get_node_or_null("player")
	if player and global.player_spawn_position != Vector2(0, 0):
		player.global_position = global.player_spawn_position
		print("Player positioned at:", global.player_spawn_position)
		global.player_spawn_position = Vector2(0, 0)

func _process(delta):
	change_scene()

func _on_house_transition_body_entered(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene = true
		global.player_spawn_position = spawn_position_in_house

func _on_house_transition_body_exited(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene = false

func _on_house_transition_body_entered2(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene2 = true
		global.player_spawn_position = spawn_position_in_house2

func _on_house_transition_body_exited2(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene2 = false

func _on_house_transition_body_entered3(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene3 = true
		global.player_spawn_position = spawn_position_in_house3

func _on_house_transition_body_exited3(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene3 = false

func _on_house_transition_body_entered4(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene4 = true
		global.player_spawn_position = spawn_position_in_house4

func _on_house_transition_body_exited4(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene4 = false

func _on_house_transition_body_entered5(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene5 = true
		global.player_spawn_position = spawn_position_in_house5

func _on_house_transition_body_exited5(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene5 = false

func _on_house_transition_body_entered6(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene6 = true
		global.player_spawn_position = spawn_position_in_house6

func _on_house_transition_body_exited6(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene6 = false

func change_scene():
	if global.transition_scene == true:
		if global.current_scene == "MainHub":
			get_tree().change_scene_to_file("res://scenes/maps/EngineeringHouse.tscn")
			global.finish_changescenes()
	if global.transition_scene2 == true:
		if global.current_scene == "MainHub":
			get_tree().change_scene_to_file("res://scenes/maps/FarmingHouse.tscn")
			global.finish_changescenes()
	if global.transition_scene3 == true:
		if global.current_scene == "MainHub":
			get_tree().change_scene_to_file("res://scenes/maps/StarHouse.tscn")
			global.finish_changescenes()
	if global.transition_scene4 == true:
		if global.current_scene == "MainHub":
			get_tree().change_scene_to_file("res://scenes/maps/ArtHouse.tscn")
			global.finish_changescenes()
	if global.transition_scene5 == true:
		if global.current_scene == "MainHub":
			get_tree().change_scene_to_file("res://scenes/maps/MedicineHouse.tscn")
			global.finish_changescenes()
	if global.transition_scene6 == true:
		if global.current_scene == "MainHub":
			get_tree().change_scene_to_file("res://scenes/maps/LeadershipHouse.tscn")
			global.finish_changescenes()
