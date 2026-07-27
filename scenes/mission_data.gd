extends Node

var final_score: int = 0
var completed_tasks: int = 0
var total_tasks: int = 7

func set_results(score: int, completed: int):
	final_score = score
	completed_tasks = completed
	print("Mission results stored: ", score, " points, ", completed, "/", total_tasks, " tasks")

func get_stars() -> int:
	# Star rating based on score (out of 1600 possible)
	if final_score == 1600:
		return 5
	elif final_score >= 1400:
		return 4
	elif final_score >= 1000:
		return 3
	elif final_score >= 600:
		return 2
	elif final_score >= 400:
		return 1
	else:
		return 0  # No stars
