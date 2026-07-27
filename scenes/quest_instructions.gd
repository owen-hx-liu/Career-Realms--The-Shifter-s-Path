extends Control

func _ready():
	get_tree().paused = true

func _on_start_button_pressed():
	print("Starting mission!")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://map_view.tscn")
