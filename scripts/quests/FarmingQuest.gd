extends Node2D

@onready var narrator = $Narrator
@onready var tilemap = $TileMap

# Load the player inventory directly from the resource file
var player_inventory: Inv = preload("res://inventory/playerinventory.tres")
var quest_completed: bool = false
var level_complete_ui: Node = null

# Seed item resources
@export var squash_seed: InvItem
@export var greenbean_seed: InvItem
@export var melon_seed: InvItem
@export var pineapple_seed: InvItem
@export var pepper_seed: InvItem
@export var lettuce_seed: InvItem
@export var sunflower_seed: InvItem

# Growth stage textures
@export_group("Squash Growth Stages")
@export var squash_stage2: Texture2D
@export var squash_stage3: Texture2D
@export var squash_stage4: Texture2D

@export_group("Green Bean Growth Stages")
@export var greenbean_stage2: Texture2D
@export var greenbean_stage3: Texture2D
@export var greenbean_stage4: Texture2D

@export_group("Melon Growth Stages")
@export var melon_stage2: Texture2D
@export var melon_stage3: Texture2D
@export var melon_stage4: Texture2D

@export_group("Pineapple Growth Stages")
@export var pineapple_stage2: Texture2D
@export var pineapple_stage3: Texture2D
@export var pineapple_stage4: Texture2D

@export_group("Pepper Growth Stages")
@export var pepper_stage2: Texture2D
@export var pepper_stage3: Texture2D
@export var pepper_stage4: Texture2D

@export_group("Lettuce Growth Stages")
@export var lettuce_stage2: Texture2D
@export var lettuce_stage3: Texture2D
@export var lettuce_stage4: Texture2D

@export_group("Sunflower Growth Stages")
@export var sunflower_stage2: Texture2D
@export var sunflower_stage3: Texture2D

@export var planted_seed_scene: PackedScene
@export var valid_farm_tile_ids: Array[int] = [4]
@export var tilemap_layer: int = 0

var has_received_seeds = false
var selected_inventory_slot = 0

# Game timer variables
var game_time_seconds = 0
var game_timer_running = false

# Base harvest points
var crop_base_points = {
	"squash": 7, "greenbean": 6, "melon": 8,
	"pineapple": 10, "pepper": 5, "lettuce": 6, "sunflower": 9
}

# Synergy bonuses
var synergy_tier1 = [
	["squash", "lettuce"], ["greenbean", "pepper"], ["melon", "sunflower"],
	["pineapple", "lettuce"], ["pepper", "sunflower"]
]
var synergy_tier2 = [
	["squash", "greenbean"], ["melon", "pepper"], ["pineapple", "sunflower"],
	["lettuce", "greenbean"], ["squash", "sunflower"]
]
var synergy_tier3 = [
	["squash", "pineapple"], ["greenbean", "melon"], ["pepper", "lettuce"],
	["melon", "lettuce"], ["pineapple", "pepper"]
]

func _ready():
	# Initialize game timer - ONLY reset if timer hasn't started yet
	if not GameState.game_timer_started:
		game_time_seconds = 30 * 60  # 30 minutes
		GameState.game_time_remaining = game_time_seconds
		GameState.game_timer_started = false
		GameState.selected_inventory_slot = 0
		game_timer_running = false
		
		# Show intro first time only
		if not GameState.has_seen_farm_intro:
			start_narrator_intro()
			GameState.has_seen_farm_intro = true
		
		# Start the timer for the first time
		start_game_timer()
		_apply_domain_bonuses()
	else:
		# Resume existing timer
		game_time_seconds = GameState.game_time_remaining
		game_timer_running = GameState.game_timer_started
		
		# Resume the timer
		var timer = get_node_or_null("CanvasLayer/GameTimer")
		if timer and game_timer_running:
			if not timer.timeout.is_connected(_on_game_timer_tick):
				timer.timeout.connect(_on_game_timer_tick)
			if timer.is_stopped():
				timer.start()
	
	update_game_timer_label()
	restore_planted_seeds()
	
	level_complete_ui = get_node_or_null("LevelCompleteUI")
	if level_complete_ui and level_complete_ui.has_signal("return_to_hub"):
		level_complete_ui.connect("return_to_hub", Callable(self, "_on_return_to_hub"))
		
