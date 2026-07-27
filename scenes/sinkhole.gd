extends Node2D

@onready var anim = $AnimationPlayer
@onready var particles = $CPUParticles2D
@export var burst_count: int = 5
@export var burst_interval: float = 0.25
@export var player_spawn_position: Vector2 = Vector2(310, 101)

func _ready():
	burst_particles()
	anim.play("expand")

func burst_particles():
	for i in range(burst_count):
		await get_tree().create_timer(i * burst_interval).timeout
		particles.restart()

func _on_area_2d_body_entered(body):
	# Player touches sinkhole - teleport back
	if body.is_in_group("player") or body.name.to_lower() == "player":
		body.global_position = player_spawn_position
	
	# NPC touches sinkhole - delete and update tracker
	elif "npc" in body.name.to_lower() or "lumberjack" in body.name.to_lower():
		if is_instance_valid(body):
			body.queue_free()
		
		# Update tracker in current quest scene
		var scene_root = get_tree().current_scene
		var tracker = scene_root.get_node_or_null("NPCTracker") if scene_root else null
		if tracker:
			tracker.npc_died()
