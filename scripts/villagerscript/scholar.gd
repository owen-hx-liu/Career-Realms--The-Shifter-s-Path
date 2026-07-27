extends CharacterBody2D

signal potion_given_success(villager_name)
signal potion_given_failed(villager_name)

@export var required_potion: String = "purple elixir"
@export var villager_name: String = "scholar"
@onready var potion_ui := $potionselectionmenu

var player_near := false
var is_healed := false
var has_attempted_healing := false

func _ready():
	is_healed = global.is_villager_healed(villager_name)
	has_attempted_healing = global.has_attempted_healing(villager_name)

	if is_healed or has_attempted_healing:
		potion_ui.visible = false  # Hide menu if already healed or tried

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		player_near = true

func _on_area_2d_body_exited(body):
	if body.is_in_group("player"):
		player_near = false

func _input(event):
	if not player_near or is_healed or has_attempted_healing:
		return

	if event.is_action_pressed("talk"):
		emit_signal("dialogue_requested", villager_name)
		$villager_dialogue.start()

	if event.is_action_pressed("give_potion"):
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var available_potions = player.inv.get_all_potion_items()
			potion_ui.show_potions(available_potions)
			potion_ui.potion_selected.connect(_on_potion_chosen)
			potion_ui.visible = true

func _on_potion_chosen(potion_name: String):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_potion(potion_name):
		player.inv.remove(potion_name, 1)
		global.mark_healing_attempt(villager_name)  # ✅ Persist the attempt
		has_attempted_healing = true

		if potion_name == required_potion:
			is_healed = true
			global.mark_villager_healed(villager_name)
			$healed_dialogue.start()
			emit_signal("potion_given_success", villager_name)
			print("potion success")
		else:
			$failed_dialogue.start()
			emit_signal("potion_given_failed", villager_name)
			print("potion failed")

	# Clean up
	potion_ui.visible = false
	potion_ui.potion_selected.disconnect(_on_potion_chosen)
