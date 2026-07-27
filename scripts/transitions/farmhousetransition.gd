extends Area2D

# Set these in the Inspector for each Area2D
@export_file("*.tscn") var target_scene: String = "res://scenes/maps/FarmingHouse.tscn"
@export var player_spawn_position: Vector2 = Vector2(746, 146)

var triggered := false


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if triggered:
		return
	
	# Detect player safely without relying on node name
	if not body.has_method("player"):
		return
	
	triggered = true
	transition_to_scene()


func transition_to_scene():
	if target_scene == "":
		push_error("Target scene not set!")
		return
	
	var next_scene = load(target_scene).instantiate()
	
	# Swap scenes safely
	var tree = get_tree()
	var old_scene = tree.current_scene
	
	tree.root.add_child(next_scene)
	tree.current_scene = next_scene
	
	if old_scene:
		old_scene.queue_free()
	
	# Wait one frame so nodes initialize
	await tree.process_frame
	
	# Place player
	var new_player = next_scene.get_node_or_null("player")
	if new_player and player_spawn_position != Vector2.ZERO:
		new_player.global_position = player_spawn_position
