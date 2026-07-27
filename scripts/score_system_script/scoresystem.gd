extends CanvasLayer

@onready var score_box: NinePatchRect = $Control/NinePatchRect
@onready var final_label: RichTextLabel = $Control/NinePatchRect/RichTextLabel2

func _ready():
	# Connect to signal
	Scoremanager.scoring_finished.connect(_on_scoring_finished)

	# If quest already finished before this scene loaded, show immediately
	if Scoremanager.finished:
		_on_scoring_finished(Scoremanager.score)
	else:
		score_box.visible = false  # hide until finished

func _on_scoring_finished(final_score: int):
	score_box.visible = true
	final_label.bbcode_enabled = true

	# Just add "Congratulations" above the score
	final_label.text = "Congratulations\n\nFinal Score: " + str(final_score)

	# Fade-in animation
	score_box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(score_box, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