func _process(delta):
	if Input.is_action_just_pressed("pickup"):
		try_place_seed()
	
	# Inventory selection
	if Input.is_action_just_pressed("A"):
		var new_slot = selected_inventory_slot - 1
		var current_row = selected_inventory_slot / 4
		var new_row = new_slot / 4
		if new_slot >= 0 and current_row == new_row:
			selected_inventory_slot = new_slot
			GameState.selected_inventory_slot = selected_inventory_slot  # Update global
			print("[FARM] Selected inventory slot: ", selected_inventory_slot)
	elif Input.is_action_just_pressed("D"):
		var new_slot = selected_inventory_slot + 1
		var current_row = selected_inventory_slot / 4
		var new_row = new_slot / 4
		if new_slot < player_inventory.slots.size() and current_row == new_row:
			selected_inventory_slot = new_slot
			GameState.selected_inventory_slot = selected_inventory_slot  # Update global
			print("[FARM] Selected inventory slot: ", selected_inventory_slot)
	elif Input.is_action_just_pressed("W"):
		var new_slot = selected_inventory_slot - 4
		if new_slot >= 0:
			selected_inventory_slot = new_slot
			GameState.selected_inventory_slot = selected_inventory_slot  # Update global
			print("[FARM] Selected inventory slot: ", selected_inventory_slot)
	elif Input.is_action_just_pressed("S"):
		var new_slot = selected_inventory_slot + 4
		if new_slot < player_inventory.slots.size():
			selected_inventory_slot = new_slot
			GameState.selected_inventory_slot = selected_inventory_slot  # Update global
			print("[FARM] Selected inventory slot: ", selected_inventory_slot)
func _apply_domain_bonuses():
	var bonuses = DomainInteractionManager.get_bonuses_for_domain("Farming")
	if bonuses.is_empty():
		return
	
	# Apply time extension
	if bonuses.has("time_extension"):
		var time_bonus = bonuses["time_extension"]
		var extra_time = int(game_time_seconds * time_bonus)
		game_time_seconds += extra_time
		GameState.game_time_remaining = game_time_seconds
		print("[FARM] Time bonus: +", extra_time, " seconds")
	
	# Show bonuses
	if narrator:
		var bonus_text = DomainInteractionManager.get_quest_bonus_summary("Farming")
		narrator.start_dialogue(["Domain Synergies Active!", bonus_text])
	
	LegacyAchievementManager.check_cross_domain_achievements(bonuses.size())
func update_inventory_selection():
	"""Notify the inventory UI to update the selection highlight"""
	# Try multiple methods to find the inventory UI
	var inv_ui = null
	
	# Method 1: Search entire tree
	inv_ui = get_tree().root.find_child("inv_ui", true, false)
	
	# Method 2: Try common paths
	if not inv_ui:
		inv_ui = get_node_or_null("/root/inv_ui")
	if not inv_ui:
		inv_ui = get_node_or_null("/root/FamingQuest/inv_ui")
	if not inv_ui:
		inv_ui = get_node_or_null("inv_ui")
	
	# Method 3: Search for any Control node with inv_ui script
	if not inv_ui:
		for node in get_tree().get_nodes_in_group("ui"):
			if node.name == "inv_ui" or "inv_ui" in node.get_script().resource_path if node.get_script() else false:
				inv_ui = node
				break
	
	# Method 4: Brute force search all nodes
	if not inv_ui:
		var all_nodes = get_tree().root.get_children()
		for node in all_nodes:
			var found = node.find_child("inv_ui", true, false)
			if found:
				inv_ui = found
				break
	
	if inv_ui:
		print("[FARM] Found inventory UI at:", inv_ui.get_path())
		if inv_ui.has_method("set_selected_slot"):
			inv_ui.set_selected_slot(selected_inventory_slot)
		elif "selected_slot" in inv_ui:
			inv_ui.selected_slot = selected_inventory_slot
			if inv_ui.has_method("update_selection_visual"):
				inv_ui.update_selection_visual()
	else:
		# As a last resort, set it directly on the inventory resource
		print("[FARM] Could not find inv_ui node in tree")
		# Try to signal the inventory to update
		if player_inventory and player_inventory.has_signal("update"):
			player_inventory.emit_signal("update")

