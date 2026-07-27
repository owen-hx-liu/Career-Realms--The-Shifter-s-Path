extends Area2D

@export var canals_given: int = 3  # change this in Inspector per pile
var player_here: bool = false

func _ready():
	monitoring = true
	monitorable = true
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
		print("Hello, Godot1!")
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))
		print("Hello, Godot2!")
	add_to_group("ResourcePiles")


func _on_body_entered(body):
	# Accept either a node named "player" or node in group "Player" depending on your setup
	if body.name == "player" or body.is_in_group("Player"):
		player_here = true
		print("Hello, Godot3!")
		# Optionally show a small label or hint (if you have a label child)
		if has_node("Label"):
			$Label.visible = true

func _on_body_exited(body):
	if body.name == "player" or body.is_in_group("Player"):
		player_here = false
		print("Hello, Godot4!")
		if has_node("Label"):
			$Label.visible = false
			print("Hello, Godot5!")
