extends Node

# Set this to where the player should spawn in MainHub (in front of the house door)
@export var spawn_position_in_mainhub: Vector2 = Vector2(104.3333, -429.9992)

func _ready():
	# Set the current scene when the house loads
	global.current_scene = "FarmingHouse"
	print("Set global.current_scene to:", global.current_scene)
	
	# Position the player at the saved spawn position
	call_deferred("position_player")

func position_player():
	var player = get_tree().current_scene.get_node_or_null("player")
	if player and global.player_spawn_position != Vector2(0, 0):
		player.global_position = global.player_spawn_position
		print("Player positioned at:", global.player_spawn_position)
		# Reset spawn position
		global.player_spawn_position = Vector2(0, 0)

func _process(delta):
	change_scene()

func _on_area_2d_body_entered(body: Node2D) -> void:
	print("Body entered exit area:", body.name, "Type:", body.get_class())
	# Check if it's actually the player (case-insensitive)
	if body.name.to_lower() == "player" or body.has_method("player"):
		print("Player detected at exit - setting transition to true")
		global.transition_scene = true
		# Set where the player should spawn in MainHub
		global.player_spawn_position = spawn_position_in_mainhub

func _on_area_2d_body_exited(body: Node2D) -> void:
	print("Body exited exit area:", body.name)
	if body.name.to_lower() == "player" or body.has_method("player"):
		print("Player left exit area - setting transition to false")
		global.transition_scene = false

func change_scene():
	if global.transition_scene == true:
		print("Transition active, current scene:", global.current_scene)
		if global.current_scene == "FarmingHouse":
			print("Changing back to MainHub...")
			get_tree().change_scene_to_file("res://scenes/maps/MainHub.tscn")
			global.finish_changescenes()