func start_game_timer():
	print("[FARM] start_game_timer called")
	var timer = get_node_or_null("CanvasLayer/GameTimer")
	if timer:
		print("[FARM] Timer found")
		if not timer.timeout.is_connected(_on_game_timer_tick):
			timer.timeout.connect(_on_game_timer_tick)
		timer.start()
		game_timer_running = true
		GameState.game_timer_started = true
		update_game_timer_label()
	else:
		print("[FARM] ERROR: Timer not found at CanvasLayer/GameTimer")

func _on_game_timer_tick():
	if not game_timer_running:
		return
	
	game_time_seconds -= 1
	GameState.game_time_remaining = game_time_seconds
	update_game_timer_label()
	
	if game_time_seconds <= 0:
		game_time_seconds = 0
		GameState.game_time_remaining = 0
		game_timer_running = false
		GameState.game_timer_started = false
		
		var timer = get_node_or_null("CanvasLayer/GameTimer")
		if timer:
			timer.stop()
		
		trigger_game_end()

func update_game_timer_label():
	var label = get_node_or_null("CanvasLayer/GameTimerLabel")
	if not label:
		print("[FARM] ERROR: GameTimerLabel not found")
		return
	
	var minutes = game_time_seconds / 60
	var seconds = game_time_seconds % 60
	label.text = "%02d:%02d" % [minutes, seconds]

func trigger_game_end():
	print("[FARM] Game ended!")
	quest_completed = true
	
	var total_points = GameState.player_points
	
	# Disable player movement
	var player = get_node_or_null("player")
	if player:
		if player.has_method("set_can_move"):
			player.set_can_move(false)
		else:
			player.set_process(false)
			player.set_physics_process(false)
	
	# Show narrator dialogue first
	if narrator and narrator.has_method("start_dialogue"):
		narrator.start_dialogue([
			"Time has run out.",
			"The farming season has ended.",
			"You earned a total of " + str(total_points) + " points.",
			"The village will remember your efforts."
		])
		
		# Wait for narrator to be dismissed, then show completion UI
		if narrator.has_signal("dialogue_finished"):
			if not narrator.is_connected("dialogue_finished", Callable(self, "_on_narrator_finished_end_game")):
				narrator.connect("dialogue_finished", Callable(self, "_on_narrator_finished_end_game").bind(total_points), CONNECT_ONE_SHOT)
		else:
			# Fallback if no signal
			await get_tree().create_timer(4.0).timeout
			_show_farming_completion_ui(total_points)
	else:
		# No narrator, show UI immediately
		_show_farming_completion_ui(total_points)

func _on_narrator_finished_end_game(total_points: int) -> void:
	print("[FARM] Narrator dialogue dismissed, showing completion UI")
	_show_farming_completion_ui(total_points)

func _show_farming_completion_ui(total_points: int) -> void:
	if level_complete_ui and level_complete_ui.has_method("show_completion_with_points"):
		print("[FARM] Showing completion UI with points:", total_points)
		level_complete_ui.show_completion_with_points(total_points)
	else:
		print("[FARM] ERROR: level_complete_ui not found or missing show_completion_with_points method!")

func _on_return_to_hub():
	# Reset game state for next play
	GameState.game_time_remaining = 0
	GameState.game_timer_started = false
	GameState.has_seen_farm_intro = false
	GameState.player_points = 0
	
	# Clear planted seeds
	for tile_pos in GameState.planted_seeds.keys():
		var seed_data = GameState.planted_seeds[tile_pos]
		if seed_data.has("sprite") and is_instance_valid(seed_data["sprite"]):
			seed_data["sprite"].queue_free()
	GameState.planted_seeds.clear()
	
	# Return to main hub
	get_tree().change_scene_to_file("res://scenes/maps/FarmingHouse.tscn")
	
