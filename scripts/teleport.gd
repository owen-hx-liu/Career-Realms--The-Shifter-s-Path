extends Area2D

@export var teleport_target: Vector2 = Vector2(0, 0)

func _on_body_entered(body: Node2D):
	# This script is simple: If a player touches me, they move.
	# Because it's placed BEHIND the door wall, they can only touch it 
	# when the door script disables the wall!
	if body.is_in_group("player") or body.name == "Player":
		print("Teleporting to: ", teleport_target)
		body.global_position = teleport_target
