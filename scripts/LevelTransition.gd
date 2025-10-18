extends Node2D

@export var target_scene_path: String
@export var player_spawn_position: Vector2

func _ready():
	global.current_scene = target_scene_path.get_file().get_basename()
	global.next_player_x = player_spawn_position.x
	global.next_player_y = player_spawn_position.y
	get_tree().change_scene_to_file(target_scene_path)


# Called when the node enters the scene tree for the first time.
# Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
