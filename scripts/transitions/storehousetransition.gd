extends Area2D

# Set these in the Inspector for each Area2D
@export_file("*.tscn") var target_scene: String = "res://scenes/maps/Storehouse.tscn"
@export var player_spawn_position: Vector2 = Vector2(127,152)

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if it's the player
	if body.name == "player":
		transition_to_scene()

func transition_to_scene():
	if target_scene == "":
		push_error("Target scene not set!")
		return
	
	# Load and change to the target scene
	var next_scene = load(target_scene).instantiate()
	
	# Find the player in the new scene and set their position
	var new_player = next_scene.get_node_or_null("player")
	if new_player and player_spawn_position != Vector2.ZERO:
		new_player.global_position = player_spawn_position
	
	# Switch scenes
	get_tree().root.add_child(next_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = next_scene
