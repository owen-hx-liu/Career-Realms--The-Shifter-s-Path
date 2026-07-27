extends Control

signal potion_selected(potion_name: String)

@onready var grid := $NinePatchRect/GridContainer
var button_scene := preload("res://scenes/potionselectbutton.tscn")  # Update path to your actual button scene

func _ready():
	visible = false

func show_potions(potion_items: Array[InvItem]):
	visible = true

	# Clear old buttons
	for child in grid.get_children():
		child.queue_free()

	# Create new buttons
	for item in potion_items:
		var btn = button_scene.instantiate()
		btn.potion_name = item.name
		btn.icon = item.texture
		btn.potion_chosen.connect(_on_button_pressed)
		grid.add_child(btn)

func _on_button_pressed(potion_name: String):
	visible = false
	emit_signal("potion_selected", potion_name)
