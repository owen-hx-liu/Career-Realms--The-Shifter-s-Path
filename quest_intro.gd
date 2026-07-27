extends Node2D

@onready var main_text = $NinePatchRect/MainText
@onready var continue_prompt = $NinePatchRect/ContinuePrompt
@onready var intro_box = $NinePatchRect

var steps := [
	"WELCOME, MASTER ENGINEER!",
	"Your mission is to navigate the laser through 5 challenging rooms.",
	"CONTROLS:\nPress [M] to place a Mirror.\nPress [N] to place a Color Filter.",
	"COLOR MATCHING:\nPress [C] on a filter to change its color.",
	"GOAL:\nYou must match the laser's color with the target's color.",
	"PROGRESSION:\nHit ALL targets in a room to unlock the path to the next room.",
	"EFFICIENCY:\nComplete all 5 rooms using as few objects as possible to earn 5 stars!",
	"Press [SPACE] to start the first room. Good luck!"
]

var current_step := 0

func _ready():
	self.visible = true
	show_step()

func _process(_delta):
	# Keeps the menu stuck to the camera center while game is running
	var canvas_transform = get_canvas_transform()
	var screen_center = -canvas_transform.origin / canvas_transform.get_scale() + (get_viewport_rect().size / 2 / canvas_transform.get_scale())
	self.global_position = screen_center
	
	# Keep the box centered
	intro_box.position = -intro_box.size / 2

func _input(event):
	if self.visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		
		current_step += 1
		if current_step < steps.size():
			show_step()
		else:
			_close_intro()

func show_step():
	main_text.text = steps[current_step]
	continue_prompt.text = "[Press Space to continue]"

func _close_intro():
	self.visible = false
	queue_free() # Removes the intro once finished
