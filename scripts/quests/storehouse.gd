extends Node2D

var game_time_seconds = 0
var game_timer_running = false

func _ready():
	# Load timer state from GameState
	game_time_seconds = GameState.game_time_remaining
	game_timer_running = GameState.game_timer_started
	
	# Resume timer if it's running
	if game_timer_running:
		var timer = get_node_or_null("CanvasLayer/GameTimer")
		if timer:
			if not timer.timeout.is_connected(_on_game_timer_tick):
				timer.timeout.connect(_on_game_timer_tick)
			if timer.is_stopped():
				timer.start()
	
	update_game_timer_label()

func _on_game_timer_tick():
	if not game_timer_running:
		return
	
	game_time_seconds -= 1
	GameState.game_time_remaining = game_time_seconds
	update_game_timer_label()
	
	if game_time_seconds <= 0:
		game_time_seconds = 0
		GameState.game_time_remaining = 0
		game_timer_running = false
		GameState.game_timer_started = false
		
		var timer = get_node_or_null("CanvasLayer/GameTimer")
		if timer:
			timer.stop()
		
		# Could show an end message here too if desired

func update_game_timer_label():
	var label = get_node_or_null("CanvasLayer/GameTimerLabel")
	if not label:
		return
	
	var minutes = game_time_seconds / 60
	var seconds = game_time_seconds % 60
	label.text = "%02d:%02d" % [minutes, seconds]
