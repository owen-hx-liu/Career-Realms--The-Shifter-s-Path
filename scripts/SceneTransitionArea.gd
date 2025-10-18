extends Area2D



@export var target_scene_path: String
@export var spawn_position: Vector2

func _on_body_entered(body):
	if body.name == "player":
		print("Transition triggered to:", target_scene_path)
		global.next_scene_path = target_scene_path
		global.next_player_x = spawn_position.x
		global.next_player_y = spawn_position.y

		var transition = preload("res://scenes/LevelTransition.tscn").instantiate()
		transition.target_scene_path = target_scene_path
		transition.player_spawn_position = spawn_position
		get_tree().get_root().add_child(transition)



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_exited(body: Node2D) -> void:
	pass # Replace with function body.