func try_place_seed():
	var player = get_node_or_null("player")
	if not player:
		print("[FARM] Player node not found")
		return
	
	if not tilemap:
		print("[FARM] Tilemap not found!")
		return
	
	var player_pos = player.global_position
	var tile_pos = tilemap.local_to_map(tilemap.to_local(player_pos))
	
	if not is_valid_farm_tile(tile_pos):
		print("[FARM] Cannot plant here! This is not a farm tile.")
		return
	
	if GameState.planted_seeds.has(tile_pos):
		print("[FARM] Already a seed planted here!")
		return
	
	var seed_to_plant = get_first_seed_from_inventory()
	if not seed_to_plant:
		print("[FARM] No seeds in inventory!")
		return
	
	player_inventory.remove(seed_to_plant.name, 1)
	place_seed_on_tile(tile_pos, seed_to_plant)
	print("[FARM] Planted ", seed_to_plant.name, " at tile position: ", tile_pos)

func is_valid_farm_tile(tile_pos: Vector2i) -> bool:
	var tile_atlas_coords = tilemap.get_cell_atlas_coords(tilemap_layer, tile_pos)
	
	if tile_atlas_coords == Vector2i(-1, -1):
		return false
	
	var source_id = tilemap.get_cell_source_id(tilemap_layer, tile_pos)
	var alternative_tile = tilemap.get_cell_alternative_tile(tilemap_layer, tile_pos)
	
	print("[FARM] Tile at ", tile_pos, " - Source ID: ", source_id, ", Atlas Coords: ", tile_atlas_coords, ", Alt: ", alternative_tile)
	
	if source_id in valid_farm_tile_ids:
		return true
	
	return false

func get_first_seed_from_inventory() -> InvItem:
	if selected_inventory_slot < 0 or selected_inventory_slot >= player_inventory.slots.size():
		print("[FARM] Invalid inventory slot selected")
		return null
	
	var slot = player_inventory.slots[selected_inventory_slot]
	if slot.item != null and slot.amount > 0:
		print("[FARM] Found item in slot ", selected_inventory_slot, ": ", slot.item.name)
		return slot.item
	else:
		print("[FARM] No item in selected slot ", selected_inventory_slot)
		return null

func place_seed_on_tile(tile_pos: Vector2i, seed: InvItem):
	var world_pos = tilemap.to_global(tilemap.map_to_local(tile_pos))
	
	print("[FARM] Planting seed with name: '", seed.name, "'")
	var seed_type_name = get_seed_base_name(seed.name)
	print("[FARM] Seed type resolved to: '", seed_type_name, "'")
	
	var initial_texture = seed.texture
	
	var seed_sprite = Sprite2D.new()
	seed_sprite.texture = initial_texture
	seed_sprite.global_position = world_pos
	
	if tilemap.tile_set and seed_sprite.texture:
		var tile_size = tilemap.tile_set.tile_size
		var scale_factor = min(tile_size.x * 0.8 / seed_sprite.texture.get_width(), 
							   tile_size.y * 0.8 / seed_sprite.texture.get_height())
		seed_sprite.scale = Vector2(scale_factor, scale_factor)
	
	add_child(seed_sprite)
	
	GameState.planted_seeds[tile_pos] = {
		"seed_type": seed_type_name,
		"sprite": seed_sprite,
		"growth_stage": 1,
		"stage1_texture_path": seed.texture.resource_path,
		"planted_time": Time.get_ticks_msec(),
		"time_until_growth": randf_range(40.0, 60.0)
	}
	
	print("[FARM] Planted ", seed_type_name, " at ", tile_pos)

