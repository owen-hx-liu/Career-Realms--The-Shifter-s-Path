extends CharacterBody2D

const speed = 30
var is_chatting = false
var player = null
var player_in_chat_zone = false

# Dialogue system
var current_dialogue_index = 0
var dialogues = [
	{"name": "Warehouse Keeper", "text": "Welcome to the storehouse!"}, 
	{"name": "Warehouse Keeper", "text": "You want some seeds?"}, 
	{"name": "Warehouse Keeper", "text": "Here, take some of these seeds"}, 
	{"name": "Warehouse Keeper", "text": "Make sure to plant them to earn the synergy bonus"}, 
	{"name": "Warehouse Keeper", "text": "Good luck!"}
]

# Reference to the dialogue UI
@export var dialogue_box_scene: PackedScene
var dialogue_box = null

# Load the player inventory directly from the resource file
var player_inventory: Inv = preload("res://inventory/playerinventory.tres")

# Seed item resources - assign these in the Inspector
@export var squash_seed: InvItem
@export var greenbean_seed: InvItem
@export var melon_seed: InvItem
@export var pineapple_seed: InvItem
@export var pepper_seed: InvItem
@export var lettuce_seed: InvItem
@export var sunflower_seed: InvItem

var has_given_seeds = false

func _ready():
	# Safety check - wait for node to be in tree
	if not is_inside_tree():
		await tree_entered
	
	print("[NPC] ========== _ready START ==========")
	
	# Try to initialize dialogue box, but don't fail if scene changes during setup
	if dialogue_box_scene:
		await _initialize_dialogue_box()
	else:
		print("[NPC] ERROR: dialogue_box_scene NOT ASSIGNED in inspector!")
	
	print("[NPC] ========== _ready END ==========")
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
	
	# Check if dialogue box exists, if not, try to create it
	if not dialogue_box or not is_instance_valid(dialogue_box):
		print("[NPC] Dialogue box not ready, attempting to initialize...")
		if dialogue_box_scene:
			await _initialize_dialogue_box()
		else:
			print("[NPC] ERROR: Cannot create dialogue - dialogue_box_scene not assigned!")
			return
	
	# Final check
	if not dialogue_box or not is_instance_valid(dialogue_box):
		print("[NPC] ERROR: Failed to initialize dialogue box!")
		return
	
	is_chatting = true
	current_dialogue_index = 0
	show_dialogue()
	
	if player:
		player.set_physics_process(false)
		print("[NPC] Disabled player movement")

func _initialize_dialogue_box():
	"""Create the dialogue box if it doesn't exist"""
	if not is_inside_tree():
		print("[NPC] Not in tree, cannot initialize dialogue box")
		return
	
	dialogue_box = dialogue_box_scene.instantiate()
	
	var canvas_layer = get_tree().current_scene.get_node_or_null("DialogueCanvasLayer")
	
	if not canvas_layer:
		canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100
		canvas_layer.name = "DialogueCanvasLayer"
		get_tree().current_scene.add_child(canvas_layer)
		print("[NPC] Created new DialogueCanvasLayer")
	else:
		print("[NPC] Reusing existing DialogueCanvasLayer")
	
	canvas_layer.add_child(dialogue_box)
	dialogue_box.visible = false
	
	print("[NPC] Dialogue box initialized successfully")

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
	
	# Safety checks
	if not is_inside_tree():
		print("[NPC] ERROR: NPC not in tree!")
		return
	
	if not dialogue_box or not is_instance_valid(dialogue_box):
		print("[NPC] ERROR: dialogue_box is NULL or invalid!")
		return
	
	if not dialogue_box.is_inside_tree():
		print("[NPC] ERROR: dialogue_box not in tree!")
		return
	
	dialogue_box.visible = true
	dialogue_box.z_index = 1000
	
	# Get viewport size to position relative to screen
	var viewport_size = get_viewport_rect().size
	print("[NPC] Viewport size:", viewport_size)
	
	var sprite = dialogue_box.get_node_or_null("Sprite2D")
	if sprite:
		# Position at bottom center of screen
		sprite.position = Vector2(viewport_size.x / 3, viewport_size.y - 325)
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
		# Position relative to viewport bottom
		name_label.position = Vector2(viewport_size.x / 3 - 130, viewport_size.y - 365)
		name_label.scale = Vector2(1, 1)
		name_label.size = Vector2(110, 12)
		name_label.add_theme_font_size_override("normal_font_size", 20)
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
		# Position relative to viewport bottom
		text_label.position = Vector2(viewport_size.x / 3 - 130, viewport_size.y - 342)
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
	
	print("[NPC] ========== show_dialogue END ==========")
	print("")

func end_dialogue():
	print("[NPC] end_dialogue called")
	is_chatting = false
	current_dialogue_index = 0
	
	if dialogue_box and is_instance_valid(dialogue_box):
		dialogue_box.visible = false
	
	if player and is_instance_valid(player):
		player.set_physics_process(true)
	
	# Give seeds to player after dialogue ends
	give_seeds_to_player()
	
	print("[NPC] Dialogue ended, is_chatting set to:", is_chatting)

func give_seeds_to_player():
	if has_given_seeds:
		print("[NPC] Player already received seeds")
		return
	
	if not player_inventory:
		push_error("[NPC] Player inventory not found!")
		return
	
	# Array of all seed types
	var all_seeds = [
		squash_seed, greenbean_seed, melon_seed, pineapple_seed, 
		pepper_seed, lettuce_seed, sunflower_seed
	]
	
	# Filter out any null seeds (in case you haven't assigned all of them yet)
	all_seeds = all_seeds.filter(func(seed): return seed != null)
	
	if all_seeds.is_empty():
		push_error("[NPC] No seed items assigned in inspector!")
		return
	
	# Track how many of each seed we've given
	var seed_counts = {}
	for seed in all_seeds:
		seed_counts[seed] = 0
	
	# Give 15 random seeds (max 3 of each type)
	var seeds_given = 0
	var max_attempts = 100  # Prevent infinite loop
	var attempts = 0
	
	while seeds_given < 15 and attempts < max_attempts:
		attempts += 1
		
		# Pick a random seed
		var random_seed = all_seeds[randi() % all_seeds.size()]
		
		# Check if we can still give this seed type (max 3)
		if seed_counts[random_seed] < 3:
			player_inventory.insert(random_seed)
			seed_counts[random_seed] += 1
			seeds_given += 1
			print("[NPC] Gave player 1x ", random_seed.name)
	
	has_given_seeds = true
	print("[NPC] Finished giving seeds. Total given: ", seeds_given)

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
