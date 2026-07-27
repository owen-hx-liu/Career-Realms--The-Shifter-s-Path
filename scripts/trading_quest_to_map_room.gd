extends Area2D

@export_file("*.tscn") var target_scene: String = "res://scenes/map_room.tscn"
@export var spawn_position: Vector2 = Vector2(96, 170)

var _is_transitioning: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if not body.is_in_group("player"):
		return

	_is_transitioning = true
	global.current_scene = target_scene
	global.next_player_x = spawn_position.x
	global.next_player_y = spawn_position.y
	get_tree().call_deferred("change_scene_to_file", target_scene)
