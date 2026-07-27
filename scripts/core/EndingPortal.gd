# EndingPortal.gd
# FIXED - Removed persistent black screen bug
# Place this in your MainHub scene

extends Area2D

@export var portal_sprite: Sprite2D
@export var prompt_label: Label
@export var particle_effect: GPUParticles2D

var player_nearby: bool = false
var portal_active: bool = false

func _ready():
	print("[EndingPortal] ========== INITIALIZING ==========")
	print("[EndingPortal] Scene tree path: ", get_path())
	
	# Create visuals if not set in scene
	if not portal_sprite:
		_create_portal_visual()
	
	if not prompt_label:
		_create_prompt_label()
	
	# Connect signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Check if portal should be active
	_update_portal_state()
	
	# Connect to quest completion signal
	if EndingManager:
		if not EndingManager.all_quests_completed.is_connected(_on_all_quests_completed):
			EndingManager.all_quests_completed.connect(_on_all_quests_completed)
		print("[EndingPortal] Connected to EndingManager signals")
	else:
		print("[EndingPortal] WARNING: EndingManager not found!")
	
	print("[EndingPortal] ========== INITIALIZATION COMPLETE ==========")

func _create_portal_visual():
	# Create a glowing portal sprite
	portal_sprite = Sprite2D.new()
	portal_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0) # Start invisible
	add_child(portal_sprite)
	
	# Create glowing circle visual
	var circle = ColorRect.new()
	circle.custom_minimum_size = Vector2(80, 80)
	circle.color = Color(0.5, 0.8, 1.0, 0.9) # Light blue glow
	circle.position = Vector2(-40, -40)
	portal_sprite.add_child(circle)
	
	print("[EndingPortal] Created portal visual")

func _create_prompt_label():
	# Create prompt that appears above portal
	prompt_label = Label.new()
	prompt_label.text = "[Press E or SPACE to view ending]"
	prompt_label.position = Vector2(-80, -100)
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.modulate.a = 0 # Start invisible
	add_child(prompt_label)
	
	print("[EndingPortal] Created prompt label")

func _update_portal_state():
	portal_active = EndingManager.check_all_quests_complete()
	
	print("[EndingPortal] Checking portal state...")
	print("[EndingPortal] All quests complete: ", portal_active)
	
	if portal_active:
		_activate_portal()
	else:
		_deactivate_portal()

func _activate_portal():
	print("[EndingPortal] ===== ACTIVATING PORTAL =====")
	portal_active = true
	
	# Animate portal appearing
	if portal_sprite:
		var tween = create_tween()
		tween.tween_property(portal_sprite, "modulate:a", 1.0, 2.0)
		
		# Pulsing glow effect (loops forever)
		tween.finished.connect(_start_pulse_animation)
	
	# Show particle effect if available
	if particle_effect:
		particle_effect.emitting = true
	
	print("[EndingPortal] Portal is now active and glowing")

func _start_pulse_animation():
	# Continuous pulsing
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(portal_sprite, "modulate:a", 0.7, 1.0)
	tween.tween_property(portal_sprite, "modulate:a", 1.0, 1.0)

func _deactivate_portal():
	print("[EndingPortal] Portal deactivated (quests incomplete)")
	portal_active = false
	
	if portal_sprite:
		portal_sprite.modulate.a = 0.3 # Semi-visible but not active
	
	if particle_effect:
		particle_effect.emitting = false

func _on_all_quests_completed():
	print("[EndingPortal] Received all_quests_completed signal!")
	_activate_portal()

func _on_body_entered(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		player_nearby = true
		print("[EndingPortal] Player entered portal area")
		
		if portal_active and prompt_label:
			# Show prompt
			var tween = create_tween()
			tween.tween_property(prompt_label, "modulate:a", 1.0, 0.3)
			print("[EndingPortal] Showing 'Press E' prompt")

func _on_body_exited(body):
	if body.name.to_lower() == "player" or body.has_method("player"):
		player_nearby = false
		print("[EndingPortal] Player left portal area")
		
		if prompt_label:
			# Hide prompt
			var tween = create_tween()
			tween.tween_property(prompt_label, "modulate:a", 0.0, 0.3)

func _process(delta):
	# Check for interaction
	if player_nearby and portal_active:
		if Input.is_action_just_pressed("ui_text_delete"): # E key
			print("[EndingPortal] E key pressed - triggering ending")
			_trigger_ending()
		elif Input.is_action_just_pressed("ui_accept"): # SPACE
			print("[EndingPortal] SPACE pressed - triggering ending")
			_trigger_ending()

func _trigger_ending():
	print("[EndingPortal] ========================================")
	print("[EndingPortal] ===== TRIGGERING ENDING SEQUENCE =====")
	print("[EndingPortal] ========================================")
	
	# Disable player movement IMMEDIATELY
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Try alternate methods to find player
		player = get_node_or_null("/root/MainHub/player")
		if not player:
			player = get_node_or_null("../player")
	
	if player:
		print("[EndingPortal] Found player, freezing movement")
		player.set_process(false)
		player.set_physics_process(false)
		if player.has_method("set_can_move"):
			player.set_can_move(false)
	else:
		print("[EndingPortal] WARNING: Could not find player to freeze")
	
	# Create full-screen fade overlay using CanvasLayer
	print("[EndingPortal] Creating fade overlay...")
	
	var canvas = CanvasLayer.new()
	canvas.layer = 1000 # Very high layer to be on top
	canvas.name = "FadeCanvas"
	
	# === THE FIX IS HERE ===
	# OLD CODE: get_tree().root.add_child(canvas)
	# This caused the black screen to persist forever because 'root' children aren't removed on scene change.
	
	# NEW CODE: Add to self (EndingPortal)
	# This ensures the black screen is destroyed when MainHub is unloaded,
	# revealing the EndingCutscene (which handles its own fade-in).
	add_child(canvas)
	
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0) # Start transparent
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.name = "FadeOverlay"
	canvas.add_child(fade)
	
	print("[EndingPortal] Fade overlay created, starting fade...")
	
	# Fade to black
	var tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.5)
	
	await tween.finished
	
	print("[EndingPortal] Fade complete!")
	print("[EndingPortal] Attempting to change scene...")
	print("[EndingPortal] Target scene: res://scenes/ending/EndingCutscene.tscn")
	
	# Verify scene exists before changing
	var scene_path = "res://scenes/ending/EndingCutscene.tscn"
	var scene_exists = FileAccess.file_exists(scene_path)
	var resource_exists = ResourceLoader.exists(scene_path)
	
	print("[EndingPortal] Scene file exists: ", scene_exists)
	print("[EndingPortal] ResourceLoader can load: ", resource_exists)
	
	if not scene_exists or not resource_exists:
		print("[EndingPortal] CRITICAL ERROR: Ending scene not found at " + scene_path)
		return
		
	var result = get_tree().change_scene_to_file(scene_path)
	print("[EndingPortal] Scene change result code: ", result)
	
	if result != OK:
		print("[EndingPortal] ERROR: Failed to change scene (Error code: ", result, ")")
