extends StaticBody2D

# IDs needed for THIS specific door
@export var required_ids: Array[String] = ["1", "2", "3"]
@onready var wall_collider: CollisionShape2D = $CollisionShape2D

var signal_states: Dictionary = {}

func _ready():
	for id in required_ids:
		signal_states[id] = false
	update_door_state()

# Targets call this
func update_signal(id: String, state: bool):
	if signal_states.has(id):
		signal_states[id] = state
		update_door_state()

func update_door_state():
	var all_hit = true
	for id in signal_states:
		if not signal_states[id]:
			all_hit = false
			break
	
	if wall_collider:
		# Wall is DISABLED (Open) only if all are hit
		wall_collider.set_deferred("disabled", all_hit)
