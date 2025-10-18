extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	global.update_camera()
	$player.position = Vector2(global.next_player_x, global.next_player_y)
	

	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
	



		

			

			
		
	
