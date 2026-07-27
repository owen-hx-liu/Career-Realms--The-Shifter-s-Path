extends Area2D

var player_in_zone = false

func _ready():
	print("ControlCenterZone ready at position: ", global_position)
	var button = get_node_or_null("../ControlCenterUI/StartQuestButton")
	if button:
		button.visible = false

func _process(_delta):
	var overlapping = get_overlapping_bodies()
	var should_show = false
	
	for body in overlapping:
		if body.name.to_lower() == "player":
			should_show = true
			break
	
	var button = get_node_or_null("../ControlCenterUI/StartQuestButton")
	
	if should_show and not player_in_zone:
		player_in_zone = true
		print("=== PLAYER ENTERED ZONE ===")
		if button:
			# Get camera and viewport info
			var camera = get_viewport().get_camera_2d()
			var viewport_size = get_viewport().get_visible_rect().size
			
			# Calculate where the zone appears on screen
			var zone_offset = global_position - camera.global_position
			var screen_center = viewport_size / 2
			var button_screen_pos = screen_center + zone_offset
			
			# Position button below the zone (add offset)
			button.position = button_screen_pos + Vector2(-button.size.x / 2, 80)
			
			button.visible = true
			print("✓ Button positioned at: ", button.position)
			print("  Viewport size: ", viewport_size)
			print("  Screen center: ", screen_center)
	elif not should_show and player_in_zone:
		player_in_zone = false
		if button:
			button.visible = false

func _on_start_quest_button_pressed():
	print("=== BUTTON WAS CLICKED ===")
	print("Current scene: ", get_tree().current_scene.name)
	print("Attempting to load: res://map_view.tscn")
	
	var error = get_tree().change_scene_to_file("res://scenes/map_view.tscn")
	
	if error == OK:
		print("✓ Scene change successful!")
	else:
		print("✗ ERROR: Scene change failed with error code: ", error)
		print("  Make sure map_view.tscn exists in res://")
