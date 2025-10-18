extends CharacterBody2D

const SPEED = 100
var current_dir = "none"

func player():
	pass
func _physics_process(delta):
	player_movement(delta)
	print(velocity)
	move_and_slide()
	current_camera()
func _ready():
	get_tree().get_root().add_child(self)
	set_owner(get_tree().get_root()) # use built-in velocity from CharacterBody2D

func player_movement(delta):
	if Input.is_action_pressed("ui_right"):
		current_dir = "right"
		play_anim(1)
		velocity.x = SPEED
		velocity.y = 0
	elif Input.is_action_pressed("ui_left"):
		current_dir = "left"
		play_anim(1)
		velocity.x = -SPEED
		velocity.y = 0
	elif Input.is_action_pressed("ui_down"):
		current_dir = "down"
		play_anim(1)
		velocity.x = 0
		velocity.y = SPEED
	elif Input.is_action_pressed("ui_up"):
		current_dir = "up"
		play_anim(1)
		velocity.x = 0
		velocity.y = -SPEED
	else:
		play_anim(0)
		velocity.x = 0
		velocity.y = 0

func play_anim(movement):
	var dir = current_dir
	var anim = $AnimatedSprite2D

	if dir == "right":
		anim.flip_h = false
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			anim.play("side_idle")

	elif dir == "left":
		anim.flip_h = true
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			anim.play("side_idle")

	elif dir == "down":
		anim.flip_h = false
		if movement == 1:
			anim.play("front_walk")
		elif movement == 0:
			anim.play("front_idle")

	elif dir == "up":
		anim.flip_h = false
		if movement == 1:
			anim.play("back_walk")
		elif movement == 0:
			anim.play("back_idle")
	
func current_camera():
	if global.current_scene == "World":
		$worldcamera.enabled = true
		$housecamera.enabled = false
		print("world cam")
		
		
	
		
	elif global.current_scene.begins_with("house"):
		
		$worldcamera.enabled = false
		$housecamera.enabled = true
		print("house cam")
		
			
		
			
		
