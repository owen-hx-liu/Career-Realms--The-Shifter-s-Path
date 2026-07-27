extends Node

var message_popup_scene = preload("res://scenes/message_popup.tscn")

func show_message(message: String, auto_close: float = 0.0):
	var popup = message_popup_scene.instantiate()
	popup.message_text = message
	popup.auto_close_time = auto_close
	
	# Add to the current scene tree
	var root = get_tree().root
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "PopupLayer"
	root.add_child(canvas_layer)
	canvas_layer.add_child(popup)
	
	# Set process mode to always
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
