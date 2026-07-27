extends CharacterBody2D
var speed = 45
var player_chase = false
var player = null

func _ready():
	global_position = Vector2(20, 97)  # Change spawn position as needed

func _physics_process(delta: float) -> void:
	if player_chase and player:
		var distance_to_player = position.distance_to(player.position)
		
		if distance_to_player < 30:
			$AnimatedSprite2D.play("idle_right")
			velocity = Vector2.ZERO
		else:
			var direction = (player.position - position).normalized()
			velocity = direction * speed
			$AnimatedSprite2D.play("walk_right")
			$AnimatedSprite2D.scale.x = -1 if direction.x < 0 else 1
	else:
		$AnimatedSprite2D.play("idle_right")
		velocity = Vector2.ZERO
	
	move_and_slide()
		
func _on_detection_area_body_entered(body: Node2D) -> void:
	player = body
	player_chase = true
	
func _on_detection_area_body_exited(body: Node2D) -> void:
	player = null
	player_chase = false
