extends Node2D

@onready var line = $Line2D

func _ready():
	visible = false
	line.default_color = Color(1.0, 0.5, 0.0, 1.0)
	line.width = 20.0  # much thicker

func fire(angle: float):
	visible = true
	var end_point = Vector2(cos(angle), sin(angle)) * 500
	line.points = [Vector2.ZERO, end_point]
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
