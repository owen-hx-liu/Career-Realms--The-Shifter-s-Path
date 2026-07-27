extends Camera2D

@export var pan_speed: float = 500.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.3
@export var max_zoom: float = 3.0

func _ready():
	make_current()  # Make sure this camera is active
	zoom = Vector2(0.8, 0.8)
	position = Vector2(0, 0)
	print("Camera ready! Position: ", position, " Zoom: ", zoom)

func _process(delta):
	# Pan with arrow keys
	var movement = Vector2.ZERO

	var move_right = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	var move_left = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	var move_down = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)
	var move_up = Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)

	if move_right:
		movement.x += 1
	if move_left:
		movement.x -= 1
	if move_down:
		movement.y += 1
	if move_up:
		movement.y -= 1
	
	if movement != Vector2.ZERO:
		position += movement.normalized() * pan_speed * delta
	
	# Zoom with Z and X keys
	if Input.is_key_pressed(KEY_Z):
		zoom += Vector2.ONE * zoom_speed * 5 * delta
		zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	
	if Input.is_key_pressed(KEY_X):
		zoom -= Vector2.ONE * zoom_speed * 5 * delta
		zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
