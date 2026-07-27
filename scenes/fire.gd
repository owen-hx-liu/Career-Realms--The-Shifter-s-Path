extends Node2D
@export var spread_time: float = 15.0
@export var spread_chance: float = 0.7
@export var tile_size: int = 32
@export var max_spread_count: int = 3
@export var player_spawn_position: Vector2 = Vector2(310, 101)
var spread_count = 0

func _ready():
	print("Fire spawned at: ", global_position)
	$AnimatedSprite2D.play("burn")
	start_spread_timer()

func start_spread_timer():
	while spread_count < max_spread_count:
		await get_tree().create_timer(spread_time).timeout
		try_spread()

func try_spread():
	if spread_count >= max_spread_count:
		return
	
	if randf() > spread_chance:
		return
	
	spread_count += 1
	
	var directions = [
		Vector2(tile_size, 0),
		Vector2(-tile_size, 0),
		Vector2(0, tile_size),
		Vector2(0, -tile_size)
	]
	
	var random_direction = directions[randi() % directions.size()]
	
	var fire_scene = load("res://scenes/fire.tscn")
	var new_fire = fire_scene.instantiate()
	new_fire.global_position = global_position + random_direction
	
	get_parent().add_child(new_fire)

func _on_area_2d_body_entered(body):
	# Player touches fire - teleport back
	if body.is_in_group("player") or body.name.to_lower() == "player":
		body.global_position = player_spawn_position
	
	# NPC touches fire - delete and update tracker
	elif "npc" in body.name.to_lower() or "lumberjack" in body.name.to_lower():
		if is_instance_valid(body):
			body.queue_free()
		
		# Update tracker in current quest scene
		var scene_root = get_tree().current_scene
		var tracker = scene_root.get_node_or_null("NPCTracker") if scene_root else null
		if tracker:
			tracker.npc_died()
