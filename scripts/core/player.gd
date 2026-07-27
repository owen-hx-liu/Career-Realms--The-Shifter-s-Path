extends CharacterBody2D

const SPEED: int = 100
const MASTER_SEED_ACTION: StringName = &"place_master_seed"
const MASTER_SEED_ITEM_NAME: String = "Master Seed"
var current_dir: String = "none"
var can_place: bool = false
var flood_quest = null
var total_objects_placed: int = 0
var _last_camera_scene_name: String = ""

@onready var score_label = $CanvasLayer/Label

@export var mirror_scene: PackedScene
@export var color_filter_scene: PackedScene 
@export var master_seed_scene: PackedScene = preload("res://scenes/enviorment/mother_plant_terraformer.tscn")

# Inventory resource
var inv: Inv = preload("res://inventory/playerinventory.tres")

func player():
	pass

func _ready() -> void:
	add_to_group("player")
	_ensure_master_seed_action()
	
	var root = get_tree().get_current_scene()
	if root:
		flood_quest = root.get_node_or_null("FloodQuest")
	if score_label:
		score_label.text = "Total Objects Placed: 0"
	
	call_deferred("setup_cameras")

func _physics_process(delta: float) -> void:
	player_movement(delta)
	move_and_slide()
	current_camera()
	handle_mirror_placement()
	handle_filter_placement()
	handle_master_seed_placement()

	if Input.is_action_just_pressed("ui_accept"):
		print("Player position:", global_position)

func player_movement(delta: float) -> void:
	if Input.is_action_pressed("ui_right"):
		current_dir = "right"
		play_anim(1)
		velocity.x = SPEED
		velocity.y = 0
	elif Input.is_action_pressed("ui_left"):
		current_dir = "left"
		play_anim(1)
		velocity.x = -SPEED
		velocity.y = 0
	elif Input.is_action_pressed("ui_down"):
		current_dir = "down"
		play_anim(1)
		velocity.x = 0
		velocity.y = SPEED
	elif Input.is_action_pressed("ui_up"):
		current_dir = "up"
		play_anim(1)
		velocity.x = 0
		velocity.y = -SPEED
	else:
		play_anim(0)
		velocity = Vector2.ZERO

func play_anim(movement: int) -> void:
	if not has_node("AnimatedSprite2D"):
		return
	var anim = $AnimatedSprite2D
	
	if current_dir == "right":
		anim.flip_h = false
		anim.play("side_walk" if movement == 1 else "side_idle")
	elif current_dir == "left":
		anim.flip_h = true
		anim.play("side_walk" if movement == 1 else "side_idle")
	elif current_dir == "down":
		anim.flip_h = false
		anim.play("front_walk" if movement == 1 else "front_idle")
	elif current_dir == "up":
		anim.flip_h = false
		anim.play("back_walk" if movement == 1 else "back_idle")

func handle_mirror_placement():
	if Input.is_action_just_pressed("place_mirror"):
		if mirror_scene:
			spawn_object(mirror_scene)

func handle_filter_placement():
	if Input.is_action_just_pressed("place_filter"):
		if color_filter_scene:
			spawn_object(color_filter_scene)

func handle_master_seed_placement() -> void:
	if not Input.is_action_just_pressed(MASTER_SEED_ACTION):
		return
	if master_seed_scene == null:
		print("[Player] No master_seed_scene assigned.")
		return
	if not inv.has_item(MASTER_SEED_ITEM_NAME):
		print("[Player] Master Seed not found in inventory.")
		return

	var plant := master_seed_scene.instantiate()
	plant.global_position = global_position
	get_parent().add_child(plant)
	inv.remove(MASTER_SEED_ITEM_NAME, 1)
	print("[Player] Master Seed planted. Terraform pulse deployed.")

func _ensure_master_seed_action() -> void:
	if InputMap.has_action(MASTER_SEED_ACTION):
		return

	InputMap.add_action(MASTER_SEED_ACTION)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	InputMap.action_add_event(MASTER_SEED_ACTION, event)

