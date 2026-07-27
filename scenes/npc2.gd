extends CharacterBody2D
@export var speed: float = 45.0
@export var stop_distance: float = 25.0

var player_chase := false
var player: Node2D = null

func _ready():
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if player_chase and is_instance_valid(player):
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player < stop_distance:
			$AnimatedSprite2D.play("idle_right")
			velocity = Vector2.ZERO
		else:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
			$AnimatedSprite2D.play("walk_right")
			$AnimatedSprite2D.scale.x = -1 if direction.x < 0 else 1
	else:
		# Not chasing - idle and reset velocity
		$AnimatedSprite2D.play("idle_right")
		velocity = Vector2.ZERO  # Completely stop instead of lerp

	move_and_slide()
		
func _on_detection_area_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.name.to_lower() == "player"):
		return
	player = body
	player_chase = true
	
func _on_detection_area_body_exited(body: Node2D) -> void:
	if body != player:
		return
	player = null
	player_chase = false
	velocity = Vector2.ZERO  # Stop immediately when player leaves
