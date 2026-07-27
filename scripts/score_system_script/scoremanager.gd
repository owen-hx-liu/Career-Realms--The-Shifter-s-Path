extends Node

signal score_changed(new_score)
signal scoring_finished(final_score)

var score: int = 0
var attempts: int = 0
var max_attempts: int = 6   # total villagers
var finished: bool = false  # <-- add this flag

func _on_potion_success(villager_name: String):
	score += 10
	attempts += 1
	emit_signal("score_changed", score)
	_check_finished()
	print("Score after success:", score)

func _on_potion_failed(villager_name: String):
	attempts += 1
	emit_signal("score_changed", score)
	_check_finished()
	print("Score after fail:", score)

func _check_finished():
	if attempts >= max_attempts and not finished:
		finished = true
		emit_signal("scoring_finished", score)
		print("Final Score:", score)
