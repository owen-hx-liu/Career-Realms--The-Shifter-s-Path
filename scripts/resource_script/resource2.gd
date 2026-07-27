extends Node2D

@export var item: InvItem
var player = null
var player_in_range = false
var has_been_collected = false
@export var resource_id: String = ""

signal collectedblueberry
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if global.is_resource_collected(resource_id):
		queue_free()
	
	 # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("collect") and not has_been_collected:
		emit_signal("collectedblueberry")
		player.collect(item)
		has_been_collected = true
		global.mark_resource_collected(resource_id)
		self.visible = false
		print("collected2134124234536478765432145678654321456")
		queue_free()
		
	





func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "player":
		player_in_range = true
		player = body # Replace with function body.


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "player":
		player_in_range = false # Replace with function body.
