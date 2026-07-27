extends Node

var current_scene = "World"
# Set true by the intro cutscene so the MainHub plays its one-time welcome
# tutorial on the first arrival (and never when returning from a house).
var show_hub_tutorial: bool = false

# --- DYSON SWARM QUEST RESULTS (Engineering) ---
# Written by scenes/dyson_swarm.gd when the mission ends so the hub /
# EndingManager can read how the player did.
var dyson_stars: int = 0
var dyson_energy: float = 0.0
var transition_scene = false
var transition_scene2 = false
var transition_scene3 = false
var transition_scene4 = false
var transition_scene5 = false
var transition_scene6 = false
signal temp_alert(status: String) 
signal weather_changed(weather_name: String)
# NEW: Specifically tells objects if the machine is broken or fixed
signal breakdown_changed(is_broken: bool) 

# --- BARN QUEST CORE ---
var quest_active: bool = false
var current_temp: float = 72.0
var weather_temp: float = 72.0
var weather_timer: float = 0.0
var current_status = "good"

var next_scene_path = ""
var next_player_x = 20
var next_player_y = 20
var scene_transition_cooldown: float = 0.0
var player_spawn_position = Vector2(0, 0)
var narrator_shown := false
var next_player_x2 = 599
var next_player_y2 = 1560

var healed_villagers: Dictionary = {}
var healing_attempts: Dictionary = {}
var collected_resources: Dictionary = {}
var score: float = 500.0
var max_score: float = 500.0
var game_timer: float = 300.0 # 5 Minutes
var game_over: bool = false

# HVAC & BREAKDOWN SYSTEM
var fan_states: Array = [0, 0, 0] 
var system_broken: bool = false
var break_timer: float = 30.0 
var break_chance: float = 0.85
# Star pedestal system - stores full metadata (domain and color)
var pedestal_stars: Dictionary = {}
var weather_types = {
	"Sunny": 90.0,
	"Blizzard": 10.0,
	"Rainy": 55.0,
	"Heatwave": 115.0,
	"Normal": 72.0
}
var barn_animals = [
	{"name": "cow",   "min": 52.0, "max": 83.0, "happy": true},
	{"name": "sheep",   "min": 57.0, "max": 80.0, "happy": true},
	{"name": "calf", "min": 53.0, "max": 90.0, "happy": true},
	{"name": "cow2",  "min": 52.0, "max": 83.0, "happy": true},
	{"name": "sheep2", "min": 57.0, "max": 80.0, "happy": true},
	{"name": "calf2", "min": 53.0, "max": 90.0, "happy": true}
]

func _ready():
	print("[Global] ========== GLOBAL STARTUP ==========")
	
	# FORCE DELETE pedestal save file to clear old data
	var save_path = "user://game_data.save"
	if FileAccess.file_exists(save_path):
		print("[Global] Deleting game_data.save...")
		DirAccess.remove_absolute(save_path)
		print("[Global] game_data.save deleted")
	
	# Clear pedestal data
	pedestal_stars.clear()
	print("[Global] Pedestal stars cleared: ", pedestal_stars.size())
	
	# Don't load old data (commented out to start fresh)
	# load_game_data()
	
	print("[Global] ====================================")

# Villager healing system
func mark_villager_healed(villager_name: String):
	healed_villagers[villager_name] = true
	save_game_data()

func is_villager_healed(villager_name: String) -> bool:
	return healed_villagers.get(villager_name, false)

func mark_healing_attempt(villager_name: String):
	healing_attempts[villager_name] = true
	save_game_data()

func has_attempted_healing(villager_name: String) -> bool:
	return healing_attempts.get(villager_name, false)

# Resource collection system
func mark_resource_collected(resource_id: String):
	collected_resources[resource_id] = true
	save_game_data()

func is_resource_collected(resource_id: String) -> bool:
	return collected_resources.get(resource_id, false)

# Narrator system
func mark_narrator_shown():
	narrator_shown = true
	save_game_data()
func start_barn_quest():
	quest_active = true
	current_temp = 72.0
	system_broken = false
	break_timer = 30.0
	# Reset the warning sign just in case
	breakdown_changed.emit(false) 
	randomize() 
	change_weather()
	print("Barn quest started!")
	
func stop_barn_quest():
	quest_active = false
	print("Barn quest stopped!")
	
func has_narrator_been_shown() -> bool:
	return narrator_shown

