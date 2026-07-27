extends Node2D

@onready var particles = $CPUParticles2D
@onready var anim = $AnimationPlayer

func _ready():
	# Play the animation
	anim.play("expand")

	# Trigger a single particle burst
	if randf() < 0.5:
		particles.restart()
