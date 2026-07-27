extends Node2D

func _ready():
	$scholar.potion_given_success.connect(Scoremanager._on_potion_success)
	$scholar.potion_given_failed.connect(Scoremanager._on_potion_failed)
