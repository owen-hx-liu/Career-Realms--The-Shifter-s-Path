extends CharacterBody2D

const speed = 30
var is_chatting = false
var player = null
var player_in_chat_zone = false

# Dialogue system
var current_dialogue_index = 0
var dialogues = [
	{"name": "Charlotte", "text": "HI there! My name is Charlotte."},
	{"name": "Charlotte", "text": "I'm a farmer from the past, and there is a serious issue I need your help with."},
	{"name": "Charlotte", "text": "My village is starving right now and needs someone who can harvest enough food to feed everyone."},
	{"name": "Charlotte", "text": "I need you to strategiclly plant crops to produce the best harvest."},
	{"name": "Charlotte", "text": "Will you accept this quest?"}
]

# Choice system
var showing_choice = false
var selected_choice = 0  # 0 = Yes, 1 = No

# Reference to the dialogue UI
@export var dialogue_box_scene: PackedScene
var dialogue_box = null

func _ready():
	print("[NPC] ========== _ready START ==========")
	if dialogue_box_scene:
		print("[NPC] dialogue_box_scene is assigned:", dialogue_box_scene)
		dialogue_box = dialogue_box_scene.instantiate()
		print("[NPC] dialogue_box instantiated:", dialogue_box)
		
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100
		canvas_layer.name = "DialogueCanvasLayer"
		print("[NPC] Created CanvasLayer with layer:", canvas_layer.layer)
		
		get_tree().current_scene.call_deferred("add_child", canvas_layer)
		canvas_layer.call_deferred("add_child", dialogue_box)
		
		print("[NPC] Scheduled CanvasLayer and DialogueBox to be added to scene tree")
		
		await get_tree().process_frame
		
		print("[NPC] After process_frame:")
		print("[NPC]   CanvasLayer in tree:", canvas_layer.is_inside_tree())
		print("[NPC]   DialogueBox in tree:", dialogue_box.is_inside_tree())
		
		dialogue_box.visible = false
		print("[NPC] Set DialogueBox visible to false initially")
		print("[NPC] DialogueBox type:", dialogue_box.get_class())
		
		var sprite = dialogue_box.get_node_or_null("Sprite2D")
		if sprite:
			print("[NPC] Sprite2D found!")
		else:
			print("[NPC] ERROR: Sprite2D NOT FOUND!")
		
		var name_lbl = dialogue_box.get_node_or_null("RichTextLabel1")
		var text_lbl = dialogue_box.get_node_or_null("RichTextLabel2")
		print("[NPC] RichTextLabel1 found:", name_lbl != null)
		print("[NPC] RichTextLabel2 found:", text_lbl != null)
		
		# Hide choice UI initially
		hide_choice_ui()
		
		print("[NPC] ========== _ready END ==========")
	else:
		print("[NPC] ERROR: dialogue_box_scene NOT ASSIGNED in inspector!")
	print("")

func _process(delta):
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("idle")
	
	# Handle choice selection with arrow keys
	if showing_choice:
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
			selected_choice = 1 - selected_choice  # Toggle between 0 and 1
			update_choice_selection()
			print("[NPC] Choice toggled to:", "Yes" if selected_choice == 0 else "No")
		
		if Input.is_action_just_pressed("ui_accept"):  # Enter key
			handle_choice_selection()
			return
	
	# Normal dialogue progression
	if player_in_chat_zone and Input.is_action_just_pressed("chat") and not showing_choice:
		print("[NPC] Chat button pressed! is_chatting:", is_chatting)
		if not is_chatting:
			start_dialogue()
		else:
			next_dialogue()

func start_dialogue():
	print("[NPC] start_dialogue called")
	is_chatting = true
	current_dialogue_index = 0
	showing_choice = false
	selected_choice = 0
	show_dialogue()
	
	if player:
		player.set_physics_process(false)
		print("[NPC] Disabled player movement")

func next_dialogue():
	print("[NPC] next_dialogue called, current index:", current_dialogue_index)
	current_dialogue_index += 1
	
	if current_dialogue_index < dialogues.size():
		show_dialogue()
	else:
		# On last dialogue, show choice instead of ending
		if current_dialogue_index == dialogues.size():
			show_choice_ui()

