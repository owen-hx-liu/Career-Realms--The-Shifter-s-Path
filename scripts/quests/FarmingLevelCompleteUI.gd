# FarmingLevelCompleteUI.gd
# Attach this to a CanvasLayer in your farming quest scene
extends CanvasLayer

signal return_to_hub

var completion_panel: Panel = null
var stars_container: HBoxContainer = null
var title_label: Label = null
var message_label: Label = null
var points_label: Label = null
var return_button: Button = null
var background_texture: TextureRect = null

var stars_earned: int = 0
var is_showing: bool = false

# Star colors
var STAR_FILLED = Color(1.0, 0.84, 0.0)  # Gold
var STAR_EMPTY = Color(0.3, 0.3, 0.3)    # Dark gray

# CUSTOMIZATION: Set these in the inspector
@export var custom_background: Texture2D = null
@export var custom_font: Font = null
@export var quest_id: String = "village_farm_1"  # Unique ID for this quest
@export var domain: String = "Farming"  # Domain: Engineering, Farming, Art, Medicine, Leadership
@export var return_scene: String = "res://scenes/maps/FarmingHouse.tscn"  # Where to return after completion

func _ready():
	_build_ui()
	hide_completion()
	
	if return_button:
		return_button.connect("pressed", Callable(self, "_on_return_pressed"))
	
	print("[FarmingUI] UI built and hidden")
	print("[FarmingUI] Quest ID: ", quest_id, " Domain: ", domain)

func _input(event):
	if is_showing and event.is_action_pressed("ui_accept"):
		print("[FarmingUI] Enter pressed, returning to hub")
		_on_return_pressed()

func _build_ui():
	print("[FarmingUI] Building UI...")
	
	# Main panel
	completion_panel = Panel.new()
	completion_panel.name = "CompletionPanel"
	add_child(completion_panel)
	
	# Center the panel
	completion_panel.set_anchors_preset(Control.PRESET_CENTER)
	completion_panel.offset_left = -250
	completion_panel.offset_right = 250
	completion_panel.offset_top = -250
	completion_panel.offset_bottom = 250
	completion_panel.custom_minimum_size = Vector2(500, 500)
	
	# Background
	if custom_background:
		background_texture = TextureRect.new()
		background_texture.texture = custom_background
		background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background_texture.stretch_mode = TextureRect.STRETCH_SCALE
		background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		completion_panel.add_child(background_texture)
		background_texture.z_index = -1
		
		var transparent_style = StyleBoxFlat.new()
		transparent_style.bg_color = Color(0, 0, 0, 0)
		completion_panel.add_theme_stylebox_override("panel", transparent_style)
	else:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color(0.4, 0.8, 0.4)  # Green border for farming
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		completion_panel.add_theme_stylebox_override("panel", style_box)
	
	# Margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	completion_panel.add_child(margin)
	
	# VBox for content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "HARVEST COMPLETE!"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))  # Bright green
	if custom_font:
		title_label.add_theme_font_override("font", custom_font)
	vbox.add_child(title_label)
	
	# Points display
	points_label = Label.new()
	points_label.text = "0 Points"
	points_label.add_theme_font_size_override("font_size", 28)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_color_override("font_color", Color(1, 1, 1))
	if custom_font:
		points_label.add_theme_font_override("font", custom_font)
	vbox.add_child(points_label)
	
	# Stars container
	stars_container = HBoxContainer.new()
	stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_container.add_theme_constant_override("separation", 15)
	vbox.add_child(stars_container)
	
	# Create 5 star labels
	for i in range(5):
		var star_label = Label.new()
		star_label.text = "★"
		star_label.add_theme_font_size_override("font_size", 64)
		star_label.add_theme_color_override("font_color", STAR_EMPTY)
		if custom_font:
			star_label.add_theme_font_override("font", custom_font)
		star_label.name = "Star%d" % i
		stars_container.add_child(star_label)
	
	# Message label
	message_label = Label.new()
	message_label.text = ""
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(400, 0)
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
	
	print("[FarmingUI] UI build complete")

func show_completion_with_points(total_points: int):
	print("[FarmingUI] show_completion_with_points called with points:", total_points)
	
	if not completion_panel:
		print("[FarmingUI] ERROR: completion_panel is null!")
		return
	
	stars_earned = _calculate_stars_from_points(total_points)
	is_showing = true
	
	print("[FarmingUI] Stars earned:", stars_earned)
	
	# Update points display
	points_label.text = str(total_points) + " Points Earned"
	
	# Update message based on stars
	var messages = {
		0: "The farm didn't produce enough. Try planting more crops!",
		1: "A modest harvest. The village appreciates your effort.",
		2: "Good work! The farm is producing well.",
		3: "Great farming! The village is thriving thanks to you.",
		4: "Excellent harvest! You're a master farmer!",
		5: "LEGENDARY! Perfect farming - the village will prosper!"
	}
	message_label.text = messages.get(stars_earned, "Harvest complete!")
	
	# Show panel and animate stars
	completion_panel.show()
	completion_panel.visible = true
	
	print("[FarmingUI] Panel shown, starting animation")
	_animate_stars()

func _calculate_stars_from_points(points: int) -> int:
	# Star thresholds for 30-minute farming quest
	if points >= 12000:
		return 5  # Legendary farmer
	elif points >= 9000:
		return 4  # Excellent farmer
	elif points >= 6000:
		return 3  # Great farmer
	elif points >= 3000:
		return 2  # Good farmer
	elif points >= 1000:
		return 1  # Basic farmer
	else:
		return 0  # Failed to establish farm

func _animate_stars():
	print("[FarmingUI] Animating stars")
	
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
			await get_tree().create_timer(0.15 * i).timeout
			var tween = create_tween()
			tween.tween_property(star, "scale", Vector2(1.3, 1.3), 0.1)
			tween.tween_property(star, "scale", Vector2(1.0, 1.0), 0.1)
			star.add_theme_color_override("font_color", STAR_FILLED)
			print("[FarmingUI] Star %d filled" % i)

func hide_completion():
	is_showing = false
	if completion_panel:
		completion_panel.hide()
		completion_panel.visible = false

func _on_return_pressed():
	print("[FarmingUI] Return pressed - saving stars and returning to hub")
	
	# Save stars to StarManager with the specified domain
	StarManager.record_quest_stars(quest_id, domain, stars_earned, 5)
	EndingManager.complete_quest("village_farming", "Farming", stars_earned)
	LegacyAchievementManager.check_star_achievements()
	LegacyAchievementManager.check_speed_achievements()
	print("[FarmingUI] Saved ", stars_earned, " stars for ", domain, " domain (Quest: ", quest_id, ")")
	print("[FarmingUI] Returning to: ", return_scene)
	
	emit_signal("return_to_hub")
	hide_completion()
	
	# Return to the specified scene
	get_tree().change_scene_to_file(return_scene)
