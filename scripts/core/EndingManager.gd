# EndingManager.gd
# AUTOLOAD SINGLETON - Add to Project Settings → Autoload
# Path: res://scripts/core/EndingManager.gd
# Name: EndingManager

extends Node

# Quest completion tracking
var completed_quests: Dictionary = {}

# Quest definitions - EASY TO ADD NEW QUESTS HERE
const QUEST_DEFINITIONS = {
	"Engineering": [
		{"id": "flood_egypt_1", "name": "Ancient Egypt Irrigation", "scene": "res://scenes/maps/AncientEgyptMap.tscn"},
		{"id": "engineering_quest_2", "name": "Dyson Swarm", "scene": "res://scenes/dyson_swarm.tscn"},
		{"id": "engineering_quest_3", "name": "Engineering Quest 3", "scene": ""}   # TODO: Add when ready
	],
	"Farming": [
		{"id": "village_farming", "name": "Village Farm Revival", "scene": "res://scenes/maps/FamingQuest.tscn"},
		{"id": "farming_quest_2", "name": "Farming Quest 2", "scene": ""},  # TODO: Add when ready
		{"id": "farming_quest_3", "name": "Farming Quest 3", "scene": ""}   # TODO: Add when ready
	],
	"Leadership": [
		{"id": "leadership_quest_1", "name": "Leadership Quest 1", "scene": "res://scenes/World.tscn"},
		{"id": "leadership_quest_2", "name": "Leadership Quest 2", "scene": "res://scenes/World2.tscn"},
		{"id": "leadership_quest_3", "name": "Leadership Quest 3", "scene": ""}   # TODO: Add when ready
	],
	"Medicine": [
		{"id": "forest_quest", "name": "Forest Healing", "scene": "res://scenes/world_scenes/forest.tscn"},
		{"id": "medicine_quest_2", "name": "Alien Gene Splicing", "scene": "res://scenes/world_scenes/AlienBioengineeringQuest.tscn"},
		{"id": "medicine_quest_3", "name": "Nanobot Surgeon", "scene": "res://scenes/nanobot_quest.tscn"}
	],
	"Art": [
		{"id": "laser_quest", "name": "Prism Array", "scene": "res://scenes/laser_quest.tscn"},
		{"id": "art_quest_2", "name": "Art Quest 2", "scene": ""},  # TODO: Add when ready
		{"id": "art_quest_3", "name": "Art Quest 3", "scene": ""}   # TODO: Add when ready
	]
}

# Ending thresholds (based on total stars)
const ENDING_THRESHOLDS = {
	"perfect": 75,      # All stars (5 domains × 3 quests × 5 stars)
	"excellent": 60,    # 80% of stars
	"good": 45,         # 60% of stars
	"decent": 30,       # 40% of stars
	"poor": 15          # 20% of stars
}

signal quest_completed(quest_id: String, domain: String)
signal all_quests_completed()

func _ready():
	print("[EndingManager] Initialized")
	load_progress()

# Mark a quest as completed
func complete_quest(quest_id: String, domain: String, stars_earned: int):
	"""Call this when a quest is completed"""
	if not completed_quests.has(domain):
		completed_quests[domain] = {}
	
	completed_quests[domain][quest_id] = {
		"completed": true,
		"stars": stars_earned,
		"completion_date": Time.get_unix_time_from_system()
	}
	
	print("[EndingManager] Quest completed: ", quest_id, " (", domain, ") - ", stars_earned, " stars")
	
	emit_signal("quest_completed", quest_id, domain)
	
	save_progress()
	
	# Check if all quests are complete
	if check_all_quests_complete():
		print("[EndingManager] 🎉 ALL QUESTS COMPLETED! Triggering ending...")
		emit_signal("all_quests_completed")
		# Don't automatically trigger - let player choose when to view ending
		# They can access it from the hub

# Check if a specific quest is completed
func is_quest_completed(quest_id: String, domain: String) -> bool:
	if not completed_quests.has(domain):
		return false
	if not completed_quests[domain].has(quest_id):
		return false
	return completed_quests[domain][quest_id].get("completed", false)

# Get stars earned for a specific quest
func get_quest_stars(quest_id: String, domain: String) -> int:
	if not completed_quests.has(domain):
		return 0
	if not completed_quests[domain].has(quest_id):
		return 0
	return completed_quests[domain][quest_id].get("stars", 0)

# Check if all quests are complete
func check_all_quests_complete() -> bool:
	for domain in QUEST_DEFINITIONS.keys():
		for quest in QUEST_DEFINITIONS[domain]:
			if not is_quest_completed(quest.id, domain):
				return false
	return true

# Get completion percentage
func get_completion_percentage() -> float:
	var total_quests = 0
	var completed = 0
	
	for domain in QUEST_DEFINITIONS.keys():
		total_quests += QUEST_DEFINITIONS[domain].size()
		if completed_quests.has(domain):
			completed += completed_quests[domain].size()
	
	return (float(completed) / float(total_quests)) * 100.0

