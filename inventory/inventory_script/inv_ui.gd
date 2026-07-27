extends Control

@onready var slots: Array = $NinePatchRect/GridContainer.get_children()
@onready var inv: Inv = preload("res://inventory/playerinventory.tres")

var is_open = false
var current_tab = "inventory" # "inventory" or "achievements"

# Hub scenes that use the shared star inventory
const HUB_SCENES = [
	"res://scenes/maps/MainHub.tscn",
	"res://scenes/maps/StarHouse.tscn",
	"res://scenes/maps/starcontainerroom.tscn",
	"res://scenes/maps/Starcontainerroom2.tscn",
	"res://scenes/maps/FarmingHouse.tscn",
	"res://scenes/maps/EngineeringHouse.tscn",
	"res://scenes/maps/ArtHouse.tscn"
]

# Achievement display elements
var achievement_panel: Panel = null
var achievement_container: VBoxContainer = null
var achievement_title: Label = null
var achievement_progress: Label = null
var inventory_tab_button: Button = null
var achievement_tab_button: Button = null

func _ready() -> void:
	print("[inv_ui] Starting _ready()")
	
	# Override with hub inventory if in a hub scene
	var current_scene_path = get_tree().current_scene.scene_file_path
	print("[inv_ui] Current scene path: ", current_scene_path)
	
	var is_hub_scene = current_scene_path in HUB_SCENES
	
	if is_hub_scene:
		inv = load("res://inventory/hub_inventory.tres")
		print("[inv_ui] Using hub inventory (with stars)")
		
		# Only create achievement UI in hub scenes
		call_deferred("_create_achievement_panel")
	else:
		print("[inv_ui] Using player inventory")
	
	if inv:
		print("[inv_ui] Inventory loaded successfully, slots count: ", inv.slots.size())
		if inv.has_method("ensure_slot_count"):
			inv.ensure_slot_count(slots.size())
		inv.update.connect(update_slots)
		update_slots()
	else:
		print("[inv_ui] ERROR: Inventory is null!")
	
	# Store if this is a hub scene for later use
	set_meta("is_hub_scene", is_hub_scene)
	
	# Connect to achievement signals
	if LegacyAchievementManager:
		if not LegacyAchievementManager.achievement_unlocked.is_connected(_on_achievement_unlocked):
			LegacyAchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	
	close()

func _create_achievement_panel():
	print("[inv_ui] Creating achievement panel")
	
	# --- 2. POSITIONING FIX: Left Side Panel ---
	achievement_panel = Panel.new()
	achievement_panel.visible = false
	add_child(achievement_panel)
	
	# Anchor to the left side of the screen
	# Top-Left corner with some padding
	achievement_panel.anchor_left = 0.05
	achievement_panel.anchor_top = 0.00
	achievement_panel.anchor_right = 0.35 # Occupy 30% of screen width
	achievement_panel.anchor_bottom = 0.90
	
	# Ensure it doesn't get too small
	achievement_panel.custom_minimum_size = Vector2(300, 400)
	
	# Title
	achievement_title = Label.new()
	achievement_title.text = "Legacy Achievements"
	achievement_title.add_theme_font_size_override("font_size", 24)
	achievement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievement_panel.add_child(achievement_title)
	achievement_title.anchor_left = 0
	achievement_title.anchor_right = 1
	achievement_title.offset_top = 15
	achievement_title.offset_bottom = 45
	
	# Progress label
	achievement_progress = Label.new()
	achievement_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievement_panel.add_child(achievement_progress)
	achievement_progress.anchor_left = 0
	achievement_progress.anchor_right = 1
	achievement_progress.offset_top = 50
	achievement_progress.offset_bottom = 70
	
	# Scroll container for achievements
	var scroll = ScrollContainer.new()
	achievement_panel.add_child(scroll)
	
	# Anchor scroll to fill most of the panel
	scroll.anchor_left = 0.05
	scroll.anchor_right = 0.95
	scroll.anchor_top = 0.2  # Start 20% down
	scroll.anchor_bottom = 0.95
	
	# Container for achievement items
	achievement_container = VBoxContainer.new()
	# Make width dynamic to fit scroll container
	achievement_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(achievement_container)
	
	# Create tab buttons
	_create_tab_buttons()
	
	print("[inv_ui] Achievement panel created")

