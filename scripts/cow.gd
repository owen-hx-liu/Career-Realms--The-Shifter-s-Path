extends AnimatedSprite2D

@onready var animatedsprite = $"."

# Called when the node enters the scene tree for the first time.
func _ready() :
	animatedsprite.play("idle")# Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
