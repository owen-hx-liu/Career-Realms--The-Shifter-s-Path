extends Node2D

func _ready():
	$farmer.potion_given_success.connect(Scoremanager._on_potion_success)
	$farmer.potion_given_failed.connect(Scoremanager._on_potion_failed)