func update_seed_sprite(tile_pos: Vector2i):
	if not GameState.planted_seeds.has(tile_pos):
		return
	
	var seed_data = GameState.planted_seeds[tile_pos]
	var stage = seed_data.get("growth_stage", 1)
	var seed_type = seed_data.get("seed_type", "unknown")
	var sprite = seed_data.get("sprite", null)
	
	if not sprite:
		return
	
	var new_texture = null
	if stage == 1:
		new_texture = load(seed_data.get("stage1_texture_path", ""))
	else:
		new_texture = get_growth_stage_texture(seed_type, stage)
	
	if new_texture and sprite:
		sprite.texture = new_texture
		
		if tilemap.tile_set:
			var tile_size = tilemap.tile_set.tile_size
			var scale_factor = min(tile_size.x * 0.8 / sprite.texture.get_width(), 
								   tile_size.y * 0.8 / sprite.texture.get_height())
			sprite.scale = Vector2(scale_factor, scale_factor)

func get_seed_base_name(full_name: String) -> String:
	var lower_name = full_name.to_lower()
	print("[FARM] Detecting seed type from name: '", full_name, "' (lowercase: '", lower_name, "')")
	
	if "squash" in lower_name:
		print("[FARM] Detected: squash")
		return "squash"
	elif "green" in lower_name or "bean" in lower_name:
		print("[FARM] Detected: greenbean")
		return "greenbean"
	elif "melon" in lower_name:
		print("[FARM] Detected: melon")
		return "melon"
	elif "pineapple" in lower_name:
		print("[FARM] Detected: pineapple")
		return "pineapple"
	elif "pepper" in lower_name:
		print("[FARM] Detected: pepper")
		return "pepper"
	elif "lettuce" in lower_name:
		print("[FARM] Detected: lettuce")
		return "lettuce"
	elif "sunflower" in lower_name:
		print("[FARM] Detected: sunflower")
		return "sunflower"
	
	print("[FARM] WARNING: Unknown seed type!")
	return "unknown"

func get_growth_stage_texture(seed_type: String, stage: int) -> Texture2D:
	match seed_type:
		"squash":
			match stage:
				2: return squash_stage2
				3: return squash_stage3
				4: return squash_stage4
		"greenbean":
			match stage:
				2: return greenbean_stage2
				3: return greenbean_stage3
				4: return greenbean_stage4
		"melon":
			match stage:
				2: return melon_stage2
				3: return melon_stage3
				4: return melon_stage4
		"pineapple":
			match stage:
				2: return pineapple_stage2
				3: return pineapple_stage3
				4: return pineapple_stage4
		"pepper":
			match stage:
				2: return pepper_stage2
				3: return pepper_stage3
				4: return pepper_stage4
		"lettuce":
			match stage:
				2: return lettuce_stage2
				3: return lettuce_stage3
				4: return lettuce_stage4
		"sunflower":
			match stage:
				2: return sunflower_stage2
				3: return sunflower_stage3
	return null

func _on_growth_tick():
	pass

func grow_seed(tile_pos: Vector2i):
	if not GameState.planted_seeds.has(tile_pos):
		return
		
	var seed_data = GameState.planted_seeds[tile_pos]
	var current_stage = seed_data["growth_stage"]
	var seed_type = seed_data["seed_type"]
	var sprite = seed_data["sprite"]
	var timer = seed_data["timer"]
	
	var next_stage = current_stage
	var max_stage = 4 if seed_type != "sunflower" else 3
	
	if current_stage < max_stage:
		next_stage = current_stage + 1
		
		if (seed_type != "sunflower" and current_stage == 3 and next_stage == 4):
			award_harvest_points(tile_pos, seed_type)
	else:
		if current_stage == max_stage:
			next_stage = max_stage - 1
			if seed_type == "sunflower":
				award_harvest_points(tile_pos, seed_type)
		else:
			next_stage = max_stage
			if seed_type != "sunflower":
				award_harvest_points(tile_pos, seed_type)
	
	var new_texture = null
	if next_stage == 1:
		new_texture = load(seed_data["stage1_texture_path"])
	else:
		new_texture = get_growth_stage_texture(seed_type, next_stage)
	
	if new_texture and sprite:
		sprite.texture = new_texture
		
		if tilemap.tile_set:
			var tile_size = tilemap.tile_set.tile_size
			var scale_factor = min(tile_size.x * 0.8 / sprite.texture.get_width(), 
								   tile_size.y * 0.8 / sprite.texture.get_height())
			sprite.scale = Vector2(scale_factor, scale_factor)
	
	seed_data["growth_stage"] = next_stage
	
	var new_wait_time = randf_range(40.0, 60.0)
	if timer:
		timer.wait_time = new_wait_time
		seed_data["next_growth_time"] = new_wait_time
	
	print("[FARM] Seed at ", tile_pos, " (", seed_type, ") grew from stage ", current_stage, " to ", next_stage, " - next growth in ", new_wait_time, " seconds")