func _create_tab_buttons():
	# --- 2. POSITIONING FIX: Neat Left Alignment ---
	
	var button_width = 140
	var button_height = 40
	var start_x = 0.05 # Match panel anchor_left
	var start_y = -0.17 # Just above the panel (which starts at 0.15)
	
	# Inventory Button
	inventory_tab_button = Button.new()
	inventory_tab_button.text = "Inventory [TAB]"
	add_child(inventory_tab_button)
	inventory_tab_button.pressed.connect(_switch_to_inventory)
	
	# Set anchors/offsets to position top-left
	inventory_tab_button.anchor_left = start_x
	inventory_tab_button.anchor_top = start_y
	inventory_tab_button.custom_minimum_size = Vector2(button_width, button_height)
	
	# Achievements Button (Placed to the right of Inventory button)
	achievement_tab_button = Button.new()
	achievement_tab_button.text = "Achievements"
	add_child(achievement_tab_button)
	achievement_tab_button.pressed.connect(_switch_to_achievements)
	
	# Position next to inventory button
	achievement_tab_button.anchor_left = start_x
	achievement_tab_button.anchor_top = start_y
	achievement_tab_button.offset_left = button_width + 10 # 10px gap
	achievement_tab_button.custom_minimum_size = Vector2(button_width, button_height)
	
	# Hide buttons initially
	inventory_tab_button.visible = false
	achievement_tab_button.visible = false

func _switch_to_inventory():
	current_tab = "inventory"
	$NinePatchRect.visible = true
	if achievement_panel:
		achievement_panel.visible = false
	
	# Visual feedback on buttons
	if inventory_tab_button: inventory_tab_button.modulate = Color(1.2, 1.2, 1.2) # Bright
	if achievement_tab_button: achievement_tab_button.modulate = Color(0.7, 0.7, 0.7) # Dim
		
	print("[inv_ui] Switched to inventory tab")

func _switch_to_achievements():
	if not achievement_panel:
		print("[inv_ui] Achievement panel not created (not in hub scene)")
		return
	
	current_tab = "achievements"
	$NinePatchRect.visible = false
	achievement_panel.visible = true
	_update_achievement_display()
	
	# Visual feedback on buttons
	if inventory_tab_button: inventory_tab_button.modulate = Color(0.7, 0.7, 0.7)
	if achievement_tab_button: achievement_tab_button.modulate = Color(1.2, 1.2, 1.2)
	
	print("[inv_ui] Switched to achievements tab")

func _update_achievement_display():
	if not achievement_container:
		return
	
	print("[inv_ui] Updating achievement display")
	
	# Clear existing achievement displays
	for child in achievement_container.get_children():
		child.queue_free()
	
	# Update progress
	if LegacyAchievementManager:
		var progress = LegacyAchievementManager.get_progress_percentage()
		var unlocked_count = LegacyAchievementManager.get_unlocked_achievements().size()
		var total_count = LegacyAchievementManager.achievements.size()
		achievement_progress.text = "Unlocked: %d / %d (%.1f%%)" % [unlocked_count, total_count, progress]
		
		# Display all achievements
		for ach_id in LegacyAchievementManager.achievements.keys():
			var ach = LegacyAchievementManager.achievements[ach_id]
			_create_achievement_item(ach)
	
	# Show active domain interactions
	_show_domain_interactions()

func _create_achievement_item(achievement):
	var item = PanelContainer.new()
	# Use expand flags so it fits the new left-panel width
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.custom_minimum_size = Vector2(0, 80) 
	achievement_container.add_child(item)
	
	var hbox = HBoxContainer.new()
	item.add_child(hbox)
	
	# --- 1. IMAGE FIX: Use TextureRect instead of ColorRect ---
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Try to load the icon
	if achievement.icon_path != "" and ResourceLoader.exists(achievement.icon_path):
		icon.texture = load(achievement.icon_path)
		# If locked, maybe darken it?
		if not achievement.unlocked:
			icon.modulate = Color(0.2, 0.2, 0.2, 1.0) # Dark silhouette
	else:
		# Fallback if image not found (keep your old square logic as backup)
		print("[inv_ui] Icon not found: ", achievement.icon_path)
		var fallback = ColorRect.new()
		fallback.custom_minimum_size = Vector2(64, 64)
		fallback.color = Color(1, 0.84, 0) if achievement.unlocked else Color(0.3, 0.3, 0.3)
		icon.add_child(fallback)
		
	hbox.add_child(icon)
	
	# Text container
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Take remaining space
	hbox.add_child(vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = achievement.title
	title_label.add_theme_font_size_override("font_size", 16) # Slightly smaller for side panel
	if achievement.unlocked:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0)) # Gold
	else:
		title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(title_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = achievement.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not achievement.unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)
	
	# Unlock date (if unlocked)
	if achievement.unlocked and achievement.unlock_date > 0:
		var date_label = Label.new()
		var date_dict = Time.get_datetime_dict_from_unix_time(achievement.unlock_date)
		date_label.text = "Unlocked: %d/%d/%d" % [date_dict.month, date_dict.day, date_dict.year]
		date_label.add_theme_font_size_override("font_size", 9)
		date_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		vbox.add_child(date_label)

