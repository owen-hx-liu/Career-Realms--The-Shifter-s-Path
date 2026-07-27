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

# Domain order for inventory slots
const DOMAIN_ORDER = ["Engineering", "Farming", "Art", "Medicine", "Leadership"]

func _ready():
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node):
	if node == get_tree().current_scene:
		call_deferred("check_and_update_stars")

func check_and_update_stars():
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	# Check if this is a hub scene
	if current_scene_path in HUB_SCENES:
		update_all_domain_stars()

func update_all_domain_stars():
	"""Update hub inventory to show all domain stars with their colors"""
	var hub_inv: Inv = load("res://inventory/hub_inventory.tres")
	var star_item: InvItem = load("res://inventory/items/star_item.tres")
	
	if not hub_inv or not star_item:
		print("[StarInventoryManager] ERROR: Could not load hub inventory or star item")
		return
	
	# Clear all stars from inventory first
	clear_all_stars(hub_inv)
	
	# Add stars for each domain in order
	var slot_index = 0
	for domain in DOMAIN_ORDER:
		var domain_stars = StarManager.get_domain_stars(domain)
		
		if domain_stars > 0:
			# Find next available slot
			if slot_index < hub_inv.slots.size():
				var slot = hub_inv.slots[slot_index]
				slot.item = star_item
				slot.amount = domain_stars
				
				# Store the domain color in metadata
				var domain_color = StarManager.get_domain_color(domain)
				slot.set_meta("star_color", domain_color)
				slot.set_meta("star_domain", domain)
				
				print("[StarInventoryManager] Added ", domain, " stars: ", domain_stars, " to slot ", slot_index)
				slot_index += 1
	
	hub_inv.update.emit()
	print("[StarInventoryManager] Updated all domain stars in hub inventory")

func clear_all_stars(inv: Inv):
	"""Remove all stars from inventory"""
	for slot in inv.slots:
		if slot.item and slot.item.name == "Star":
			slot.item = null
			slot.amount = 0
			if slot.has_meta("star_color"):
				slot.remove_meta("star_color")
			if slot.has_meta("star_domain"):
				slot.remove_meta("star_domain")
