extends Node2D

func _ready():
	$hunter.potion_given_success.connect(Scoremanager._on_potion_success)
	$hunter.potion_given_failed.connect(Scoremanager._on_potion_failed)