func spawn_object(scene_to_spawn: PackedScene):
	var new_obj = scene_to_spawn.instantiate()
	new_obj.global_position = global_position + Vector2(10, 0)
	get_parent().add_child(new_obj)
	total_objects_placed += 1
	if score_label:
		score_label.text = "Total Objects Placed: " + str(total_objects_placed)

func setup_cameras() -> void:
	current_camera(true)

func _get_current_scene_name() -> String:
	if get_tree() and get_tree().current_scene:
		return str(get_tree().current_scene.name)
	return ""

func _is_house_scene(scene_name: String) -> bool:
	var lower = scene_name.to_lower()
	return lower.begins_with("house")

func _is_interior_scene(scene_name: String) -> bool:
	var lower = scene_name.to_lower()
	if lower.begins_with("house"):
		return false
	return lower.contains("house") \
		or lower.contains("starcontainerroom") \
		or lower == "storehouse" \
		or lower.contains("library")

func _disable_all_cameras() -> void:
	if has_node("worldcamera"):
		$worldcamera.enabled = false
	if has_node("housecamera"):
		$housecamera.enabled = false
	if has_node("mainhubcamera"):
		$mainhubcamera.enabled = false

func _find_first_tilemap(node: Node) -> Node:
	if node is TileMap or node is TileMapLayer:
		return node
	for child in node.get_children():
		var found = _find_first_tilemap(child)
		if found:
			return found
	return null

func _configure_world_camera_limits() -> void:
	if not has_node("worldcamera"):
		return

	var cam: Camera2D = $worldcamera
	var root = get_tree().current_scene
	if root == null:
		return

	var map_node = _find_first_tilemap(root)
	if map_node == null or not map_node.has_method("get_used_rect"):
		# Safe fallback so camera never gets stuck in one corner.
		cam.limit_left = -20000
		cam.limit_top = -20000
		cam.limit_right = 20000
		cam.limit_bottom = 20000
		return

	var used_rect = map_node.get_used_rect()
	var tile_size = Vector2i(16, 16)
	var tile_set = map_node.get("tile_set")
	if tile_set != null:
		tile_size = tile_set.tile_size

	cam.limit_left = int(used_rect.position.x * tile_size.x)
	cam.limit_top = int(used_rect.position.y * tile_size.y)
	cam.limit_right = int((used_rect.position.x + used_rect.size.x) * tile_size.x)
	cam.limit_bottom = int((used_rect.position.y + used_rect.size.y) * tile_size.y)

func current_camera(force: bool = false) -> void:
	var scene_name = _get_current_scene_name()
	if scene_name == "":
		return
	if not force and scene_name == _last_camera_scene_name:
		return

	_last_camera_scene_name = scene_name
	global.current_scene = scene_name
	_disable_all_cameras()

	if scene_name == "MainHub":
		if has_node("mainhubcamera"):
			$mainhubcamera.enabled = true
		return

	if _is_house_scene(scene_name):
		if has_node("housecamera"):
			$housecamera.enabled = true
		return

	# Keep interior hub scenes on the legacy world-camera limits
	# (avoids overfitting to sparse TileMap used_rect bounds).
	if _is_interior_scene(scene_name):
		if has_node("worldcamera"):
			$worldcamera.enabled = true
		return

	# Default camera mode for open maps/quests.
	if has_node("worldcamera"):
		$worldcamera.enabled = true
		_configure_world_camera_limits()

func collect(item):
	inv.insert(item)

func has_potion(potion_name: String) -> bool:
	return inv.has_item(potion_name)

func place_canal():
	if flood_quest and "quest_active" in flood_quest and flood_quest.quest_active:
		var canal_scene = preload("res://scenes/enviorment/CanalTile.tscn")
		var canal_instance = canal_scene.instantiate()
		canal_instance.position = position
		get_parent().add_child(canal_instance)
