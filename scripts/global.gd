extends Node

var current_scene = "World"





var next_scene_path = ""
var next_player_x = 20
var next_player_y = 20





func update_camera():
	var root = get_tree().get_current_scene()
	var player = root.get_node("player")  # Make sure your player node is named "Player"
	print("Current scene is:", current_scene)

	if current_scene == "World":
		if player.has_node("worldcamera"):
			player.get_node("worldcamera").enabled = true
		if player.has_node("housecamera"):
			player.get_node("housecamera").enabled = false
	elif current_scene.begins_with("house"):
		if player.has_node("worldcamera"):
			player.get_node("worldcamera").enabled = false
		if player.has_node("housecamera"):
			player.get_node("housecamera").enabled = true
		
