extends Node

var current_scene = ""




var narrator_shown := false
var next_scene_path = ""
var next_player_x = 599
var next_player_y = 1560


var healed_villagers: Dictionary = {}

func mark_villager_healed(villager_name: String):
	healed_villagers[villager_name] = true

func is_villager_healed(villager_name: String) -> bool:
	return healed_villagers.get(villager_name, false)

var healing_attempts: Dictionary = {}

func mark_healing_attempt(villager_name: String):
	healing_attempts[villager_name] = true

func has_attempted_healing(villager_name: String) -> bool:
	return healing_attempts.get(villager_name, false)


var collected_resources: Dictionary = {}

func mark_resource_collected(resource_id: String):
	collected_resources[resource_id] = true

func is_resource_collected(resource_id: String) -> bool:
	return collected_resources.get(resource_id, false)




func mark_narrator_shown():
	narrator_shown = true

func has_narrator_been_shown() -> bool:
	return narrator_shown

	
