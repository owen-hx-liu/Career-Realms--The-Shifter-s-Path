extends Area2D

var player_in_range = false
@export var recipe_ui_path: NodePath  # Assign your CraftableUI node in the editor

@onready var ui = get_node(recipe_ui_path)

func _ready():
	if ui:
		ui.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		player_in_range = true
		if ui:
			ui.visible = true
			ui.grab_focus()  # Optional

func _on_body_exited(body: Node2D) -> void:
	if body.name == "player":
		player_in_range = false
		if ui:
			ui.visible = false