# Pedestal star system - with full metadata support
func mark_pedestal_has_star(pedestal_id: String, domain: String = "", color: Color = Color.WHITE):
	"""Mark that a pedestal has a star with domain and color information"""
	print("\n[Global] >>> Marking pedestal with star")
	print("[Global] Pedestal ID: ", pedestal_id)
	print("[Global] Domain: ", domain)
	print("[Global] Color: ", color)
	
	pedestal_stars[pedestal_id] = {
		"has_star": true,
		"domain": domain,
		"color": color
	}
	
	print("[Global] Total pedestals with stars: ", pedestal_stars.size())
	print("[Global] <<< Mark complete\n")
	
	# Auto-save after marking
	save_game_data()

func does_pedestal_have_star(pedestal_id: String) -> bool:
	"""Check if a pedestal has a star (backwards compatibility)"""
	return pedestal_stars.has(pedestal_id) and pedestal_stars[pedestal_id].get("has_star", false)

func get_pedestal_star_data(pedestal_id: String) -> Dictionary:
	"""Get full star data for a pedestal including domain and color"""
	if pedestal_stars.has(pedestal_id):
		return pedestal_stars[pedestal_id]
	return {}

func remove_pedestal_star(pedestal_id: String):
	"""Remove a star from a pedestal"""
	print("\n[Global] >>> Removing star from pedestal")
	print("[Global] Pedestal ID: ", pedestal_id)
	
	if pedestal_stars.has(pedestal_id):
		pedestal_stars.erase(pedestal_id)
		print("[Global] Star removed")
		save_game_data()
	else:
		print("[Global] Pedestal not found in saved data")
	
	print("[Global] Total pedestals with stars: ", pedestal_stars.size())
	print("[Global] <<< Remove complete\n")

func clear_all_pedestal_stars():
	"""Clear all pedestal stars - useful for debugging"""
	print("[Global] ==================== CLEARING ALL PEDESTAL STARS ====================")
	print("[Global] Before clear: ", pedestal_stars.size(), " pedestals")
	pedestal_stars.clear()
	print("[Global] After clear: ", pedestal_stars.size(), " pedestals")
	print("[Global] ====================================================================")
	save_game_data()
func get_total_pedestals_with_stars(domain: String) -> int:
	var count := 0
	
	for pedestal_id in pedestal_stars:
		var data = pedestal_stars[pedestal_id]
		if data.get("has_star", false) and data.get("domain", "") == domain:
			count += 1
	
	return count

func debug_print_pedestal_stars():
	"""Debug function to print all stored pedestal stars"""
	print("\n[Global] ==================== PEDESTAL STARS DEBUG ====================")
	print("[Global] Total pedestals: ", pedestal_stars.size())
	for pedestal_id in pedestal_stars:
		var data = pedestal_stars[pedestal_id]
		print("[Global] Pedestal: ", pedestal_id)
		print("  - Has star: ", data.get("has_star", false))
		print("  - Domain: ", data.get("domain", "UNKNOWN"))
		print("  - Color: ", data.get("color", "UNKNOWN"))
	print("[Global] ================================================================\n")

# Scene transition system
func finish_changescenes():
	if transition_scene == true:
		transition_scene = false
		if current_scene == "MainHub":
			current_scene = "EngineeringHouse"
		elif current_scene == "EngineeringHouse":
			current_scene = "MainHub"
		else:
			current_scene = "AncientEgyptMap"
	
	if transition_scene2 == true:
		transition_scene2 = false
		if current_scene == "MainHub":
			current_scene = "FarmingHouse"
		elif current_scene == "FarmingHouse":
			current_scene = "MainHub"
	
	if transition_scene3 == true:
		transition_scene3 = false
		if current_scene == "MainHub":
			current_scene = "Starcontainerroom2"
		elif current_scene == "Starcontainerroom2":
			current_scene = "MainHub"
	
	if transition_scene4 == true:
		transition_scene4 = false
		if current_scene == "MainHub":
			current_scene = "ArtHouse"
		elif current_scene == "ArtHouse":
			current_scene = "MainHub"

# Camera system
func update_camera():
	var root = get_tree().get_current_scene()
	var player = root.get_node_or_null("player")
	if not player:
		return
	
	print("Current scene is:", current_scene)
	
	if current_scene == "World":
		if player.has_node("worldcamera"):
			player.get_node("worldcamera").enabled = true
		if player.has_node("housecamera"):
			player.get_node("housecamera").enabled = false
	elif current_scene.begins_with("house") or current_scene == "EngineeringHouse":
		if player.has_node("worldcamera"):
			player.get_node("worldcamera").enabled = false
		if player.has_node("housecamera"):
			player.get_node("housecamera").enabled = true

