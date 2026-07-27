extends Control

@onready var start_button = $ContentPanel/MarginContainer/VBoxContainer/StartButton

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	
	# Optional: Add a fade-in animation
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)

func _on_start_pressed():
	print("Button pressed! Loading game...")
	print("Checking if scene exists...")
	
	var scene_path = "res://scenes/immune_card_quest.tscn"
	if FileAccess.file_exists(scene_path):
		print("✓ Scene found at: ", scene_path)
	else:
		print("❌ Scene NOT found at: ", scene_path)
	
	get_tree().change_scene_to_file(scene_path)
