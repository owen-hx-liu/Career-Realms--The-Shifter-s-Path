# LevelCompleteUI.gd
# Attach this to a CanvasLayer in your quest scene
extends CanvasLayer

signal return_to_hub

var completion_panel: Panel = null
var stars_container: HBoxContainer = null
var title_label: Label = null
var message_label: Label = null
var return_button: Button = null
var background_texture: TextureRect = null

var stars_earned: int = 0
var is_showing: bool = false

# Star colors
var STAR_FILLED = Color(1.0, 0.84, 0.0)  # Gold
var STAR_EMPTY = Color(0.3, 0.3, 0.3)    # Dark gray

# CUSTOMIZATION: Set these in the inspector or in code
@export var custom_background: Texture2D = null  # Drag your background image here
@export var custom_font: Font = null  # Drag your font file here
@export var text_color: Color = Color(1, 1, 1)  # Title/message colour (dark for light panels)
# Layout knobs — defaults match the original look. Override these to fit content
# inside a framed background (e.g. the Egyptian stela's inner papyrus field).
@export var content_margin_left: int = 40
@export var content_margin_right: int = 40
@export var content_margin_top: int = 40
@export var content_margin_bottom: int = 40
@export var title_font_size: int = 36
@export var star_font_size: int = 64
@export var message_font_size: int = 20
@export var message_width: int = 400
@export var item_separation: int = 30
@export var quest_id: String = "flood_egypt_1"  # Unique ID for this quest
@export var domain: String = "Engineering"  # Domain: Engineering, Farming, Art, Medicine, Leadership
@export var return_scene: String = "res://scenes/maps/EngineeringHouse.tscn"  # Where to return after completion

func _ready():
	_build_ui()
	hide_completion()
	
	if return_button:
		return_button.connect("pressed", Callable(self, "_on_return_pressed"))
	
	print("[LevelCompleteUI] UI built and hidden")
	print("[LevelCompleteUI] Quest ID: ", quest_id, " Domain: ", domain)

func _input(event):
	if is_showing and event.is_action_pressed("ui_accept"):
		print("[LevelCompleteUI] Enter pressed, returning to hub")
		_on_return_pressed()

func _build_ui():
	print("[LevelCompleteUI] Building UI...")
	
	# Main panel
	completion_panel = Panel.new()
	completion_panel.name = "CompletionPanel"
	add_child(completion_panel)
	
	# Center the panel properly
	completion_panel.set_anchors_preset(Control.PRESET_CENTER)
	completion_panel.offset_left = -250
	completion_panel.offset_right = 250
	completion_panel.offset_top = -200
	completion_panel.offset_bottom = 200
	completion_panel.custom_minimum_size = Vector2(500, 400)
	
	# Background - either custom texture or styled box
	if custom_background:
		# Use custom background image
		background_texture = TextureRect.new()
		background_texture.texture = custom_background
		background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_texture.stretch_mode = TextureRect.STRETCH_SCALE
		background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		completion_panel.add_child(background_texture)
		background_texture.z_index = -1
		
		# Make panel background transparent
		var transparent_style = StyleBoxFlat.new()
		transparent_style.bg_color = Color(0, 0, 0, 0)
		completion_panel.add_theme_stylebox_override("panel", transparent_style)
	else:
		# Use default styled box
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color(0.8, 0.6, 0.2)
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		completion_panel.add_theme_stylebox_override("panel", style_box)
	
	# Margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", content_margin_left)
	margin.add_theme_constant_override("margin_right", content_margin_right)
	margin.add_theme_constant_override("margin_top", content_margin_top)
	margin.add_theme_constant_override("margin_bottom", content_margin_bottom)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	completion_panel.add_child(margin)

	# VBox for content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", item_separation)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "QUEST COMPLETE!"
	title_label.add_theme_font_size_override("font_size", title_font_size)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", text_color)
	if custom_font:
		title_label.add_theme_font_override("font", custom_font)
	vbox.add_child(title_label)
	
	# Stars container
	stars_container = HBoxContainer.new()
	stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_container.add_theme_constant_override("separation", 15)
	vbox.add_child(stars_container)
	
	# Create 5 star labels
	for i in range(5):
		var star_label = Label.new()
		star_label.text = "★"
		star_label.add_theme_font_size_override("font_size", star_font_size)
		star_label.add_theme_color_override("font_color", STAR_EMPTY)
		if custom_font:
			star_label.add_theme_font_override("font", custom_font)
		star_label.name = "Star%d" % i
		stars_container.add_child(star_label)
	
	# Message label
	message_label = Label.new()
	message_label.text = ""
	message_label.add_theme_font_size_override("font_size", message_font_size)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(message_width, 0)
	message_label.add_theme_color_override("font_color", text_color)
	if custom_font:
		message_label.add_theme_font_override("font", custom_font)
	vbox.add_child(message_label)
	
	# Return button
	return_button = Button.new()
	return_button.text = "Press ENTER to Return to Hub"
	return_button.custom_minimum_size = Vector2(300, 50)
	return_button.add_theme_font_size_override("font_size", 18)
	if custom_font:
		return_button.add_theme_font_override("font", custom_font)
	var button_container = CenterContainer.new()
	button_container.add_child(return_button)
	vbox.add_child(button_container)
	
	print("[LevelCompleteUI] UI build complete")

