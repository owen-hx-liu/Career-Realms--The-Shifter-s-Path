extends Node

var current_level: int = 1
var max_repair_level: int = 3
var last_repair_score: int = 0
var last_repair_stars: int = 0

# Resets the skyscraper repair quest progression back to level 1.
func reset_repair_progress() -> void:
	current_level = 1
	last_repair_score = 0
	last_repair_stars = 0
