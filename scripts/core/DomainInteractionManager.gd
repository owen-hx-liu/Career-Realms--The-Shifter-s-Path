# DomainInteractionManager.gd
# AUTOLOAD SINGLETON - Add to Project Settings → Autoload
# Path: res://scripts/core/DomainInteractionManager.gd
# Name: DomainInteractionManager

extends Node

# Track how many times bonuses have been triggered (for achievements)
var bonus_trigger_count: int = 0

# Domain interaction definitions
# Format: { "source_domain": { "target_domain": { threshold: bonus_value } } }
const DOMAIN_INTERACTIONS = {
	"Engineering": {
		"Farming": {
			5: {"type": "crop_growth_speed", "value": 0.05, "description": "+5% crop growth speed"},
			10: {"type": "crop_synergy_bonus", "value": 0.10, "description": "+10% crop synergy bonus"}
		},
		"Medicine": {
			5: {"type": "healing_capacity", "value": 1, "description": "+1 healing capacity"},
			10: {"type": "healing_capacity", "value": 2, "description": "+2 healing capacity"}
		},
		"Leadership": {
			5: {"type": "time_bonus", "value": 0.05, "description": "+5% quest time extension"},
			10: {"type": "coordination_boost", "value": 0.10, "description": "+10% team efficiency"}
		}
	},
	
	"Farming": {
		"Medicine": {
			5: {"type": "healing_effectiveness", "value": 0.10, "description": "+10% healing effectiveness"},
			10: {"type": "special_herbs", "value": 1, "description": "Unlock medicinal herbs"}
		},
		"Engineering": {
			5: {"type": "time_extension", "value": 0.05, "description": "+5% build time extension"},
			10: {"type": "time_extension", "value": 0.10, "description": "+10% build time extension"}
		},
		"Leadership": {
			5: {"type": "morale_boost", "value": 0.05, "description": "+5% village morale"},
			10: {"type": "resource_efficiency", "value": 0.10, "description": "+10% resource efficiency"}
		}
	},
	
	"Leadership": {
		"Engineering": {
			5: {"type": "efficiency_boost", "value": 0.05, "description": "+5% engineering efficiency"},
			10: {"type": "efficiency_boost", "value": 0.10, "description": "+10% engineering efficiency"}
		},
		"Farming": {
			5: {"type": "efficiency_boost", "value": 0.05, "description": "+5% farming efficiency"},
			10: {"type": "efficiency_boost", "value": 0.10, "description": "+10% farming efficiency"}
		},
		"Medicine": {
			5: {"type": "efficiency_boost", "value": 0.05, "description": "+5% medicine efficiency"},
			10: {"type": "efficiency_boost", "value": 0.10, "description": "+10% medicine efficiency"}
		},
		"Art": {
			5: {"type": "efficiency_boost", "value": 0.05, "description": "+5% art efficiency"},
			10: {"type": "efficiency_boost", "value": 0.10, "description": "+10% art efficiency"}
		}
	},
	
	"Medicine": {
		"Leadership": {
			5: {"type": "health_morale", "value": 0.05, "description": "+5% villager morale from health"},
			10: {"type": "health_morale", "value": 0.10, "description": "+10% villager morale from health"}
		}
	},
	
	"Art": {
		"Leadership": {
			5: {"type": "cultural_morale", "value": 0.05, "description": "+5% morale from culture"},
			10: {"type": "cultural_morale", "value": 0.10, "description": "+10% morale from culture"}
		}
	}
}

func _ready():
	print("[DomainInteraction] Manager initialized")

# Get all bonuses that apply when doing a quest in target_domain
func get_bonuses_for_domain(target_domain: String) -> Dictionary:
	"""
	Returns: { 
		"crop_growth_speed": 0.05,
		"time_extension": 0.10,
		...
	}
	"""
	var active_bonuses = {}
	
	# Check each source domain's stars
	for source_domain in DOMAIN_INTERACTIONS.keys():
		var source_stars = StarManager.get_domain_stars(source_domain)
		
		# Check if this source domain has interactions with target domain
		if DOMAIN_INTERACTIONS[source_domain].has(target_domain):
			var interactions = DOMAIN_INTERACTIONS[source_domain][target_domain]
			
			# Check each threshold
			for threshold in interactions.keys():
				if source_stars >= threshold:
					var bonus_data = interactions[threshold]
					var bonus_type = bonus_data["type"]
					var bonus_value = bonus_data["value"]
					
					# Accumulate bonuses of same type (they stack)
					if active_bonuses.has(bonus_type):
						active_bonuses[bonus_type] += bonus_value
					else:
						active_bonuses[bonus_type] = bonus_value
					
					print("[DomainInteraction] ", source_domain, " (", source_stars, " stars) → ", target_domain, ": ", bonus_data["description"])
	
	if active_bonuses.size() > 0:
		bonus_trigger_count += 1
		
		# Check for achievement
		if LegacyAchievementManager:
			LegacyAchievementManager.check_cross_domain_achievements(active_bonuses.size())
	
	return active_bonuses

# Get a specific bonus type value for a domain
func get_bonus_value(target_domain: String, bonus_type: String) -> float:
	var bonuses = get_bonuses_for_domain(target_domain)
	return bonuses.get(bonus_type, 0.0)

# Check if a domain has a specific bonus active
func has_bonus(target_domain: String, bonus_type: String) -> bool:
	return get_bonus_value(target_domain, bonus_type) > 0.0

# Get all active domain interactions (for UI display)
func get_all_active_interactions() -> Array:
	"""
	Returns array of: [
		{
			"source": "Engineering",
			"target": "Farming",
			"type": "crop_growth_speed",
			"value": 0.05,
			"description": "+5% crop growth speed"
		},
		...
	]
	"""
	var active = []
	
	for source_domain in DOMAIN_INTERACTIONS.keys():
		var source_stars = StarManager.get_domain_stars(source_domain)
		
		if source_stars == 0:
			continue
		
		for target_domain in DOMAIN_INTERACTIONS[source_domain].keys():
			var interactions = DOMAIN_INTERACTIONS[source_domain][target_domain]
			
			for threshold in interactions.keys():
				if source_stars >= threshold:
					var bonus_data = interactions[threshold].duplicate()
					bonus_data["source"] = source_domain
					bonus_data["target"] = target_domain
					bonus_data["threshold"] = threshold
					active.append(bonus_data)
	
	return active

# Get count of currently active interactions
func get_active_interaction_count() -> int:
	return get_all_active_interactions().size()

# Get a user-friendly summary of bonuses for a specific quest
func get_quest_bonus_summary(quest_domain: String) -> String:
	var bonuses = get_bonuses_for_domain(quest_domain)
	
	if bonuses.is_empty():
		return "No domain bonuses active for this quest"
	
	var summary = "Active Domain Bonuses:\n"
	for bonus_type in bonuses.keys():
		var value = bonuses[bonus_type]
		var percent = value * 100 if value < 1.0 else value
		summary += "  • %s: +%.0f%%\n" % [bonus_type.replace("_", " ").capitalize(), percent]
	
	return summary

# Reset bonus trigger count (for new game)
func reset():
	bonus_trigger_count = 0
	print("[DomainInteraction] Reset")
