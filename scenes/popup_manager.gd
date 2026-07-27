extends Node

var message_popup_scene = preload("res://scenes/message_popup.tscn")  # Is this path correct?

func show_message(message: String, auto_close: float = 0.0):
	print("PopupManager.show_message called with: ", message)
	
	if message_popup_scene == null:
		print("ERROR: message_popup_scene is NULL - path is wrong!")
		return
	
	print("About to instantiate popup...")
	var popup = message_popup_scene.instantiate()
	print("Popup instantiated: ", popup != null)
	
	if popup == null:
		print("ERROR: Failed to instantiate popup!")
		return
	
	print("Popup type: ", popup.get_class())
	
	# Set properties
	popup.message_text = message
	popup.auto_close_time = auto_close
	print("Properties set - message_text: ", popup.message_text)
	
	# Create canvas layer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "PopupLayer"
	canvas_layer.layer = 100
	
	# Add to tree
	get_tree().root.add_child(canvas_layer)
	print("CanvasLayer added")
	
	canvas_layer.add_child(popup)
	print("Popup added to CanvasLayer")
	print("Popup visible: ", popup.visible)
	
	# Set process modes
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	print("ALL DONE - popup should be visible!")
