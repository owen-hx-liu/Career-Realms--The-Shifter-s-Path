extends Node2D

func _ready():
	$villager.potion_given_success.connect(Scoremanager._on_potion_success)
	$villager.potion_given_failed.connect(Scoremanager._on_potion_failed)
