extends Node2D

@onready var congrats = $CongratsScreen

func _ready():
	var player = $player
	if player == null:
		print("ERROR: player not found")
		return
	
	match Global.spawn_point:
		"from_level":
			if $SpawnPoint2 == null:
				print("ERROR: SpawnPoint2 not found")
				return
			player.global_position = $SpawnPoint2.global_position
			if Global.all_patients_complete():
				congrats.show_congrats()
		_:
			if $SpawnPoint == null:
				print("ERROR: SpawnPoint not found")
				return
			player.global_position = $SpawnPoint.global_position
