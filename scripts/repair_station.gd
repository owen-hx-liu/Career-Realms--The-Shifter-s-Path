extends Area2D

@export var mini_game_layer: CanvasLayer
var player_in_zone = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"): player_in_zone = true

func _on_body_exited(body):
	if body.is_in_group("player"): 
		player_in_zone = false
		mini_game_layer.visible = false

func _input(event):
	if player_in_zone and global.system_broken and event.is_action_pressed("collect"):
		mini_game_layer.visible = true
		mini_game_layer.get_node("MiniGame").setup_game()
