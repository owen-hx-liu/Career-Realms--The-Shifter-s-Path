extends Node

@export var spawn_position_in_scr2: Vector2 = Vector2(22.044445, 34.72562)
@export var spawn_position_in_scr4: Vector2 = Vector2(312.9998, 43.73738)

var transition_cooldown: float = 1.0  # 1 second cooldown

func _ready():
	global.current_scene = "Starcontainerroom3"
	print("Set global.current_scene to:", global.current_scene)
	call_deferred("position_player")

func position_player():
	var player = get_tree().current_scene.get_node_or_null("player")
	if player and global.player_spawn_position != Vector2(0, 0):
		player.global_position = global.player_spawn_position
		print("Player positioned at:", global.player_spawn_position)
		global.player_spawn_position = Vector2(0, 0)

func _process(delta):
	# Update global cooldown timer
	if global.scene_transition_cooldown > 0:
		global.scene_transition_cooldown -= delta
	
	change_scene()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name.to_lower() == "player" or body.has_method("player"):
		if global.scene_transition_cooldown <= 0:  # Check global cooldown
			print("Player detected at exit - setting transition to true")
			global.transition_scene = true
			global.player_spawn_position = spawn_position_in_scr2
		else:
			print("Transition on cooldown - ignoring")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene = false

func _on_area_2d_body_entered2(body: Node2D) -> void:
	if body.name.to_lower() == "player" or body.has_method("player"):
		if global.scene_transition_cooldown <= 0:  # Check global cooldown
			print("Player detected at exit - setting transition to true")
			global.transition_scene2 = true
			global.player_spawn_position = spawn_position_in_scr4
		else:
			print("Transition on cooldown - ignoring")

func _on_area_2d_body_exited2(body: Node2D) -> void:
	if body.name.to_lower() == "player" or body.has_method("player"):
		global.transition_scene2 = false

func change_scene():
	if global.transition_scene == true and global.scene_transition_cooldown <= 0:
		print("Changing back to Starcontainerroom...")
		global.scene_transition_cooldown = transition_cooldown  # Start global cooldown
		get_tree().change_scene_to_file("res://scenes/maps/starcontainerroom2.tscn")
		global.finish_changescenes()
	if global.transition_scene2 == true and global.scene_transition_cooldown <= 0:
		print("Changing back to Starcontainerroom...")
		global.scene_transition_cooldown = transition_cooldown  # Start global cooldown
		get_tree().change_scene_to_file("res://scenes/maps/starcontainerroom4.tscn")
		global.finish_changescenes()