func show_dialogue():
	print("[NPC] ========== show_dialogue START ==========")
	print("[NPC] Current dialogue index:", current_dialogue_index)
	
	if not dialogue_box:
		print("[NPC] ERROR: dialogue_box is NULL!")
		return
	
	dialogue_box.visible = true
	dialogue_box.z_index = 1000
	
	var sprite = dialogue_box.get_node_or_null("Sprite2D")
	if sprite:
		sprite.position = Vector2(400, 325)
		sprite.scale = Vector2(0.2, 0.1)
		sprite.visible = true
		sprite.z_index = 0
	
	var current = dialogues[current_dialogue_index]
	var name_label = dialogue_box.get_node_or_null("RichTextLabel1")
	var text_label = dialogue_box.get_node_or_null("RichTextLabel2")
	
	if name_label:
		# Clear anchors so position works
		name_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		name_label.anchor_left = 0
		name_label.anchor_top = 0
		name_label.anchor_right = 0
		name_label.anchor_bottom = 0
		name_label.offset_left = 0
		name_label.offset_top = 0
		name_label.offset_right = 0
		name_label.offset_bottom = 0
		
		name_label.text = current["name"]
		name_label.visible = true
		name_label.z_index = 11
		name_label.position = Vector2(270, 285)
		name_label.scale = Vector2(1, 1)
		name_label.size = Vector2(110, 12)
		name_label.add_theme_font_size_override("normal_font_size", 16)
		name_label.add_theme_color_override("default_color", Color(0.2, 0.1, 0.05, 1))
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.fit_content = true
		name_label.scroll_active = false
		name_label.scroll_following = false
		name_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		name_label.clip_contents = false
		
		print("[NPC]   name_label POSITION:", name_label.position, "SCALE:", name_label.scale)
	
	if text_label:
		# Clear anchors so position works
		text_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		text_label.anchor_left = 0
		text_label.anchor_top = 0
		text_label.anchor_right = 0
		text_label.anchor_bottom = 0
		text_label.offset_left = 0
		text_label.offset_top = 0
		text_label.offset_right = 0
		text_label.offset_bottom = 0
		
		text_label.text = current["text"]
		text_label.visible = true
		text_label.z_index = 10
		text_label.position = Vector2(270, 305)
		text_label.scale = Vector2(1, 1)
		text_label.size = Vector2(275, 70)
		text_label.add_theme_font_size_override("normal_font_size", 15)
		text_label.add_theme_color_override("default_color", Color(0.2, 0.1, 0.05, 1))
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.fit_content = true
		text_label.scroll_active = false
		text_label.scroll_following = false
		text_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		text_label.clip_contents = false
		
		print("[NPC]   text_label POSITION:", text_label.position, "SCALE:", text_label.scale)
	
	# Check if this is the last dialogue
	if current_dialogue_index == dialogues.size() - 1:
		print("[NPC] Last dialogue reached, will show choice on next input")
	
	print("[NPC] ========== show_dialogue END ==========")
	print("")