func _show_domain_interactions():
	if not DomainInteractionManager:
		return
	
	# Add separator
	var separator = Label.new()
	separator.text = "\n=== Active Domain Interactions ==="
	separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	separator.add_theme_font_size_override("font_size", 14)
	achievement_container.add_child(separator)
	
	# Get all active interactions
	var interactions = DomainInteractionManager.get_all_active_interactions()
	
	if interactions.is_empty():
		var none_label = Label.new()
		none_label.text = "No active domain interactions yet."
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		none_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		achievement_container.add_child(none_label)
		return
	
	# Display each interaction
	for interaction in interactions:
		var item = PanelContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.custom_minimum_size = Vector2(0, 60)
		achievement_container.add_child(item)
		
		var vbox = VBoxContainer.new()
		item.add_child(vbox)
		
		var title = Label.new()
		title.text = "%s → %s" % [interaction.source, interaction.target]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", StarManager.get_domain_color(interaction.source))
		vbox.add_child(title)
		
		var desc = Label.new()
		desc.text = interaction.description
		desc.add_theme_font_size_override("font_size", 11)
		vbox.add_child(desc)

func _on_achievement_unlocked(achievement):
	# Show a popup notification
	print("[inv_ui] Achievement unlocked: ", achievement.title)
	# Update display if achievements tab is open
	if current_tab == "achievements" and achievement_panel and achievement_panel.visible:
		_update_achievement_display()

func update_slots():
	# First clear every UI slot so stale/default text never leaks through.
	for i in range(slots.size()):
		var clear_slot: Node = slots[i]
		if clear_slot and clear_slot.has_method("update"):
			clear_slot.call("update", null)
	
	if not inv:
		return
	
	var slot_count: int = mini(inv.slots.size(), slots.size())
	for i in range(slot_count):
		var ui_slot: Node = slots[i]
		if ui_slot and ui_slot.has_method("update"):
			ui_slot.call("update", inv.slots[i])
	# Update selection highlighting
	update_selection_visual()

func update_selection_visual():
	"""Update which slot appears highlighted - SUPER BRIGHT"""
	# Don't highlight slots in hub scenes
	if get_meta("is_hub_scene", false):
		for i in range(slots.size()):
			slots[i].modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	
	var selected = GameState.selected_inventory_slot if "selected_inventory_slot" in GameState else 0
	
	for i in range(slots.size()):
		if i == selected:
			# SUPER BRIGHT highlight
			slots[i].modulate = Color(1.5, 1.5, 1.5, 1.0)
		else:
			# Normal appearance
			slots[i].modulate = Color(1.0, 1.0, 1.0, 1.0)

func close():
	visible = false
	is_open = false
	
	# Hide tab buttons
	if inventory_tab_button:
		inventory_tab_button.visible = false
	if achievement_tab_button:
		achievement_tab_button.visible = false

func open():
	visible = true
	is_open = true
	_switch_to_inventory() # Always start on inventory tab
	update_selection_visual()
	
	# Show tab buttons only in hub scenes
	if get_meta("is_hub_scene", false):
		if inventory_tab_button:
			inventory_tab_button.visible = true
		if achievement_tab_button:
			achievement_tab_button.visible = true

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("i"):
		if is_open:
			close()
		else:
			open()
	
	# Tab switching with TAB key (only in hub scenes when inventory is open)
	if is_open and get_meta("is_hub_scene", false):
		if Input.is_action_just_pressed("ui_focus_next"): # TAB key
			if current_tab == "inventory":
				_switch_to_achievements()
			else:
				_switch_to_inventory()
	
	# Continuously update selection visual while inventory is open
	if is_open and current_tab == "inventory":
		update_selection_visual()
