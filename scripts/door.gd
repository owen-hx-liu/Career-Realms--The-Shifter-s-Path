extends Area2D

@export var target_scene: String = ""
@export var spawn_id: String = "Default"

func _on_body_entered(body):
	if body.is_in_group("player"):
		Global.spawn_point = spawn_id
		SceneManager.change_scene(target_scene)
