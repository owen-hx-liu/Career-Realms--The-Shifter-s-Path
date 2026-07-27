extends CharacterBody2D

const speed = 30
var is_chatting = false
var player = null
var player_in_chat_zone = false

# Dialogue system
var current_dialogue_index = 0
var dialogues = [
	{"name": "Librarian", "text": "Hi there! How can I help you?"},
	{"name": "Librarian", "text": "You want to place your stars?"},
	{"name": "Librarian", "text": "Go through that door to access the Star Lock Room."},
	{"name": "Librarian", "text": "Good luck Traveler!"}
]

# Reference to the dialogue UI
@export var dialogue_box_scene: PackedScene
var dialogue_box = null

var has_given_seeds = false

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
		
		# THIS IS THE KEY - use current_scene and call_deferred!
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
		
		print("[NPC] ========== _ready END ==========")
	else:
		print("[NPC] ERROR: dialogue_box_scene NOT ASSIGNED in inspector!")
	print("")

func _process(delta):
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("idle")
	
	# Normal dialogue progression
	if player_in_chat_zone and Input.is_action_just_pressed("chat"):
		print("[NPC] Chat button pressed! is_chatting:", is_chatting)
		if not is_chatting:
			start_dialogue()
		else:
			next_dialogue()

func start_dialogue():
	print("[NPC] start_dialogue called")
	is_chatting = true
	current_dialogue_index = 0
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
		end_dialogue()

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
		sprite.position = Vector2(215, 325)
		sprite.scale = Vector2(0.2, 0.1)
		sprite.visible = true
		sprite.z_index = 0
		print("[NPC] Sprite positioned at:", sprite.position)
	
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
		name_label.position = Vector2(85, 285)
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
		text_label.position = Vector2(85, 305)
		text_label.scale = Vector2(1, 1)
		text_label.size = Vector2(225, 70)
		text_label.add_theme_font_size_override("normal_font_size", 15)
		text_label.add_theme_color_override("default_color", Color(0.2, 0.1, 0.05, 1))
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.fit_content = true
		text_label.scroll_active = false
		text_label.scroll_following = false
		text_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		text_label.clip_contents = false
		
		print("[NPC]   text_label POSITION:", text_label.position, "SCALE:", text_label.scale)
	
	print("[NPC] ========== show_dialogue END ==========")
	print("")

func end_dialogue():
	print("[NPC] end_dialogue called")
	is_chatting = false
	current_dialogue_index = 0
	
	if dialogue_box:
		dialogue_box.visible = false
	
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
