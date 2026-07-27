# StarManager.gd
# IMPORTANT: Add this as an Autoload Singleton
# Project Settings -> Autoload -> Path: res://scripts/core/StarManager.gd -> Name: StarManager
extends Node

# Data structure: { "domain_name": { "quest_id": star_count } }
var quest_stars: Dictionary = {}

# Metadata: { "quest_id": { "domain": "domain_name", "max_stars": 5, "completed": bool } }
var quest_metadata: Dictionary = {}

# Domain colors for star visual representation
const DOMAIN_COLORS = {
	"Engineering": Color(1.0, 1.0, 0.0),  # Yellow
	"Farming": Color(0.0, 1.0, 0.0),      # Green
	"Art": Color(1.0, 0.0, 0.0),          # Red
	"Medicine": Color(0.6, 0.0, 1.0),     # Purple
	"Leadership": Color(0.0, 0.5, 1.0)    # Blue
}

# Map domain names to their container room scenes
const DOMAIN_ROOMS = {
	"Engineering": "res://scenes/maps/EngineeringHouse.tscn",
	"Farming": "res://scenes/maps/FarmingHouse.tscn",
	"Art": "res://scenes/maps/ArtHouse.tscn",
	"Medicine": "res://scenes/maps/StarHouse.tscn",  # Adjust if different
	"Leadership": "res://scenes/maps/starcontainerroom.tscn"  # Adjust if different
}

func _ready():
	print("[StarManager] ========== STARTUP ==========")
	print("[StarManager] Checking for save file...")
	
	var save_path = "user://star_data.save"
	var file_exists = FileAccess.file_exists(save_path)
	print("[StarManager] Save file exists: ", file_exists)
	
	if file_exists:
		print("[StarManager] Attempting to delete save file...")
		var err = DirAccess.remove_absolute(save_path)
		print("[StarManager] Delete result code: ", err, " (0 = success)")
		
		# Verify deletion
		if FileAccess.file_exists(save_path):
			print("[StarManager] WARNING: File still exists after delete attempt!")
		else:
			print("[StarManager] File successfully deleted")
	
	# Reset all data structures
	print("[StarManager] Clearing all data structures...")
	quest_stars.clear()
	quest_metadata.clear()
	print("[StarManager] quest_stars size: ", quest_stars.size())
	print("[StarManager] quest_metadata size: ", quest_metadata.size())
	
	# Don't load old data
	# load_stars()  # COMMENTED OUT - don't load old data
	
	print("[StarManager] Total stars after reset: ", get_total_stars())
	print("[StarManager] ========== READY COMPLETE ==========")
	
	# OPTIONAL: Uncomment to reset stars every time
	# reset_all_stars()

func reset_all_stars():
	"""Reset all star data - useful for testing or starting fresh"""
	print("[StarManager] ========== RESETTING ALL STARS ==========")
	print("[StarManager] Before reset - quest_stars: ", quest_stars)
	print("[StarManager] Before reset - quest_metadata: ", quest_metadata)
	
	quest_stars.clear()
	quest_metadata.clear()
	
	print("[StarManager] After clear - quest_stars size: ", quest_stars.size())
	print("[StarManager] After clear - quest_metadata size: ", quest_metadata.size())
	
	save_stars()
	
	print("[StarManager] All stars have been reset")
	print("[StarManager] Total stars: ", get_total_stars())
	print("[StarManager] ==========================================")

# Call this from your quest system when a quest is completed
func record_quest_stars(quest_id: String, domain: String, stars: int, max_stars: int = 5):
	# Ensure domain exists
	if not quest_stars.has(domain):
		quest_stars[domain] = {}
	
	# Store stars
	quest_stars[domain][quest_id] = stars
	
	# Store metadata
	quest_metadata[quest_id] = {
		"domain": domain,
		"max_stars": max_stars,
		"completed": stars > 0
	}
	
	save_stars()
	
	# Update the corresponding domain's inventory
	update_domain_inventory(domain)

# Convert any score to 1-5 stars
func convert_to_stars(score: float, min_score: float, max_score: float) -> int:
	var normalized = clamp((score - min_score) / (max_score - min_score), 0.0, 1.0)
	var stars = int(ceil(normalized * 5.0))
	return max(1, min(stars, 5))

func get_total_stars() -> int:
	var total = 0
	for domain in quest_stars:
		for quest_id in quest_stars[domain]:
			total += quest_stars[domain][quest_id]
	return total

func get_max_possible_stars() -> int:
	var total = 0
	for quest_id in quest_metadata:
		total += quest_metadata[quest_id].get("max_stars", 5)
	return total

func get_completed_quest_count() -> int:
	var count = 0
	for quest_id in quest_metadata:
		if quest_metadata[quest_id].get("completed", false):
			count += 1
	return count

func get_total_quest_count() -> int:
	return quest_metadata.size()

func get_domain_stars(domain: String) -> int:
	if not quest_stars.has(domain):
		return 0
	var total = 0
	for quest_id in quest_stars[domain]:
		total += quest_stars[domain][quest_id]
	return total

func get_domain_max_stars(domain: String) -> int:
	var total = 0
	for quest_id in quest_metadata:
		if quest_metadata[quest_id].get("domain") == domain:
			total += quest_metadata[quest_id].get("max_stars", 5)
	return total

func get_domain_quest_count(domain: String) -> int:
	if not quest_stars.has(domain):
		return 0
	return quest_stars[domain].size()

func get_all_domains() -> Array:
	return quest_stars.keys()

func get_quest_stars(quest_id: String) -> int:
	if quest_metadata.has(quest_id):
		var domain = quest_metadata[quest_id].get("domain")
		if quest_stars.has(domain) and quest_stars[domain].has(quest_id):
			return quest_stars[domain][quest_id]
	return 0

func get_domain_color(domain: String) -> Color:
	return DOMAIN_COLORS.get(domain, Color(1.0, 1.0, 1.0))

func update_domain_inventory(domain: String):
	"""Update the inventory for a specific domain with colored stars"""
	# This will be called by the inventory when it loads in domain-specific rooms
	pass

func save_stars():
	var save_data = {
		"quest_stars": quest_stars,
		"quest_metadata": quest_metadata
	}
	var file = FileAccess.open("user://star_data.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("[StarManager] Stars saved - Total: ", get_total_stars())
	else:
		print("[StarManager] ERROR: Could not open save file for writing!")

func load_stars():
	print("[StarManager] ========== LOADING STARS ==========")
	if FileAccess.file_exists("user://star_data.save"):
		var file = FileAccess.open("user://star_data.save", FileAccess.READ)
		if file:
			var save_data = file.get_var()
			quest_stars = save_data.get("quest_stars", {})
			quest_metadata = save_data.get("quest_metadata", {})
			file.close()
			print("[StarManager] Loaded quest_stars: ", quest_stars)
			print("[StarManager] Loaded quest_metadata: ", quest_metadata)
			print("[StarManager] Total stars loaded: ", get_total_stars())
		else:
			print("[StarManager] ERROR: Could not open save file for reading!")
	else:
		print("[StarManager] No save file found")
	print("[StarManager] ======================================")
