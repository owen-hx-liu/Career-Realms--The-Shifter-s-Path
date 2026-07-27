extends Node2D

@onready var player = $player
@onready var canal_zones = $CanalZones
@onready var flood_zones = $FloodZones
@onready var resource_piles = $ResourcePiles
@onready var reservoirs = $ReservoirMarkers
@onready var narrator = $Narrator
const CANALZONE_SCENE = preload("res://scenes/enviorment/CanalZone.tscn")

var available_resources := 0
var max_canals := 100
var built_canals := []
var total_score := 0
var quest_started := false

func _ready() -> void:
	global.update_camera()
	player.position = Vector2(global.next_player_x, global.next_player_y)
	generate_canal_zones()
	setup_flood_zones()
	setup_resource_piles()
	start_intro()

func start_intro():
	narrator.start_dialogue([
		"You arrive in Ancient Egypt.",
		"Raging floods threaten to destroy the farmlands.",
		"Collect materials from the piles and build canals to redirect the water!"
	])
	await get_tree().create_timer(2.5).timeout
	quest_started = true

func generate_canal_zones():
	var canal_tiles = [
		Vector2(10, 15),
		Vector2(12, 15),
		Vector2(14, 16),
		Vector2(16, 16),
		Vector2(18, 17)
	]
	for tile in canal_tiles:
		var zone = CANALZONE_SCENE.instantiate()
		zone.tile_position = tile
		canal_zones.add_child(zone)
		zone.activate_zone()
		zone.connect("canal_built_signal", Callable(self, "_on_canal_built"))

func _on_canal_built(tile_position):
	if available_resources > 0:
		available_resources -= 1
		built_canals.append(tile_position)
		print("Canal built at:", tile_position, " | Remaining resources:", available_resources)
		if available_resources == 0:
			print("No more resources left!")
	else:
		print("You have no resources to build canals!")

func setup_resource_piles():
	for pile in resource_piles.get_children():
		pile.connect("body_entered", Callable(self, "_on_resource_collected"))

func _on_resource_collected(body):
	if body.name == "player":
		available_resources += 3
		print("Resources collected! Total:", available_resources)
		narrator.start_dialogue(["You gathered building materials!"])
		var pile = get_parent()
		pile.queue_free()

func setup_flood_zones():
	for zone in flood_zones.get_children():
		if zone.has_node("Label"):
			zone.get_node("Label").text = "Flood Risk"
		zone.modulate = Color(1, 0, 0, 0.25)

func trigger_flood():
	for zone in flood_zones.get_children():
		zone.modulate = Color(0, 0, 1, 0.4)
		print("Flooded:", zone.name)
	check_canals_for_success()

func check_canals_for_success():
	for res in reservoirs.get_children():
		for canal_tile in built_canals:
			var res_pos = res.position / 32
			if canal_tile.distance_to(res_pos) < 3:
				total_score += 10
				print("Water reached reservoir:", res.name)
				break
	end_quest()

func end_quest():
	var message := ""
	if total_score > 0:
		message = "Congratulations! You successfully redirected the floodwaters and saved Egypt’s farms."
	else:
		message = "The floods overwhelmed the fields. Next time, build faster canals!"
	narrator.start_dialogue([message])
	print("Quest complete. Final Score:", total_score)
