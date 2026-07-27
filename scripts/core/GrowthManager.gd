extends Node

# This autoload manages all seed growth timers globally
# So they keep running even when you're in the storehouse

func _ready():
	print("[GROWTH_MANAGER] Started")

func _process(delta):
	# Process all seed growth timers
	for tile_pos in GameState.planted_seeds.keys():
		var seed_data = GameState.planted_seeds[tile_pos]
		
		# Update timer countdown
		if "time_until_growth" in seed_data:
			seed_data["time_until_growth"] -= delta
			
			# Check if it's time to grow
			if seed_data["time_until_growth"] <= 0:
				grow_seed(tile_pos)
				# Set new random timer
				seed_data["time_until_growth"] = randf_range(40.0, 60.0)

func grow_seed(tile_pos: Vector2i):
	if not GameState.planted_seeds.has(tile_pos):
		return
	
	var seed_data = GameState.planted_seeds[tile_pos]
	var current_stage = seed_data.get("growth_stage", 1)
	var seed_type = seed_data.get("seed_type", "unknown")
	
	# Determine next stage
	var next_stage = current_stage
	var max_stage = 4 if seed_type != "sunflower" else 3
	
	if current_stage < max_stage:
		next_stage = current_stage + 1
		
		# Check if harvest (3->4 for normal, 2->3 for sunflower)
		if (seed_type != "sunflower" and current_stage == 3) or \
		   (seed_type == "sunflower" and current_stage == 2):
			award_harvest_points(tile_pos, seed_type)
	else:
		# Alternate between max and max-1
		if current_stage == max_stage:
			next_stage = max_stage - 1
			# ONLY sunflower awards points on 3->2
			if seed_type == "sunflower":
				award_harvest_points(tile_pos, seed_type)
		else:
			next_stage = max_stage
			# Normal crops (not sunflower) award points on x->4
			if seed_type != "sunflower":
				award_harvest_points(tile_pos, seed_type)
	
	# Update stored stage
	seed_data["growth_stage"] = next_stage
	
	print("[GROWTH_MANAGER] Seed at ", tile_pos, " (", seed_type, ") grew from ", current_stage, " to ", next_stage)
	
	# Update visual if we're on the farm scene
	update_seed_visual(tile_pos)

func update_seed_visual(tile_pos: Vector2i):
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("update_seed_sprite"):
		current_scene.update_seed_sprite(tile_pos)


func award_harvest_points(tile_pos: Vector2i, seed_type: String):
	# Base points
	var crop_points = {
		"squash": 7, "greenbean": 6, "melon": 8, 
		"pineapple": 10, "pepper": 5, "lettuce": 6, "sunflower": 9
	}
	var points = crop_points.get(seed_type, 5)
	
	# Calculate synergy
	var synergy_bonus = calculate_synergy_bonus(tile_pos, seed_type)
	var total_points = points + synergy_bonus
	
	# Add to GameState
	GameState.player_points += total_points
	
	# Show notification globally
	var notif_system = get_node_or_null("/root/PointsNotifications")
	if notif_system and notif_system.has_method("show_points_notification"):
		notif_system.show_points_notification(total_points, seed_type.capitalize(), synergy_bonus)
	
	print("[GROWTH_MANAGER] HARVEST! ", seed_type, " +", total_points, " pts (", points, " base + ", synergy_bonus, " synergy)")

func calculate_synergy_bonus(tile_pos: Vector2i, seed_type: String) -> int:
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
	
	var total_bonus = 0
	var adjacent_positions = [
		Vector2i(tile_pos.x, tile_pos.y - 1), Vector2i(tile_pos.x, tile_pos.y + 1),
		Vector2i(tile_pos.x - 1, tile_pos.y), Vector2i(tile_pos.x + 1, tile_pos.y)
	]
	
	for adj_pos in adjacent_positions:
		if GameState.planted_seeds.has(adj_pos):
			var adj_type = GameState.planted_seeds[adj_pos].get("seed_type", "")
			
			# Check tier 3 (3 points)
			for pair in synergy_tier3:
				if (pair[0] == seed_type and pair[1] == adj_type) or (pair[0] == adj_type and pair[1] == seed_type):
					total_bonus += 3
					continue
			
			# Check tier 2 (2 points)
			for pair in synergy_tier2:
				if (pair[0] == seed_type and pair[1] == adj_type) or (pair[0] == adj_type and pair[1] == seed_type):
					total_bonus += 2
					continue
			
			# Check tier 1 (1 point)
			for pair in synergy_tier1:
				if (pair[0] == seed_type and pair[1] == adj_type) or (pair[0] == adj_type and pair[1] == seed_type):
					total_bonus += 1
					continue
	
	return total_bonus
