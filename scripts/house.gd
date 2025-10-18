extends Node2D

func _ready():
	global.update_camera()
	$player.position = Vector2(global.next_player_x, global.next_player_y)





# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	



		

			
