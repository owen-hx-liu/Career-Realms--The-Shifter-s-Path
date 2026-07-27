extends Node2D

@export var quest_id: String = "forest_quest"
@export var domain: String = "Medicine"

var quest_saved: bool = false
var resource_ids: Array[String] = []
var start_collected_count: int = 0

func _ready() -> void:
	# Position player based on global transition state.
	if has_node("player"):
		$player.position = Vector2(global.next_player_x2, global.next_player_y2)

	# Keep global scene state accurate while still using world-style camera behavior.
	global.current_scene = get_tree().get_current_scene().name

	_setup_narrator_once()
	_configure_player_camera_for_forest()
	_cache_resource_state()
	_connect_forest_exit_transitions()

func _setup_narrator_once() -> void:
	if get_tree().get_first_node_in_group("narrator") == null:
		var narrator = preload("res://scenes/narrator copy.tscn").instantiate()
		add_child(narrator)

func _configure_player_camera_for_forest() -> void:
	var player = get_node_or_null("player")
	if player == null:
		return

	var world_cam: Camera2D = player.get_node_or_null("worldcamera")
	if world_cam:
		world_cam.enabled = true
		world_cam.make_current()

		# Match limits to the forest TileMap bounds.
		var tile_map = get_node_or_null("TileMap")
		if tile_map and tile_map.tile_set:
			var used: Rect2i = tile_map.get_used_rect()
			var tile_size: Vector2i = tile_map.tile_set.tile_size
			world_cam.limit_left = used.position.x * tile_size.x
			world_cam.limit_top = used.position.y * tile_size.y
			world_cam.limit_right = (used.position.x + used.size.x) * tile_size.x
			world_cam.limit_bottom = (used.position.y + used.size.y) * tile_size.y

	var house_cam: Camera2D = player.get_node_or_null("housecamera")
	if house_cam:
		house_cam.enabled = false

	var mainhub_cam: Camera2D = player.get_node_or_null("mainhubcamera")
	if mainhub_cam:
		mainhub_cam.enabled = false

	var forest_cam: Camera2D = player.get_node_or_null("forestcamera")
	if forest_cam:
		forest_cam.enabled = false

func _cache_resource_state() -> void:
	var found: Dictionary = {}
	_collect_resource_ids_recursive(self, found)
	resource_ids.clear()
	for key in found.keys():
		resource_ids.append(str(key))
	start_collected_count = _count_collected_resources(resource_ids)
	print("[ForestQuest] Tracking ", resource_ids.size(), " resources. Start collected: ", start_collected_count)

func _collect_resource_ids_recursive(node: Node, found: Dictionary) -> void:
	if node.is_queued_for_deletion():
		return

	var resource_id = node.get("resource_id")
	if typeof(resource_id) == TYPE_STRING and resource_id != "":
		found[resource_id] = true

	for child in node.get_children():
		_collect_resource_ids_recursive(child, found)

func _count_collected_resources(ids: Array[String]) -> int:
	var count: int = 0
	for id in ids:
		if global.is_resource_collected(id):
			count += 1
	return count

func _connect_forest_exit_transitions() -> void:
	for child in get_children():
		if not (child is Area2D):
			continue

		var target_scene = child.get("target_scene_path")
		if typeof(target_scene) != TYPE_STRING or String(target_scene).is_empty():
			continue

		if not child.body_entered.is_connected(_on_forest_exit_body_entered):
			child.body_entered.connect(_on_forest_exit_body_entered)

func _on_forest_exit_body_entered(body: Node2D) -> void:
	if quest_saved:
		return
	if not (body.is_in_group("player") or body.name.to_lower() == "player"):
		return

	_save_forest_quest_result()

func _save_forest_quest_result() -> void:
	if quest_saved:
		return
	quest_saved = true

	var now_collected: int = _count_collected_resources(resource_ids)
	var collected_this_run: int = maxi(0, now_collected - start_collected_count)
	var collectible_this_run: int = maxi(1, resource_ids.size() - start_collected_count)
	var progress_ratio: float = float(collected_this_run) / float(collectible_this_run)

	var stars_earned: int = _stars_from_progress(progress_ratio)
	var best_stars: int = maxi(stars_earned, int(StarManager.get_quest_stars(quest_id)))

	StarManager.record_quest_stars(quest_id, domain, best_stars, 5)
	EndingManager.complete_quest(quest_id, domain, best_stars)

	if DomainInteractionManager:
		var bonuses = DomainInteractionManager.get_bonuses_for_domain(domain)
		LegacyAchievementManager.check_cross_domain_achievements(bonuses.size())
	LegacyAchievementManager.check_star_achievements()
	LegacyAchievementManager.check_speed_achievements()

	print("[ForestQuest] Completed. collected_this_run=", collected_this_run, "/", collectible_this_run, " stars=", stars_earned, " best=", best_stars)

func _stars_from_progress(progress_ratio: float) -> int:
	if progress_ratio >= 0.90:
		return 5
	if progress_ratio >= 0.75:
		return 4
	if progress_ratio >= 0.55:
		return 3
	if progress_ratio >= 0.35:
		return 2
	if progress_ratio > 0.0:
		return 1
	return 0

func _input(event):
	if event.is_action_pressed("reopen_narrator"):
		var narrator = get_tree().get_first_node_in_group("narrator")
		if narrator:
			narrator.visible = true
			narrator.set_process_input(true)
			narrator.call("show_step")
