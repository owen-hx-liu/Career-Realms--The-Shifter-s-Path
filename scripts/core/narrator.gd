extends CanvasLayer

signal dialogue_finished

@onready var dialogue_box = get_node_or_null("DialogueBox")
@onready var dialogue_label = get_node_or_null("DialogueBox/DialogueLabel")
@onready var continue_label = get_node_or_null("DialogueBox/ContinueLabel")

var dialogue_lines = []
var current_index = 0
var showing_text = false

func _ready():
	if dialogue_box == null or dialogue_label == null or continue_label == null:
		push_error("Narrator.gd: Missing required nodes. Please check node paths.")
		return
	
	dialogue_box.visible = false
	continue_label.visible = false

func start_dialogue(lines: Array):
	if dialogue_box == null or dialogue_label == null:
		push_error("Narrator.gd: Dialogue nodes missing. Cannot start dialogue.")
		return

	dialogue_lines = lines
	current_index = 0
	dialogue_box.visible = true
	show_next_line()

func show_next_line():
	if current_index >= dialogue_lines.size():
		end_dialogue()
		return

	showing_text = true
	continue_label.visible = false
	dialogue_label.text = ""
	var text = dialogue_lines[current_index]
	current_index += 1
	reveal_text(text)

func reveal_text(text: String):
	var chars = text.split("")
	dialogue_label.text = ""
	for c in chars:
		dialogue_label.text += c
		await get_tree().create_timer(0.03).timeout
	showing_text = false
	continue_label.visible = true

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept") and dialogue_box and dialogue_box.visible:
		if showing_text:
			showing_text = false
			dialogue_label.text = dialogue_lines[current_index - 1]
			continue_label.visible = true
		else:
			show_next_line()

func end_dialogue():
	if dialogue_box:
		dialogue_box.visible = false
	emit_signal("dialogue_finished")
