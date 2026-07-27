extends Node

var total_npcs: int = 3
var alive_npcs: int = 3
var tracker

func _ready():
	tracker = get_node("/root/World/NPCTracker")
	print("NPC Tracker initialized - Starting NPCs: ", alive_npcs)

	if tracker:
		var survivors = tracker.get_alive_count()
		var deaths = tracker.get_deaths()
		print("You escaped with ", survivors, " survivors!")
		print(deaths, " citizens died.")

func npc_died():
	alive_npcs -= 1
	print("NPC died! Remaining NPCs: ", alive_npcs, "/", total_npcs)
	
	if alive_npcs <= 0:
		print("All NPCs have perished!")

func get_alive_count() -> int:
	return alive_npcs

func get_total_count() -> int:
	return total_npcs

func get_deaths() -> int:
	return total_npcs - alive_npcs
