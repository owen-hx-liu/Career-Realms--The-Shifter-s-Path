extends Area2D

@export var paper_texture: Texture2D  # The paper graphic to show
var domain_name: String = "Engineering"  # Which domain this paper is for

var player_nearby: bool = false
var paper_ui: Control = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Make sure this node can process when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create the paper UI AFTER we're in the tree
	call_deferred("create_paper_ui")

func _process(delta):
	# Check for input even when paused
	if player_nearby and Input.is_action_just_pressed("ui_accept"):  # Enter key
		toggle_paper()
		print("[Paper] Enter key pressed, toggling paper")

func _on_body_entered(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		player_nearby = true
		print("[Paper] Player nearby - Press ENTER to read")

func _on_body_exited(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		player_nearby = false
		if paper_ui and paper_ui.visible:
			close_paper()

func toggle_paper():
	if paper_ui:
		if paper_ui.visible:
			close_paper()
		else:
			open_paper()

func open_paper():
	if paper_ui:
		# Update the text with current stats before showing
		update_paper_content()
		paper_ui.visible = true
		paper_ui.show()
		# Pause the game while reading
		get_tree().paused = true
		
		print("[Paper] Paper opened")
		print("[Paper] paper_ui visible: ", paper_ui.visible)
		print("[Paper] paper_ui is_inside_tree: ", paper_ui.is_inside_tree())
		print("[Paper] paper_ui size: ", paper_ui.size)

func close_paper():
	if paper_ui:
		paper_ui.visible = false
		paper_ui.hide()
		get_tree().paused = false
		print("[Paper] Paper closed")

func get_paper_content() -> Dictionary:
	# Get current stats from StarManager
	var domain_stars = StarManager.get_domain_stars(domain_name)
	var domain_max_stars = StarManager.get_domain_max_stars(domain_name)
	var total_stars = StarManager.get_total_stars()
	var pedestals_filled = global.get_total_pedestals_with_stars("Engineering")
	
	# Build the content
	var title = "🔧 Engineering Department 🔧"
	
	var content = ""
	content += "━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	
	# Star System Explanation
	content += "⭐ THE STAR SYSTEM ⭐\n\n"
	content += "Complete quests to earn stars based on your\n"
	content += "performance. Each quest awards 1-5 stars.\n\n"
	
	# Pedestal System
	content += "🏛️ PEDESTAL PLACEMENT 🏛️\n\n"
	content += "Stars collected can be placed on the 15 pedestals\n"
	content += "scattered throughout the hub. Walk up to an empty\n"
	content += "pedestal and press C to place a star.\n\n"
	content += "Pedestals Filled: " + str(pedestals_filled) + " / 15\n\n"
	
	# Current Progress
	content += "━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	content += "YOUR PROGRESS:\n"
	content += "Total Stars Earned: " + str(total_stars) + "\n"
	content += "Engineering Stars: " + str(domain_stars)
	if domain_max_stars > 0:
		content += " / " + str(domain_max_stars)
	content += "\n\n"
	
	# Current Quest Description
	content += "━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	content += "CURRENT QUEST:\n"
	content += "The Flood Canal Challenge\n\n"
	content += "The ancient city's irrigation system has failed!\n"
	content += "Villagers need your engineering expertise to\n"
	content += "redirect water flow and prevent flooding.\n\n"
	content += "Mission Objectives:\n"
	content += "• Design and build flood control channels\n"
	content += "• Redirect water away from homes\n"
	content += "• Ensure proper drainage to fields\n"
	content += "• Complete within time limit for bonus stars\n\n"
	
	content += "━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	content += "Press ENTER to close"
	
	return {
		"title": title,
		"content": content
	}

func update_paper_content():
	# Find the labels in the UI and update them
	if not paper_ui:
		return
	
	var data = get_paper_content()
	
	# Find title label
	var title_label = find_node_by_name(paper_ui, "TitleLabel")
	if title_label:
		title_label.text = data.title
	
	# Find content label
	var content_label = find_node_by_name(paper_ui, "ContentLabel")
	if content_label:
		content_label.text = data.content

func find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var result = find_node_by_name(child, node_name)
		if result:
			return result
	return null

func create_paper_ui():
	print("[Paper] === STARTING UI CREATION ===")
	print("[Paper] Is this node in tree?: ", is_inside_tree())
	print("[Paper] get_tree() result: ", get_tree())
	print("[Paper] get_tree().root result: ", get_tree().root if get_tree() else "NULL")
	
	if not get_tree():
		print("[Paper] ERROR: get_tree() is null! Cannot create UI.")
		return
	
	# Create a CanvasLayer to ensure it's above everything
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # Very high layer
	canvas_layer.name = "PaperCanvasLayer"
	print("[Paper] Created CanvasLayer")
	
	# Add canvas_layer to scene tree FIRST
	var root = get_tree().root
	print("[Paper] About to add to root, root =", root)
	root.add_child(canvas_layer)
	print("[Paper] Added CanvasLayer to root")
	print("[Paper] CanvasLayer is_inside_tree: ", canvas_layer.is_inside_tree())
	
	# Create a fullscreen overlay (for background dimming)
	paper_ui = Control.new()
	paper_ui.name = "PaperUI"
	
	# CRITICAL: Set anchors and offsets to fill the screen
	paper_ui.anchor_left = 0.0
	paper_ui.anchor_top = 0.0
	paper_ui.anchor_right = 1.0
	paper_ui.anchor_bottom = 1.0
	paper_ui.offset_left = 0.0
	paper_ui.offset_top = 0.0
	paper_ui.offset_right = 0.0
	paper_ui.offset_bottom = 0.0
	
	paper_ui.visible = false
	paper_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	print("[Paper] Created paper_ui Control with fullscreen anchors")
	
	# Add paper_ui to canvas_layer BEFORE adding children
	canvas_layer.add_child(paper_ui)
	print("[Paper] Added paper_ui to CanvasLayer")
	print("[Paper] paper_ui is_inside_tree: ", paper_ui.is_inside_tree())
	
	# Semi-transparent black background
	var background = ColorRect.new()
	background.name = "Background"
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color(0, 0, 0, 0.7)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	paper_ui.add_child(background)
	print("[Paper] Added background ColorRect")
	
	# Center container for the paper popup
	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.anchor_left = 0.0
	center_container.anchor_top = 0.0
	center_container.anchor_right = 1.0
	center_container.anchor_bottom = 1.0
	paper_ui.add_child(center_container)
	print("[Paper] Added CenterContainer")
	
	# Paper panel (popup style - fixed size in middle of screen)
	var paper_panel = Panel.new()
	paper_panel.name = "PaperPanel"
	paper_panel.custom_minimum_size = Vector2(500, 450)
	center_container.add_child(paper_panel)
	print("[Paper] Added Panel with size: ", paper_panel.custom_minimum_size)
	
	# Add a stylebox for nice borders/shadow effect
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.95, 0.9, 0.85)
	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(0.4, 0.3, 0.2)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	paper_panel.add_theme_stylebox_override("panel", style_box)
	
	# If you have a paper texture, show it as background
	if paper_texture:
		var texture_rect = TextureRect.new()
		texture_rect.name = "TextureBackground"
		texture_rect.texture = paper_texture
		texture_rect.anchor_left = 0.0
		texture_rect.anchor_top = 0.0
		texture_rect.anchor_right = 1.0
		texture_rect.anchor_bottom = 1.0
		texture_rect.offset_left = 0.0
		texture_rect.offset_top = 0.0
		texture_rect.offset_right = 0.0
		texture_rect.offset_bottom = 0.0
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		texture_rect.z_index = -1  # Behind the text
		paper_panel.add_child(texture_rect)
		print("[Paper] Added texture background")
	
	# Content container with margins
	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	paper_panel.add_child(margin)
	
	# Scroll container for long text
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(scroll)
	
	# VBox for title and text
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 15)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	# Title
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "TEST TITLE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.1, 0.05))
	vbox.add_child(title_label)
	
	# Text content
	var text_label = Label.new()
	text_label.name = "ContentLabel"
	text_label.text = "TEST CONTENT - If you see this, the paper is working!"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_font_size_override("font_size", 14)
	text_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_label)
	
	# Set initial content
	var data = get_paper_content()
	title_label.text = data.title
	text_label.text = data.content
	print("[Paper] Set content")
	
	# Make sure it processes even when paused
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	paper_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wait one frame and check again
	await get_tree().process_frame
	
	print("[Paper] === UI CREATION COMPLETE ===")
	print("[Paper] Canvas layer in tree: ", canvas_layer.is_inside_tree())
	print("[Paper] Paper UI in tree: ", paper_ui.is_inside_tree())
	print("[Paper] Paper UI size: ", paper_ui.size)
	print("[Paper] Viewport size: ", get_viewport().get_visible_rect().size if get_viewport() else "NO VIEWPORT")
