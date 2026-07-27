extends Control

@export_group("Weather Textures")
@export var tex_sunny: Texture2D
@export var tex_blizzard: Texture2D
@export var tex_rainy: Texture2D
@export var tex_heatwave: Texture2D
@export var tex_normal: Texture2D

@onready var screen = $CameraFeed

func _ready():
	# Hide the panel immediately
	self.visible = false
	
	# Connect to global weather signal
	global.weather_changed.connect(_on_weather_changed)

func toggle():
	self.visible = !self.visible
	if self.visible:
		_update_image()

func _update_image():
	# Use the global weather_temp to find the right name
	var current_weather = ""
	for key in global.weather_types:
		if global.weather_types[key] == global.weather_temp:
			current_weather = key
			break
	
	match current_weather:
		"Sunny": screen.texture = tex_sunny
		"Blizzard": screen.texture = tex_blizzard
		"Rainy": screen.texture = tex_rainy
		"Heatwave": screen.texture = tex_heatwave
		"Normal": screen.texture = tex_normal
		
	# Force the size constant for every texture swap
	screen.custom_minimum_size = Vector2(200, 230)
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _on_weather_changed(_name):
	# If the player is currently looking at the panel, update the image live
	if self.visible:
		_update_image()
