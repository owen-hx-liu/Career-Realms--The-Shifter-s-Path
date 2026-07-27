extends CanvasLayer

@onready var main_text := $Control/NinePatchRect/RichTextLabel
@onready var continue_prompt := $Control/NinePatchRect/RichTextLabel2

var steps := [
	"Welcome, apprentice. Your healing journey begins now...",
	"Six villagers are sick — each needs a special potion.",
	"Explore the world to collect herbs, roots, and crystals.",
	"Return to the healer’s hut to craft potions.",
	"Check the recipe board behind the crafting table for help.",
	"Press [T] to talk, [E] to collect, and [I] to open your inventory.",
	"Press [R] to open the crafting and recipe menu at the back of the healer’s hut.",
	"Press [G] to give a potion to a villager.",
	"You only get one chance to heal each villager — choose carefully.",
	"The village’s fate is in your hands. Good luck, apprentice.",
	"Press [Q] if you want to see this again"
]

var current_step := 0
var finished := false

func _ready():
	add_to_group("narrator")
	if not global.has_narrator_been_shown():
		self.visible = true
		set_process_input(true)
		show_step()
	else:
		self.visible = false
		set_process_input(true)

func _input(event):
	if event.is_action_pressed("ui_accept") and self.visible:
		current_step += 1
		if current_step < steps.size():
			show_step()
		else:
			hide_narrator()
			global.mark_narrator_shown()
			finished = true

	elif event.is_action_pressed("reopen_narrator") and finished:
		current_step = 0
		self.visible = true
		set_process_input(true)
		show_step()

func show_step():
	main_text.text = steps[current_step]
	continue_prompt.text = "[Press Space to continue]"

func hide_narrator():
	self.visible = false
	set_process_input(true)
