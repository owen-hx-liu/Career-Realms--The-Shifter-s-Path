extends Area2D

@export_file("*.tscn") var target_scene: String = "res://scenes/map.tscn"
@export var interact_action: StringName = &"collect"

var _player_in_range: bool = false
var _is_transitioning: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false

func _input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if not _player_in_range:
		return
	if not event.is_action_pressed(interact_action):
		return

	_is_transitioning = true
	global.current_scene = target_scene
	# Map scene has no walkable player avatar, so clear pending spawn data.
	global.next_player_x = -1
	global.next_player_y = -1
	get_tree().call_deferred("change_scene_to_file", target_scene)
