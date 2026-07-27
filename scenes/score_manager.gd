extends Node

var total_points: int = 0
var completed_locations: int = 0
var score_label = null  # ← This line must be here!

func _ready():
	print("ScoreManager initialized")
	find_score_label()
	update_display()

func find_score_label():
	score_label = get_node_or_null("../UILayer/InstructionsPanel/ScoreLabel")
	
	if not score_label:
		score_label = get_node_or_null("/root/MapView/UILayer/InstructionsPanel/ScoreLabel")
	
	if score_label:
		print("✓ ScoreLabel found!")
	else:
		print("✗ ScoreLabel not found")

func add_points(points: int):
	total_points += points
	completed_locations += 1
	print("=== LOCATION COMPLETE ===")
	print("Points earned: +", points)
	print("Total score: ", total_points, "/1600")
	print("Progress: ", completed_locations, "/7 locations")
	update_display()

func update_display():
	if score_label:
		score_label.text = "SCORE\n" + str(total_points) + " pts\n" + str(completed_locations) + "/7 Complete"
		print("✓ Score display updated: ", total_points, " points")
	else:
		print("⚠ Cannot update display - ScoreLabel not found")
