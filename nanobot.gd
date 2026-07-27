extends CharacterBody2D

@export var speed: float = 100.0
@export var drift_speed: float = 30.0

var is_active: bool = false
var current_direction: Vector2 = Vector2.RIGHT
var is_hooked: bool = false
var is_repairing: bool = false
var repair_time: float = 15.0
var repair_progress: float = 0.0
var current_repair_site = null

@onready var anim = $AnimatedSprite2D
@onready var progress_bar = $ProgressBar

func _ready():
	progress_bar.visible = false

func _physics_process(delta):
	if is_hooked:
		velocity = Vector2.ZERO
		anim.play("idle")
		
		if is_repairing:
			repair_progress += delta
			progress_bar.value = repair_progress
			if repair_progress >= repair_time:
				finish_repair()
		return
		
	if is_active:
		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if direction != Vector2.ZERO:
			velocity = direction * speed
			anim.play("move")
		else:
			velocity = current_direction * drift_speed
			anim.play("idle")
	else:
		velocity = current_direction * drift_speed
		anim.play("idle")
		
	move_and_slide()

func hook():
	print("Hooked!")
	is_hooked = true
	is_repairing = true
	repair_progress = 0.0
	velocity = Vector2.ZERO
	progress_bar.visible = true
	progress_bar.value = 0

func finish_repair():
	is_repairing = false
	is_hooked = false
	repair_progress = 0.0
	progress_bar.visible = false
	if current_repair_site:
		current_repair_site.on_repair_complete()
	get_tree().get_first_node_in_group("level_manager").on_site_repaired()
