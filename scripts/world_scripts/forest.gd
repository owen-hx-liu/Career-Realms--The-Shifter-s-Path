extends Node2D

func _ready() -> void:
	# Position player based on global state
	$player.position = Vector2(global.next_player_x, global.next_player_y)
	global.current_scene = get_tree().get_current_scene().name

	# ✅ Only add narrator once
	if get_tree().get_first_node_in_group("narrator") == null:
		var narrator = preload("res://scenes/narrator.tscn").instantiate()
		add_child(narrator)

	# ✅ Connect villager signals to Scoremanager (autoload singleton)
	

	
  # Should show Node instance, not resource

func _input(event):
	if event.is_action_pressed("reopen_narrator"):  # Q key
		var narrator = get_tree().get_first_node_in_group("narrator")
		if narrator:
			narrator.visible = true
			narrator.set_process_input(true)
			narrator.call("show_step")  # Reset to first step
