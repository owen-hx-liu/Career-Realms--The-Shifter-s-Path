extends CharacterBody2D

# Make sure your Sprite2D child is named exactly "SadBubble"
@onready var bubble = $SadBubble 

# Type the name in the Inspector to match the name in your global.barn_animals list
# e.g., "Cow", "Pig", "Sheep"
@export var animal_name: String = "Cow" 

func _ready():
	# 1. Hide the bubble at the start
	if bubble:
		bubble.visible = false
	else:
		push_error("SadBubble Sprite2D not found on " + name)
	
	# Small check to make sure the name exists in global
	_verify_animal_data()

func _process(_delta):
	# Only update if the quest is actually running
	if global.quest_active:
		_sync_with_global_mood()

func _sync_with_global_mood():
	if not is_instance_valid(bubble):
		return
	
	# Look through the global list to find this specific animal's happiness status
	for animal_data in global.barn_animals:
		if animal_data.name == animal_name:
			# If happy is true, bubble is hidden (false). 
			# If happy is false, bubble is visible (true).
			bubble.visible = not animal_data.happy
			return

func _verify_animal_data():
	var found = false
	for a in global.barn_animals:
		if a.name == animal_name:
			found = true
			break
	if not found:
		push_warning("Animal name '" + animal_name + "' does not match any entry in global.gd!")
