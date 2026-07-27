extends Node2D

func _ready():
	$kid.potion_given_success.connect(Scoremanager._on_potion_success)
	$kid.potion_given_failed.connect(Scoremanager._on_potion_failed)
