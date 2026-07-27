# LegacyAchievementManager.gd
# AUTOLOAD SINGLETON - Add to Project Settings → Autoload
# Path: res://scripts/core/LegacyAchievementManager.gd
# Name: LegacyAchievementManager

extends Node

# Achievement data structure
class Achievement:
	var id: String
	var title: String
	var description: String
	var icon_path: String
	var unlocked: bool = false
	var unlock_date: int = 0  # Unix timestamp
	
	func _init(p_id: String, p_title: String, p_desc: String, p_icon: String = ""):
		id = p_id
		title = p_title
		description = p_desc
		icon_path = p_icon if p_icon != "" else "res://assets/icons/achievement_default.png"

# All available achievements
var achievements: Dictionary = {}

# Track first play time for speed achievements
var game_start_time: int = 0

signal achievement_unlocked(achievement: Achievement)

func _ready():
	_initialize_achievements()
	load_achievements()
	print("[Achievements] Manager initialized with ", achievements.size(), " achievements")

func _initialize_achievements():
	# Star Collection Achievements
	achievements["first_star"] = Achievement.new(
		"first_star",
		"First Star",
		"Earn your first star in any domain",
		"res://assets/icons/achievement_first_star.png"
	)
	
	achievements["rising_star"] = Achievement.new(
		"rising_star",
		"Rising Star",
		"Earn 5 stars in a single domain",
		"res://assets/icons/achievement_rising_star.png"
	)
	
	achievements["stellar_performance"] = Achievement.new(
		"stellar_performance",
		"Stellar Performance",
		"Earn 10 stars in a single domain",
		"res://assets/icons/achievement_stellar.png"
	)
	
	achievements["domain_master"] = Achievement.new(
		"domain_master",
		"Domain Master",
		"Earn all possible stars in a single domain",
		"res://assets/icons/achievement_master.png"
	)
	
	achievements["jack_of_trades"] = Achievement.new(
		"jack_of_trades",
		"Jack of All Trades",
		"Earn at least 1 star in every domain",
		"res://assets/icons/achievement_jack.png"
	)
	
	achievements["renaissance"] = Achievement.new(
		"renaissance",
		"Renaissance Person",
		"Earn at least 5 stars in every domain",
		"res://assets/icons/achievement_renaissance.png"
	)
	
	achievements["perfect_balance"] = Achievement.new(
		"perfect_balance",
		"Perfect Balance",
		"Earn equal stars in at least 3 domains",
		"res://assets/icons/achievement_balance.png"
	)
	
	achievements["specialist"] = Achievement.new(
		"specialist",
		"Specialist",
		"Earn 15+ stars in one domain while others have <5",
		"res://assets/icons/achievement_specialist.png"
	)
	
	achievements["complete_collection"] = Achievement.new(
		"complete_collection",
		"The Complete Collection",
		"Earn all stars in all domains",
		"res://assets/icons/achievement_complete.png"
	)
	
	# Cross-Domain Achievements
	achievements["synergy_seeker"] = Achievement.new(
		"synergy_seeker",
		"Synergy Seeker",
		"Trigger 10 cross-domain bonuses",
		"res://assets/icons/achievement_synergy.png"
	)
	
	achievements["master_coordinator"] = Achievement.new(
		"master_coordinator",
		"Master Coordinator",
		"Have 5+ active domain interactions at once",
		"res://assets/icons/achievement_coordinator.png"
	)
	
	achievements["domain_synergy"] = Achievement.new(
		"domain_synergy",
		"Domain Synergy",
		"Complete a quest with 3+ domain bonuses active",
		"res://assets/icons/achievement_domain_synergy.png"
	)
	
	# Speed Achievements
	achievements["quick_learner"] = Achievement.new(
		"quick_learner",
		"Quick Learner",
		"Earn 5 stars within first hour of play",
		"res://assets/icons/achievement_quick.png"
	)

# Check and unlock achievements based on star counts
func check_star_achievements():
	var total_stars = StarManager.get_total_stars()
	var domains = ["Engineering", "Farming", "Leadership", "Medicine", "Art"]
	
	# First star
	if total_stars >= 1:
		unlock_achievement("first_star")
	
	# Check per-domain achievements
	var max_stars_in_domain = 0
	var domains_with_1_plus = 0
	var domains_with_5_plus = 0
	var star_counts = []
	
	for domain in domains:
		var stars = StarManager.get_domain_stars(domain)
		star_counts.append(stars)
		
		if stars >= 1:
			domains_with_1_plus += 1
		if stars >= 5:
			domains_with_5_plus += 1
			unlock_achievement("rising_star")
		if stars >= 10:
			unlock_achievement("stellar_performance")
		if stars > max_stars_in_domain:
			max_stars_in_domain = stars
		
		# Check if domain is complete
		var max_possible = StarManager.get_domain_max_stars(domain)
		if max_possible > 0 and stars >= max_possible:
			unlock_achievement("domain_master")
	
	# Jack of all trades
	if domains_with_1_plus >= 5:
		unlock_achievement("jack_of_trades")
	
	# Renaissance person
	if domains_with_5_plus >= 5:
		unlock_achievement("renaissance")
	
	# Perfect balance - check if at least 3 domains have equal stars
	var balance_count = 0
	for i in range(star_counts.size()):
		var matches = 0
		for j in range(star_counts.size()):
			if i != j and star_counts[i] == star_counts[j] and star_counts[i] > 0:
				matches += 1
		if matches >= 2:  # At least 2 other domains match
			balance_count = matches + 1
			break
	if balance_count >= 3:
		unlock_achievement("perfect_balance")
	
	# Specialist - one domain 15+, others <5
	if max_stars_in_domain >= 15:
		var other_domains_low = true
		for domain in domains:
			var stars = StarManager.get_domain_stars(domain)
			if stars != max_stars_in_domain and stars >= 5:
				other_domains_low = false
				break
		if other_domains_low:
			unlock_achievement("specialist")
	
	# Complete collection
	var all_complete = true
	for domain in domains:
		var stars = StarManager.get_domain_stars(domain)
		var max_possible = StarManager.get_domain_max_stars(domain)
		if max_possible > 0 and stars < max_possible:
			all_complete = false
			break
	if all_complete:
		unlock_achievement("complete_collection")

