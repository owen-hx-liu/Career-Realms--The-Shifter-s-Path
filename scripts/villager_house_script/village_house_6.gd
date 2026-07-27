extends Node2D

func _ready():
	$gaurd.potion_given_success.connect(Scoremanager._on_potion_success)
	$gaurd.potion_given_failed.connect(Scoremanager._on_potion_failed)