# Get total quests per domain
func get_domain_quest_count(domain: String) -> int:
	if QUEST_DEFINITIONS.has(domain):
		return QUEST_DEFINITIONS[domain].size()
	return 0

# Get completed quests per domain
func get_domain_completed_count(domain: String) -> int:
	if not completed_quests.has(domain):
		return 0
	return completed_quests[domain].size()

# Determine ending tier based on performance
func get_ending_tier() -> String:
	var total_stars = StarManager.get_total_stars()
	
	if total_stars >= ENDING_THRESHOLDS.perfect:
		return "perfect"
	elif total_stars >= ENDING_THRESHOLDS.excellent:
		return "excellent"
	elif total_stars >= ENDING_THRESHOLDS.good:
		return "good"
	elif total_stars >= ENDING_THRESHOLDS.decent:
		return "decent"
	else:
		return "poor"

# Get ending title and description
func get_ending_info() -> Dictionary:
	var tier = get_ending_tier()
	var total_stars = StarManager.get_total_stars()
	var max_stars = 75  # 5 domains × 3 quests × 5 stars
	
	var endings = {
		"perfect": {
			"title": "The Perfect Renaissance",
			"subtitle": "Legend of the Five Domains",
			"description": "You have achieved perfection across all domains. The village has become a beacon of civilization, renowned across all lands. Your name will be remembered for generations as the greatest leader in history.",
			"color": Color(1.0, 0.84, 0.0)  # Gold
		},
		"excellent": {
			"title": "The Grand Renaissance",
			"subtitle": "Master of Many Disciplines",
			"description": "Your exceptional leadership has transformed the village into a thriving center of knowledge and prosperity. Future generations will study your achievements as a model of excellence.",
			"color": Color(0.75, 0.75, 1.0)  # Light blue
		},
		"good": {
			"title": "The Renaissance",
			"subtitle": "A New Era of Progress",
			"description": "Through your efforts, the village has entered a new golden age. Your balanced approach to leadership has created lasting prosperity and happiness for all villagers.",
			"color": Color(0.5, 1.0, 0.5)  # Light green
		},
		"decent": {
			"title": "The Awakening",
			"subtitle": "Hope for Tomorrow",
			"description": "You have brought meaningful change to the village. While challenges remain, you have laid a foundation for future progress. The villagers are grateful for your contributions.",
			"color": Color(1.0, 1.0, 0.5)  # Light yellow
		},
		"poor": {
			"title": "The Beginning",
			"subtitle": "A Journey Started",
			"description": "You have taken the first steps toward revitalizing the village. Much work remains, but you have shown the villagers that change is possible. Your journey has only just begun.",
			"color": Color(0.7, 0.7, 0.7)  # Gray
		}
	}
	
	var info = endings[tier].duplicate()
	info["tier"] = tier
	info["stars"] = total_stars
	info["max_stars"] = max_stars
	info["percentage"] = (float(total_stars) / float(max_stars)) * 100.0
	
	return info

# Get detailed statistics for ending screen
func get_ending_statistics() -> Dictionary:
	var stats = {
		"total_stars": StarManager.get_total_stars(),
		"max_possible_stars": 75,
		"quests_completed": 0,
		"total_quests": 0,
		"domain_stats": {}
	}
	
	for domain in QUEST_DEFINITIONS.keys():
		var domain_quests = get_domain_quest_count(domain)
		var domain_completed = get_domain_completed_count(domain)
		var domain_stars = StarManager.get_domain_stars(domain)
		
		stats.total_quests += domain_quests
		stats.quests_completed += domain_completed
		
		stats.domain_stats[domain] = {
			"completed": domain_completed,
			"total": domain_quests,
			"stars": domain_stars,
			"max_stars": domain_quests * 5
		}
	
	return stats

# Save progress
func save_progress():
	var save_data = {
		"completed_quests": completed_quests
	}
	
	var file = FileAccess.open("user://ending_progress.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

# Load progress
func load_progress():
	if FileAccess.file_exists("user://ending_progress.save"):
		var file = FileAccess.open("user://ending_progress.save", FileAccess.READ)
		if file:
			var save_data = file.get_var()
			completed_quests = save_data.get("completed_quests", {})
			file.close()
			print("[EndingManager] Loaded progress - ", get_completion_percentage(), "% complete")

# Reset all progress (for testing or new game)
func reset_progress():
	completed_quests.clear()
	save_progress()
	print("[EndingManager] Progress reset")

# Trigger the ending cutscene
func show_ending():
	"""Call this to start the ending sequence"""
	if not check_all_quests_complete():
		print("[EndingManager] Cannot show ending - not all quests complete")
		return
	
	# Change to ending scene
	get_tree().change_scene_to_file("res://scenes/ending/EndingCutscene.tscn")