# Check cross-domain achievements
func check_cross_domain_achievements(active_bonus_count: int):
	# Domain synergy - complete quest with 3+ bonuses
	if active_bonus_count >= 3:
		unlock_achievement("domain_synergy")
	
	# Master coordinator - 5+ active interactions
	if DomainInteractionManager:
		var interaction_count = DomainInteractionManager.get_active_interaction_count()
		if interaction_count >= 5:
			unlock_achievement("master_coordinator")
		
		# Synergy seeker - trigger 10 times
		if DomainInteractionManager.bonus_trigger_count >= 10:
			unlock_achievement("synergy_seeker")

# Check speed achievements
func check_speed_achievements():
	if game_start_time == 0:
		return
	
	var time_played = (Time.get_ticks_msec() / 1000) - game_start_time
	var total_stars = StarManager.get_total_stars()
	
	# Quick learner - 5 stars in first hour
	if time_played <= 3600 and total_stars >= 5:
		unlock_achievement("quick_learner")

# Unlock an achievement
func unlock_achievement(achievement_id: String) -> bool:
	if not achievements.has(achievement_id):
		print("[Achievements] Unknown achievement: ", achievement_id)
		return false
	
	var achievement = achievements[achievement_id]
	if achievement.unlocked:
		return false  # Already unlocked
	
	achievement.unlocked = true
	achievement.unlock_date = Time.get_unix_time_from_system()
	
	print("[Achievements] ✨ UNLOCKED: ", achievement.title)
	emit_signal("achievement_unlocked", achievement)
	
	save_achievements()
	
	# Show notification (if you have a notification system)
	_show_achievement_notification(achievement)
	
	return true

# Show achievement notification
func _show_achievement_notification(achievement: Achievement):
	# TODO: Create a UI popup that shows the achievement
	# For now, just print
	print("[Achievements] 🏆 ", achievement.title, " - ", achievement.description)

# Get all unlocked achievements
func get_unlocked_achievements() -> Array:
	var unlocked = []
	for ach_id in achievements.keys():
		var ach = achievements[ach_id]
		if ach.unlocked:
			unlocked.append(ach)
	return unlocked

# Get achievement progress as percentage
func get_progress_percentage() -> float:
	var total = achievements.size()
	var unlocked = get_unlocked_achievements().size()
	return (float(unlocked) / float(total)) * 100.0

# Check if specific achievement is unlocked
func is_unlocked(achievement_id: String) -> bool:
	if not achievements.has(achievement_id):
		return false
	return achievements[achievement_id].unlocked

# Save achievements to file
func save_achievements():
	var save_data = {
		"game_start_time": game_start_time,
		"achievements": {}
	}
	
	for ach_id in achievements.keys():
		var ach = achievements[ach_id]
		save_data["achievements"][ach_id] = {
			"unlocked": ach.unlocked,
			"unlock_date": ach.unlock_date
		}
	
	var file = FileAccess.open("user://achievements.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("[Achievements] Saved")

# Load achievements from file
func load_achievements():
	if not FileAccess.file_exists("user://achievements.save"):
		game_start_time = Time.get_ticks_msec() / 1000
		return
	
	var file = FileAccess.open("user://achievements.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		game_start_time = save_data.get("game_start_time", Time.get_ticks_msec() / 1000)
		
		var saved_achievements = save_data.get("achievements", {})
		for ach_id in saved_achievements.keys():
			if achievements.has(ach_id):
				var ach_data = saved_achievements[ach_id]
				achievements[ach_id].unlocked = ach_data.get("unlocked", false)
				achievements[ach_id].unlock_date = ach_data.get("unlock_date", 0)
		
		print("[Achievements] Loaded - ", get_unlocked_achievements().size(), " unlocked")

# Reset all achievements (for testing)
func reset_all():
	for ach_id in achievements.keys():
		achievements[ach_id].unlocked = false
		achievements[ach_id].unlock_date = 0
	game_start_time = Time.get_ticks_msec() / 1000
	save_achievements()
	print("[Achievements] All achievements reset")
