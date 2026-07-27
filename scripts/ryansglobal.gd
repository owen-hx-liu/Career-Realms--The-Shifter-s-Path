extends Node

# --- SIGNALS ---






# DEFINE YOUR ANIMALS HERE
# This ensures the game knows their limits even when you are in the Control Room

# --- NON-QUEST RELATED CODE ---
var current_scene = ""
var narrator_shown := false
var next_scene_path = ""
var next_player_x = -1
var next_player_y = -1

var healed_villagers: Dictionary = {}
func mark_villager_healed(v_name: String): healed_villagers[v_name] = true
func is_villager_healed(v_name: String) -> bool: return healed_villagers.get(v_name, false)
var healing_attempts: Dictionary = {}
func mark_healing_attempt(v_name: String): healing_attempts[v_name] = true
func has_attempted_healing(v_name: String) -> bool: return healing_attempts.get(v_name, false)
var collected_resources: Dictionary = {}
func mark_resource_collected(r_id: String): collected_resources[r_id] = true
func is_resource_collected(r_id: String) -> bool: return collected_resources.get(r_id, false)
func mark_narrator_shown(): narrator_shown = true
func has_narrator_been_shown() -> bool: return narrator_shown


# --- BARN QUEST LOGIC ---
