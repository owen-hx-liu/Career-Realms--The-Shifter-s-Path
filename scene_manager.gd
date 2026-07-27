extends CanvasLayer

var is_transitioning = false

@onready var overlay = $ColorRect
@onready var anim = $AnimationPlayer

func _ready():
	# The fade ColorRect is a full-screen autoload overlay that stays alive (and
	# `visible`) in every scene, only transparent via modulate. Left at its
	# default mouse_filter=STOP it silently swallows every world click that isn't
	# caught by a higher CanvasLayer (e.g. the laser quest's grid). It's purely
	# cosmetic, so it must not intercept the mouse while idle.
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(path: String):
	if is_transitioning:
		return
	is_transitioning = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP   # block stray clicks mid-fade
	anim.play("fade_out")
	await anim.animation_finished
	get_tree().change_scene_to_file(path)
	anim.play("fade_in")
	await anim.animation_finished
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