func show_choice_ui():
	print("[NPC] ========== show_choice_ui START ==========")
	showing_choice = true
	selected_choice = 0
	
	if not dialogue_box:
		return
	
	# Get the main dialogue box sprite for reference
	var main_sprite = dialogue_box.get_node_or_null("Sprite2D")
	if not main_sprite:
		print("[NPC] ERROR: Main Sprite2D not found!")
		return
	
	# Calculate choice box position (10 pixels to the right, centered vertically)
	var main_pos = main_sprite.position
	var main_scale = main_sprite.scale
	var choice_box_x = main_pos.x + (main_sprite.texture.get_width() * main_scale.x / 2) + 60
	var choice_box_y = main_pos.y
	
	# Setup choice box sprite (quarter width, half height)
	var choice_sprite = dialogue_box.get_node_or_null("ChoiceBoxSprite")
	if choice_sprite:
		choice_sprite.position = Vector2(choice_box_x, choice_box_y)
		choice_sprite.scale = Vector2(main_scale.x / 4, main_scale.y / 2)
		choice_sprite.visible = true
		choice_sprite.z_index = 0
		print("[NPC] Choice box sprite positioned at:", choice_sprite.position)
	else:
		print("[NPC] ERROR: ChoiceBoxSprite not found!")
	
	# Setup Yes label
	var yes_label = dialogue_box.get_node_or_null("YesLabel")
	if yes_label:
		yes_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		yes_label.anchor_left = 0
		yes_label.anchor_top = 0
		yes_label.anchor_right = 0
		yes_label.anchor_bottom = 0
		yes_label.offset_left = 0
		yes_label.offset_top = 0
		yes_label.offset_right = 0
		yes_label.offset_bottom = 0
		
		yes_label.text = "Yes"
		yes_label.position = Vector2(choice_box_x - 10, choice_box_y - 20)
		yes_label.scale = Vector2(1, 1)
		yes_label.size = Vector2(60, 20)
		yes_label.add_theme_font_size_override("normal_font_size", 14)
		yes_label.add_theme_color_override("default_color", Color(0.2, 0.1, 0.05, 1))
		yes_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		yes_label.fit_content = true
		yes_label.scroll_active = false
		yes_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		yes_label.visible = true
		yes_label.z_index = 11
	
	# Setup No label
	var no_label = dialogue_box.get_node_or_null("NoLabel")
	if no_label:
		no_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		no_label.anchor_left = 0
		no_label.anchor_top = 0
		no_label.anchor_right = 0
		no_label.anchor_bottom = 0
		no_label.offset_left = 0
		no_label.offset_top = 0
		no_label.offset_right = 0
		no_label.offset_bottom = 0
		
		no_label.text = "No"
		no_label.position = Vector2(choice_box_x - 10, choice_box_y )
		no_label.scale = Vector2(1, 1)
		no_label.size = Vector2(60, 20)
		no_label.add_theme_font_size_override("normal_font_size", 14)
		no_label.add_theme_color_override("default_color", Color(0.2, 0.1, 0.05, 1))
		no_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		no_label.fit_content = true
		no_label.scroll_active = false
		no_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no_label.visible = true
		no_label.z_index = 11
	
	# Setup selection arrow
	var arrow = dialogue_box.get_node_or_null("SelectionArrow")
	if arrow:
		arrow.visible = true
		arrow.z_index = 12
		arrow.scale = Vector2(0.1, 0.1)
		arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	update_choice_selection()
	
	print("[NPC] ========== show_choice_ui END ==========")

func hide_choice_ui():
	if not dialogue_box:
		return
	
	var choice_sprite = dialogue_box.get_node_or_null("ChoiceBoxSprite")
	var yes_label = dialogue_box.get_node_or_null("YesLabel")
	var no_label = dialogue_box.get_node_or_null("NoLabel")
	var arrow = dialogue_box.get_node_or_null("SelectionArrow")
	
	if choice_sprite:
		choice_sprite.visible = false
	if yes_label:
		yes_label.visible = false
	if no_label:
		no_label.visible = false
	if arrow:
		arrow.visible = false

func update_choice_selection():
	var arrow = dialogue_box.get_node_or_null("SelectionArrow")
	var yes_label = dialogue_box.get_node_or_null("YesLabel")
	
	if arrow and yes_label:
		if selected_choice == 0:  # Yes selected
			arrow.position = Vector2(yes_label.position.x - 15, yes_label.position.y + 10)
		else:  # No selected
			var no_label = dialogue_box.get_node_or_null("NoLabel")
			if no_label:
				arrow.position = Vector2(no_label.position.x - 15, no_label.position.y + 10)

func handle_choice_selection():
	print("[NPC] Choice selected:", "Yes" if selected_choice == 0 else "No")
	
	if selected_choice == 0:  # Yes
		print("[NPC] Player accepted quest! Loading Farming Quest...")
		get_tree().change_scene_to_file("res://scenes/maps/FamingQuest.tscn")
	else:  # No
		print("[NPC] Player declined quest")
		end_dialogue()

func end_dialogue():
	print("[NPC] end_dialogue called")
	is_chatting = false
	showing_choice = false
	current_dialogue_index = 0
	selected_choice = 0
	
	if dialogue_box:
		dialogue_box.visible = false
		hide_choice_ui()
	
	if player:
		player.set_physics_process(true)
	
	print("[NPC] Dialogue ended, is_chatting set to:", is_chatting)

func _on_area_2d_body_entered(body: Node2D) -> void:
	print("[NPC] _on_area_2d_body_entered called, body:", body.name)
	if body.has_method("player"):
		player = body
		player_in_chat_zone = true
		print("[NPC] Player entered chat zone, player_in_chat_zone =", player_in_chat_zone)

func _on_area_2d_body_exited(body: Node2D) -> void:
	print("[NPC] _on_area_2d_body_exited called, body:", body.name)
	if body.has_method("player"):
		player_in_chat_zone = false
		player = null
		if is_chatting:
			print("[NPC] Player walked away during dialogue, ending dialogue")
			end_dialogue()
		print("[NPC] Player left chat zone, player_in_chat_zone =", player_in_chat_zone)
