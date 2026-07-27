extends Node2D

@onready var map_view_camera: Camera2D = $Camera2D

func _ready():
	# Quest-local camera setup only. Do not touch global/root cameras.
	if map_view_camera:
		map_view_camera.enabled = true
		map_view_camera.make_current()
		map_view_camera.limit_left = -10000
		map_view_camera.limit_top = -10000
		map_view_camera.limit_right = 10000
		map_view_camera.limit_bottom = 10000
		map_view_camera.position_smoothing_enabled = false
		print("[MapView] Local quest camera is active.")
	else:
		push_warning("[MapView] Camera2D node not found.")

func _process(_delta):
	# Safety check: keep this scene's camera current while in map view.
	if map_view_camera and not map_view_camera.is_current():
		map_view_camera.make_current()

func set_camera_target(_new_target):
	# Kept for compatibility with any older calls.
	# Map view now uses manual pan/zoom and does not follow a target.
	pass
