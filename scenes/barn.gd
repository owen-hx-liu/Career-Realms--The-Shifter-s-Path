# Barn.gd
extends Node2D

func _ready():
	# If this is the start of the quest, turn the system on
	if global.quest_active == false:
		global.start_barn_quest()
	
	# Connect UI and other things here...
