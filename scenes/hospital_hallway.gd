extends Node2D

func _ready():
	var player = $player
	match Global.spawn_point:
		"patient1":
			player.global_position = $SpawnPatient1.global_position
		"patient2":
			player.global_position = $SpawnPatient2.global_position
		"patient3":
			player.global_position = $SpawnPatient3.global_position
		"patient4":
			player.global_position = $SpawnPatient4.global_position
		_:
			player.global_position = $SpawnPointLobby.global_position
