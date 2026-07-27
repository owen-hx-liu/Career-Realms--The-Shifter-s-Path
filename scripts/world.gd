extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	$player.position = Vector2(global.next_player_x, global.next_player_y)
	global.current_scene = get_tree().get_current_scene().name

	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
	



		

			

			
		
	