func show_completion(reservoirs_filled: int):
	print("[LevelCompleteUI] show_completion called with reservoirs_filled:", reservoirs_filled)
	
	if not completion_panel:
		print("[LevelCompleteUI] ERROR: completion_panel is null!")
		return
	
	stars_earned = _calculate_stars(reservoirs_filled)
	is_showing = true
	
	print("[LevelCompleteUI] Stars earned:", stars_earned)
	
	# Update message based on reservoirs filled
	var messages = {
		0: "No reservoirs filled. The farmland flooded!",
		1: "Good start! One reservoir filled.",
		2: "Great work! Two reservoirs filled!",
		3: "Perfect! All three reservoirs filled!"
	}
	message_label.text = messages.get(reservoirs_filled, "Quest complete!")
	
	# Show panel and animate stars
	completion_panel.show()
	completion_panel.visible = true
	
	print("[LevelCompleteUI] Panel shown, starting animation")
	_animate_stars()

func _calculate_stars(reservoirs_filled: int) -> int:
	# Star calculation: 0 reservoirs = 0 stars, 1 = 1 star, 2 = 3 stars, 3 = 5 stars
	match reservoirs_filled:
		0:
			return 0
		1:
			return 1
		2:
			return 3
		3:
			return 5
		_:
			return 0

func _animate_stars():
	print("[LevelCompleteUI] Animating stars")
	
	# Reset all stars to empty
	for i in range(5):
		var star = stars_container.get_node_or_null("Star%d" % i)
		if star:
			star.add_theme_color_override("font_color", STAR_EMPTY)
			star.scale = Vector2(1.0, 1.0)
	
	# Animate filled stars
	for i in range(stars_earned):
		var star = stars_container.get_node_or_null("Star%d" % i)
		if star:
			# Use a tween for smooth animation
			await get_tree().create_timer(0.15 * i).timeout
			var tween = create_tween()
			tween.tween_property(star, "scale", Vector2(1.3, 1.3), 0.1)
			tween.tween_property(star, "scale", Vector2(1.0, 1.0), 0.1)
			star.add_theme_color_override("font_color", STAR_FILLED)
			print("[LevelCompleteUI] Star %d filled" % i)

func hide_completion():
	is_showing = false
	if completion_panel:
		completion_panel.hide()
		completion_panel.visible = false

func _on_return_pressed():
	print("[LevelCompleteUI] Return pressed - saving stars and returning to hub")
	
	# Save stars to StarManager with the specified domain
	StarManager.record_quest_stars(quest_id, domain, stars_earned, 5)
	EndingManager.complete_quest("flood_egypt_1", "Engineering", stars_earned)
	LegacyAchievementManager.check_star_achievements()
	LegacyAchievementManager.check_speed_achievements()
	print("[LevelCompleteUI] Saved ", stars_earned, " stars for ", domain, " domain (Quest: ", quest_id, ")")
	print("[LevelCompleteUI] Returning to: ", return_scene)
	
	# Emit signal first
	emit_signal("return_to_hub")
	
	# Hide the UI
	hide_completion()
	
	# Use call_deferred to ensure the scene change happens safely
	if get_tree():
		get_tree().call_deferred("change_scene_to_file", return_scene)
	else:
		print("[LevelCompleteUI] ERROR: get_tree() is null!")