func award_harvest_points(tile_pos: Vector2i, seed_type: String):
	var points = crop_base_points.get(seed_type, 5)
	var synergy_bonus = calculate_synergy_bonus(tile_pos, seed_type)
	var total_points = points + synergy_bonus
	
	var points_ui = get_node_or_null("CanvasLayer/PointsUI")
	if points_ui and points_ui.has_method("add_points"):
		points_ui.add_points(total_points)
	else:
		print("[FARM] ERROR: PointsUI not found at CanvasLayer/PointsUI")
	
	var notification_ui = get_node_or_null("PointsNotifications")
	if notification_ui and notification_ui.has_method("show_points_notification"):
		notification_ui.show_points_notification(total_points, seed_type.capitalize(), synergy_bonus)
		print("[FARM] Notification sent!")
	else:
		print("[FARM] ERROR: PointsNotifications not found!")
	
	print("[FARM] HARVEST! ", seed_type, " at ", tile_pos, " - Base: ", points, " + Synergy: ", synergy_bonus, " = Total: ", total_points, " points")

func calculate_synergy_bonus(tile_pos: Vector2i, seed_type: String) -> int:
	var total_bonus = 0
	
	var adjacent_positions = [
		Vector2i(tile_pos.x, tile_pos.y - 1),
		Vector2i(tile_pos.x, tile_pos.y + 1),
		Vector2i(tile_pos.x - 1, tile_pos.y),
		Vector2i(tile_pos.x + 1, tile_pos.y)
	]
	
	for adj_pos in adjacent_positions:
		if GameState.planted_seeds.has(adj_pos):
			var adjacent_seed = GameState.planted_seeds[adj_pos]
			var adjacent_type = adjacent_seed["seed_type"]
			
			var bonus = get_synergy_bonus(seed_type, adjacent_type)
			if bonus > 0:
				total_bonus += bonus
				print("[FARM]   Synergy: ", seed_type, " + ", adjacent_type, " = +", bonus, " points")
	
	return total_bonus

func get_synergy_bonus(crop1: String, crop2: String) -> int:
	for pair in synergy_tier3:
		if (pair[0] == crop1 and pair[1] == crop2) or (pair[0] == crop2 and pair[1] == crop1):
			return 3
	
	for pair in synergy_tier2:
		if (pair[0] == crop1 and pair[1] == crop2) or (pair[0] == crop2 and pair[1] == crop1):
			return 2
	
	for pair in synergy_tier1:
		if (pair[0] == crop1 and pair[1] == crop2) or (pair[0] == crop2 and pair[1] == crop1):
			return 1
	
	return 0

