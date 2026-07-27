extends Area2D

var player_in_range = false
@export var craft_ui_path: NodePath  # Drag your CraftableUI node into this in the editor

func _ready():
	var ui = get_node(craft_ui_path)
	if ui:
		ui.visible = false

func _process(delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("craft"):  # "craft" should be mapped to R
		var ui = get_node(craft_ui_path)
		if ui:
			ui.visible = not ui.visible
			if ui.visible:
				ui.grab_focus()  # Optional: focus the UI for keyboard/gamepad input


	  # Hide UI when player leaves

func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		player_in_range = true # Replace with function body.


func _on_body_exited(body: Node2D) -> void:
	if body.name == "player":
		player_in_range = false
		 # Replace with function body.
