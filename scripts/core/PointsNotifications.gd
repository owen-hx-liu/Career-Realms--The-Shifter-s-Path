extends CanvasLayer

const MAX_VISIBLE_NOTIFICATIONS = 5
const NOTIFICATION_LIFETIME = 3.0  # seconds before fading out
const NOTIFICATION_HEIGHT = 30  # pixels per notification
const FADE_DURATION = 0.5  # seconds to fade out

var notifications = []  # Array of {label: Label, time: float}
var container: Control

func _ready():
	# Set layer to be on top
	layer = 100
	
	# Create container control
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.offset_left = -300  # Shifted more to the left
	container.offset_right = -100
	container.offset_top = 10
	container.offset_bottom = 200
	add_child(container)
	
	print("[NOTIFICATION] System ready")

func show_points_notification(points: int, crop_name: String, synergy_bonus: int = 0):
	var message = ""
	if synergy_bonus > 0:
		message = "+%d pts (%s) +%d synergy!" % [points - synergy_bonus, crop_name, synergy_bonus]
	else:
		message = "+%d pts (%s)" % [points, crop_name]
	
	add_notification(message)

func add_notification(text: String):
	# Create new label
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))  # Yellow/gold color
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.modulate.a = 1.0
	label.z_index = 1000
	
	container.add_child(label)
	
	# Add to notifications array
	notifications.append({
		"label": label,
		"time": 0.0
	})
	
	# Position all notifications
	reposition_notifications()
	
	print("[NOTIFICATION] Added and positioned: ", text)

func reposition_notifications():
	var y_pos = 0
	var visible_count = 0
	
	# Position from top to bottom, but only show MAX_VISIBLE_NOTIFICATIONS
	for i in range(notifications.size()):
		var notif = notifications[i]
		var label = notif["label"]
		
		if visible_count < MAX_VISIBLE_NOTIFICATIONS:
			label.visible = true
			label.position = Vector2(0, y_pos)
			label.size = Vector2(230, NOTIFICATION_HEIGHT)
			y_pos += NOTIFICATION_HEIGHT
			visible_count += 1
		else:
			# Hide older notifications that exceed the limit
			label.visible = false

func _process(delta):
	var i = 0
	while i < notifications.size():
		var notif = notifications[i]
		notif["time"] += delta
		
		# Start fading after lifetime
		if notif["time"] > NOTIFICATION_LIFETIME:
			var fade_progress = (notif["time"] - NOTIFICATION_LIFETIME) / FADE_DURATION
			notif["label"].modulate.a = 1.0 - fade_progress
			
			# Remove when fully faded
			if fade_progress >= 1.0:
				notif["label"].queue_free()
				notifications.remove_at(i)
				reposition_notifications()
				continue
		
		i += 1