func restore_planted_seeds():
	print("[FARM] Restoring ", GameState.planted_seeds.size(), " planted seeds")
	for tile_pos in GameState.planted_seeds.keys():
		var seed_data = GameState.planted_seeds[tile_pos]
		
		print("[FARM] Restoring seed at ", tile_pos, " - Type: ", seed_data["seed_type"], ", Stage: ", seed_data.get("growth_stage", 1))
		
		var stage = seed_data.get("growth_stage", 1)
		var seed_type = seed_data["seed_type"]
		
		var texture = null
		if stage == 1:
			var texture_path = seed_data.get("stage1_texture_path", "")
			print("[FARM] Loading stage 1 texture from: ", texture_path)
			texture = load(texture_path)
		else:
			print("[FARM] Getting growth stage ", stage, " texture for ", seed_type)
			texture = get_growth_stage_texture(seed_type, stage)
		
		if not texture:
			print("[FARM] ERROR: Could not load texture for seed at ", tile_pos)
			continue
		
		var world_pos = tilemap.to_global(tilemap.map_to_local(tile_pos))
		
		var seed_sprite = Sprite2D.new()
		seed_sprite.texture = texture
		seed_sprite.global_position = world_pos
		
		if tilemap.tile_set and seed_sprite.texture:
			var tile_size = tilemap.tile_set.tile_size
			var scale_factor = min(tile_size.x * 0.8 / seed_sprite.texture.get_width(), 
								   tile_size.y * 0.8 / seed_sprite.texture.get_height())
			seed_sprite.scale = Vector2(scale_factor, scale_factor)
		
		add_child(seed_sprite)
		print("[FARM] Sprite added for seed at ", tile_pos)
		
		# Update sprite reference - GrowthManager will handle growth timing
		seed_data["sprite"] = seed_sprite
	
	print("[FARM] Finished restoring seeds")

func start_narrator_intro() -> void:
	if narrator and narrator.has_method("start_dialogue"):
		narrator.start_dialogue([
			"Welcome to the village farm. The land has been barren for too long.",
			"Your mission: Plant crops and earn points to revive the village.",
			"Press W, A, S, D to move around the farm.",
			"Visit the storehouse to collect your seeds.",
			"Press I to open your inventory and view your points.",
			"Use W, A, S, D to select different seeds in your inventory.",
			"Stand on a farm tile and press P to plant the selected seed.",
			"Your crops will grow over time through 4 stages.",
			"When crops reach stage 4, they are harvested and you earn points!",
			"Different crops are worth different amounts of points.",
			"IMPORTANT: Plant compatible crops next to each other for synergy bonuses!",
			"Adjacent crops can give you +1, +2, or even +3 bonus points per harvest.",
			"Experiment with different combinations to discover the best pairings.",
			"The more points you earn, the more you help restore the village.",
			"You have 30 minutes to accumulate as many points as possible.",
			"Good luck, farmer!"
		])

func give_seeds_to_player():
	if has_received_seeds:
		print("[FARM] Player already received seeds")
		return
	
	if not player_inventory:
		push_error("[FARM] Player inventory not found!")
		return
	
	var all_seeds = [
		greenbean_seed, squash_seed, sunflower_seed, 
		pepper_seed, lettuce_seed, melon_seed
	]
	
	all_seeds = all_seeds.filter(func(seed): return seed != null)
	
	if all_seeds.is_empty():
		push_error("[FARM] No seed items assigned in inspector!")
		return
	
	var seed_counts = {}
	for seed in all_seeds:
		seed_counts[seed] = 0
	
	var seeds_given = 0
	var max_attempts = 100
	var attempts = 0
	
	while seeds_given < 15 and attempts < max_attempts:
		attempts += 1
		
		var random_seed = all_seeds[randi() % all_seeds.size()]
		
		if seed_counts[random_seed] < 3:
			player_inventory.insert(random_seed)
			seed_counts[random_seed] += 1
			seeds_given += 1
			print("[FARM] Gave player 1x ", random_seed.name)
	
	has_received_seeds = true
	print("[FARM] Finished giving seeds. Total given: ", seeds_given)
	
	if narrator and narrator.has_method("start_dialogue"):
		narrator.start_dialogue([
			"You received 15 seeds!",
			"Check your inventory to see what you got."
		])

func start_storehouse_dialogue():
	var lines = [
		"You've entered the storehouse.",
		"This is where you keep your supplies."
	]
	narrator.start_dialogue(lines)

func trigger_dialogue(dialogue_lines: Array):
	narrator.start_dialogue(dialogue_lines)
