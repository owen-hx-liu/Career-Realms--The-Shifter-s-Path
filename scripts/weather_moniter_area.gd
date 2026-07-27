extends Area2D

var player_in_range = false
# In the Inspector, click this and select your WeatherPanel node
@export var weather_panel: Control 

func _on_body_entered(body):
	if body.name == "player":
		player_in_range = true

func _on_body_exited(body):
	if body.name == "player":
		player_in_range = false
		if weather_panel.visible:
			weather_panel.toggle()

func _input(event):
	if player_in_range and event.is_action_pressed("collect"):
		if weather_panel:
			weather_panel.toggle()
