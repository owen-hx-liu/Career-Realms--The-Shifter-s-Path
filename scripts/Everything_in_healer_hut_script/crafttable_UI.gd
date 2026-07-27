extends Control

var player: Node = null

func _ready():
	await get_tree().process_frame  # Wait one frame to ensure player is added to scene

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		print("Player not found!")

	for button in $NinePatchRect/GridContainer.get_children():
		button.craft_requested.connect(_on_craft_requested)

func has_required_ingredients(recipe: Dictionary) -> bool:
	if not player or not player.inv:
		print("Error: player or inventory not found")
		return false

	for ingredient_name in recipe.keys():
		if typeof(ingredient_name) != TYPE_STRING:
			print("Error: invalid ingredient name:", ingredient_name)
			continue

		var required = recipe[ingredient_name]
		var available = player.inv.get_count(ingredient_name)

		if available < required:
			return false
	return true

	
func consume_ingredients(recipe: Dictionary):
	for ingredient_name in recipe.keys():
		var amount = recipe[ingredient_name]
		player.inv.remove(ingredient_name, amount)



func _on_craft_requested(item: InvItem, recipe: Dictionary):
	if not player:
		print("Crafting failed: no player reference")
		return

	if has_required_ingredients(recipe):
		consume_ingredients(recipe)
		player.collect(item)
		print("Crafted:", item.name)
	else:
		print("Not enough ingredients to craft", item.name)

		
