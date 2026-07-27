extends Area2D

var speed: float = 150.0
var direction: Vector2 = Vector2.ZERO

@export var sprites: Array[Texture2D] = []

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("debris")
	scale = Vector2(0.6, 0.6)  # sized for the 96px asteroid sprite
	if sprites.size() > 0:
		sprite.texture = sprites[randi() % sprites.size()]
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta):
	position += direction * speed * delta
	rotation += 1.0 * delta  # slowly spin
	
	# Destroy if too far from center
	if position.length() > 600:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("mirror"):
		area.queue_free()
		queue_free()

func _on_body_entered(body):
	pass