# Save and load system
func save_game_data():
	var save_data = {
		"healed_villagers": healed_villagers,
		"healing_attempts": healing_attempts,
		"collected_resources": collected_resources,
		"narrator_shown": narrator_shown,
		"pedestal_stars": pedestal_stars
	}
	
	var file = FileAccess.open("user://game_data.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("[Global] Game data saved - Pedestals: ", pedestal_stars.size())

func load_game_data():
	if FileAccess.file_exists("user://game_data.save"):
		var file = FileAccess.open("user://game_data.save", FileAccess.READ)
		if file:
			var save_data = file.get_var()
			healed_villagers = save_data.get("healed_villagers", {})
			healing_attempts = save_data.get("healing_attempts", {})
			collected_resources = save_data.get("collected_resources", {})
			narrator_shown = save_data.get("narrator_shown", false)
			pedestal_stars = save_data.get("pedestal_stars", {})
			file.close()
			print("[Global] Game data loaded - Pedestals: ", pedestal_stars.size())
func _process(delta):
	if not quest_active or game_over: return
	
	# 1. Update Timer
	game_timer -= delta
	if game_timer <= 0:
		_end_game()

	# 2. Update Animal Happiness & Score
	var unhappy_count = 0
	
	for animal in barn_animals:
		# Check the temp against this specific animal's limits
		if current_temp >= animal.min and current_temp <= animal.max:
			animal.happy = true
		else:
			animal.happy = false
			unhappy_count += 1
	
	# 3. Calculate Score Deduction
	# Rule: 1 point per 2 seconds (0.5 points per second) per unhappy animal
	if unhappy_count > 0:
		var deduction = (0.5 * delta) * unhappy_count
		score -= deduction
		if score < 0: score = 0
	if not quest_active:
		return 

	# 1. Weather Timer
	weather_timer -= delta
	if weather_timer <= 0:
		change_weather()

	# 2. Breakdown Timer
	if not system_broken:
		break_timer -= delta
		if break_timer <= 0:
			_roll_for_breakdown()
			break_timer = 30.0 

	# 3. Physics & Temperature
	_update_temperature(delta)

func change_weather():
	var keys = weather_types.keys()
	var new_weather = keys[randi() % keys.size()]
	weather_temp = weather_types[new_weather]
	weather_timer = randf_range(15.0, 30.0) 
	
	weather_changed.emit(new_weather)
	print("New Weather: ", new_weather, " Target: ", weather_temp)

func _roll_for_breakdown():
	if randf() < break_chance:
		system_broken = true
		
		# UPDATE: Alert the warning sign!
		breakdown_changed.emit(true) 
		temp_alert.emit("broken")
		print("SYSTEM FAILURE: Repairs needed in Control Room!")

func fix_system():
	system_broken = false
	break_timer = 30.0 
	
	# UPDATE: Turn off the warning sign!
	breakdown_changed.emit(false) 
	print("System Repaired.")

func _update_temperature(delta):
	var weather_diff = weather_temp - current_temp
	var insulation_factor = 0.15 
	var weather_change = weather_diff * insulation_factor * delta
	
	var temp_gap = abs(weather_diff)
	var efficiency = clamp(1.0 - (temp_gap * 0.01), 0.2, 1.0)
	
	var hvac_power = 0.0
	var fan_base_strength = 5.5
	
	for state in fan_states:
		if state == 1:
			hvac_power += (fan_base_strength * efficiency) * delta 
		elif state == -1:
			hvac_power -= (fan_base_strength * efficiency) * delta 
			
	if not system_broken:
		current_temp += weather_change + hvac_power
	else:
		current_temp = lerp(current_temp, weather_temp, 0.4 * delta)

	var new_status = "good"
	if system_broken: 
		new_status = "broken"
	elif current_temp > 85.0: 
		new_status = "hot"
	elif current_temp < 52.0: 
		new_status = "cold"
	
	if new_status != current_status:
		current_status = new_status
		temp_alert.emit(current_status)
		
func _end_game():
	game_over = true
	print("Game Over! Final Score: ", int(score))
	quest_active = false
