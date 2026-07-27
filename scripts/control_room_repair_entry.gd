extends Area2D

@export_file("*.tscn") var target_scene: String = "res://scenes/repair_scene.tscn"
@export var interact_action: StringName = &"collect"
@export var prompt_label_path: NodePath = NodePath("PromptLabel")
@export var interaction_enabled: bool = true

var _player_in_range: bool = false
var _is_transitioning: bool = false

@onready var _prompt_label: Label = get_node_or_null(prompt_label_path) as Label

# Connects trigger signals and hides the prompt at startup.
func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_update_prompt_visibility()

# Marks the player as in range and shows the interaction prompt.
func _on_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	_player_in_range = true
	_update_prompt_visibility()

# Clears in-range state and hides the interaction prompt.
func _on_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	_player_in_range = false
	_update_prompt_visibility()

# Handles pressing E/collect while the player is inside the trigger.
func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if not _player_in_range:
		return
	if not interaction_enabled:
		return
	if not event.is_action_pressed(interact_action):
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

# Enables or disables E/collect interaction and prompt visibility.
func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	_update_prompt_visibility()

# Refreshes prompt visibility based on range and interaction lock state.
func _update_prompt_visibility() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _player_in_range and interaction_enabled
