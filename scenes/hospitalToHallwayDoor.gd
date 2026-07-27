extends Area2D

@export var next_scene: String = "res://scenes/hospital_hallway.tscn"

func _on_body_entered(body):
	if body.name == "player":
		get_tree().change_scene_to_file(next_scene)
