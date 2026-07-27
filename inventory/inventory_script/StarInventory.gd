extends Node

# Add as Autoload: Project Settings -> Autoload -> StarInventoryManager

const HUB_SCENES = [
	"res://scenes/maps/MainHub.tscn",
	"res://scenes/maps/StarHouse.tscn",
	"res://scenes/maps/starcontainerroom.tscn",
	"res://scenes/maps/Starcontainerroom2.tscn",
	"res://scenes/maps/FarmingHouse.tscn",
	"res://scenes/maps/EngineeringHouse.tscn",
	"res://scenes/maps/ArtHouse.tscn"
]

func _ready():
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node):
	if node == get_tree().current_scene:
		call_deferred("check_and_update_stars")

func check_and_update_stars():
	var current_scene_path = get_tree().current_scene.scene_file_path
	if current_scene_path in HUB_SCENES:
		update_star_count()

func update_star_count():
	var hub_inv: Inv = load("res://inventory/hub_inventory.tres")
	var star_item: InvItem = load("res://inventory/items/star_item.tres")
	
	if not hub_inv or not star_item:
		return
	
	var total_stars = StarManager.get_total_stars()
	
	# Remove all existing stars first
	hub_inv.remove("Star", 9999)
	
	# Add the current star count
	for i in range(total_stars):
		hub_inv.insert(star_item)
	
	print("[StarInventoryManager] Updated stars: ", total_stars)
