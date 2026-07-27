extends Area2D

var is_repaired: bool = false
var my_tile_pos: Vector2i

func _ready():
	pass

func _on_body_entered(body):
	print("Something entered repair site: ", body.name)
	if body is CharacterBody2D and not is_repaired:
		if body.has_method("hook"):
			body.current_repair_site = self
			body.hook()
			is_repaired = true

func on_repair_complete():
	var label = Label.new()
	label.text = "✓"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0, 1, 0))
	# Position relative to the Area2D itself, not global
	label.position = Vector2(-10, -20)
	add_child(label)
	print("Repair complete!")
