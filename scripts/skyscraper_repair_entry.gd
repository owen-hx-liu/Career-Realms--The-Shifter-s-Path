extends Area2D

@export_file("*.tscn") var target_scene: String = "res://scenes/control_room_repair_city.tscn"

var _is_transitioning: bool = false

# Connects the Area2D enter signal when the node is ready.
func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

# Instantly moves the player to the control room when they touch this trigger.
func _on_body_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if not _is_player_body(body):
		return

	_is_transitioning = true
	global.current_scene = "World"
	global.next_player_x = -1
	global.next_player_y = -1
	get_tree().call_deferred("change_scene_to_file", target_scene)

# Returns true when the colliding body is the player character.
func _is_player_body(body: Node) -> bool:
	if body == null:
		return false
	return body.is_in_group("player") or String(body.name).to_lower() == "player"
