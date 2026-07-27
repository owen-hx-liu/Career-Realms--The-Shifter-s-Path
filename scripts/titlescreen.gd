extends Control

@onready var title_anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var play_button: Button = $control   # make sure this matches your node name
@onready var settings_button: Button = $setting   # new button node

func _ready():
	# Start the title animation
	title_anim.animation = "loop"
	title_anim.play()

	# Connect the button signals
	play_button.connect("pressed", Callable(self, "_on_play_pressed"))
	settings_button.connect("pressed", Callable(self, "_on_settings_pressed"))

func _on_play_pressed():
	# Change to your next scene
	get_tree().change_scene_to_file("res://scenes/control.tscn")

func _on_settings_pressed():
	# Change to your settings scene
	get_tree().change_scene_to_file("res://scenes/setting.tscn")
