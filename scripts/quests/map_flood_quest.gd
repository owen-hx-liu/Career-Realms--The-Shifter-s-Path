extends Node2D

# map_flood_quest.gd - Updated with quest completion system

const CANALS_PER_PILE := 24
var DEBUG_PRINTS: bool = true
var DEBUG_SAMPLE_LIMIT: int = 30

# Scene references
var player: Node = null
var tilemap: TileMap = null
var canal_zones_container: Node = null
var placed_canals_container: Node = null
var flood_zones_container: Node = null
var resource_piles_container: Node = null
var reservoirs_container: Node = null
var river_sources_container: Node = null
var narrator: Node = null
var hud: Node = null
var level_complete_ui: Node = null

# Packed scenes
@export var canal_zone_scene: PackedScene = preload("res://scenes/enviorment/CanalZone.tscn")
@export var canal_tile_scene: PackedScene = preload("res://scenes/enviorment/CanalTile.tscn")

# State
var available_resources: int = 0
var total_capacity: int = 0
var built_canals: Array[Vector2i] = []
var canal_nodes: Dictionary = {}  # Vector2i tile_pos -> canal Node2D (for autotiling)
var total_score: int = 0
var quest_started: bool = false
var quest_completed: bool = false

# Cache
var tile_size: Vector2 = Vector2(16, 16)
var _hud_missing_warned: bool = false

# --- Juice / theming ----------------------------------------------------------
const GAME_FONT := preload("res://art/Cute_Fantasy_Free2/Outdoor decoration/determination/determination.ttf")
const FLOOD_BASE := Color(0.86, 0.16, 0.11, 0.30)      # danger red
const FLOOD_RIM := Color(0.45, 0.06, 0.04, 0.85)
const RESERVOIR_BASE := Color(0.16, 0.56, 0.80, 0.34)  # inviting water blue
const RESERVOIR_RIM := Color(0.82, 0.67, 0.41, 0.95)   # sandstone basin rim
const RESERVOIR_FILLED := Color(0.12, 0.52, 0.78, 0.72)

var flood_running: bool = false
var _flood_polys: Array = []
var _reservoir_polys: Array = []
var _filled_polys: Array = []
var _sfx := {}                       # name -> AudioStreamPlayer
var _bfs_order: Array = []           # cells in the order water reaches them

func _ready() -> void:
	if DEBUG_PRINTS:
		print("[Map] setup start")

	player = get_node_or_null("Player")
	tilemap = get_node_or_null("TileMap")
	canal_zones_container = get_node_or_null("CanalZones")
	placed_canals_container = get_node_or_null("PlacedCanals")
	flood_zones_container = get_node_or_null("FloodZones")
	resource_piles_container = get_node_or_null("ResourcePiles")
	reservoirs_container = get_node_or_null("ReservoirMarkers")
	river_sources_container = get_node_or_null("RiverSources")
	narrator = get_node_or_null("Narrator")
	hud = get_node_or_null("HUD")
	level_complete_ui = get_node_or_null("LevelCompleteUI")

	if level_complete_ui and level_complete_ui.has_signal("return_to_hub"):
		level_complete_ui.connect("return_to_hub", Callable(self, "_on_return_to_hub"))

	if tilemap and tilemap.tile_set:
		tile_size = tilemap.tile_set.tile_size
		if DEBUG_PRINTS:
			print("[Map] Detected tile size:", tile_size)

	_update_hud()
	built_canals.clear()
	canal_nodes.clear()

	if tilemap and canal_zones_container:
		generate_canal_zones_from_tiles()
		_connect_zone_signals()
	else:
		if DEBUG_PRINTS:
			print("[Map] Skipped zone generation — missing nodes")

	_setup_audio()
	_setup_zone_theming()
	start_narrator_intro()
	_apply_domain_bonuses()
	if DEBUG_PRINTS:
		print("[Map] setup complete")

func _apply_domain_bonuses():
	var bonuses = DomainInteractionManager.get_bonuses_for_domain("Engineering")
	if bonuses.is_empty():
		return
	
	print("[Map] Active bonuses: ", bonuses)
	
	if narrator:
		var bonus_text = DomainInteractionManager.get_quest_bonus_summary("Engineering")
		if bonus_text != "No domain bonuses active for this quest":
			narrator.start_dialogue(["Domain Synergies Active!", bonus_text])
	
	LegacyAchievementManager.check_cross_domain_achievements(bonuses.size())
	
func start_narrator_intro() -> void:
	if narrator and narrator.has_method("start_dialogue"):
		narrator.start_dialogue([
			"You arrive in Ancient Egypt.",
			"The Nile threatens to overflow into farmland (areas shown in red).",
			"Gather materials by standing on a pile and pressing P to collect canal segments.",
			"Stand on a buildable tile and press C to place a canal segment.",
			"When you are ready press F to start the flood simulation.",
		])
	quest_started = true


func generate_canal_zones_from_tiles() -> void:
	if DEBUG_PRINTS:
		print("[Map] Generating canal zones...")

	if tilemap == null:
		if DEBUG_PRINTS:
			print("[Map] No tilemap, aborting zone gen")
		return
	if not tilemap.tile_set:
		push_error("[Map] TileMap has no tile_set")
		return

	var used := tilemap.get_used_cells(0)
	if DEBUG_PRINTS:
		print("[Map] Found used cells:", used.size())

	for cell in used:
		var cell_i = Vector2i(int(cell.x), int(cell.y))
		var zone = canal_zone_scene.instantiate()
		zone.tile_position = cell_i

		var local_center: Vector2 = tilemap.map_to_local(cell_i)
		var global_center: Vector2 = tilemap.to_global(local_center)
		zone.global_position = global_center

		if zone.has_method("set_tilemap_reference"):
			zone.set_tilemap_reference(tilemap)

		canal_zones_container.add_child(zone)
		if zone.has_method("deactivate_zone"):
			zone.deactivate_zone()

	if DEBUG_PRINTS:
		print("[Map] Canal zones created:", canal_zones_container.get_child_count())


func _connect_zone_signals() -> void:
	if canal_zones_container == null:
		return
	for zone in canal_zones_container.get_children():
		if not is_instance_valid(zone):
			continue
		if zone.has_signal("build_requested"):
			if not zone.is_connected("build_requested", Callable(self, "_on_zone_build_requested")):
				zone.connect("build_requested", Callable(self, "_on_zone_build_requested"))
		if zone.has_signal("canal_built_signal"):
			if not zone.is_connected("canal_built_signal", Callable(self, "_on_zone_built")):
				zone.connect("canal_built_signal", Callable(self, "_on_zone_built"))


func _process(delta: float) -> void:
	_update_zone_theming()  # keep flood/reservoir overlays pulsing

	if not player or not canal_zones_container:
		return

	# Don't allow input while the quest is over or the flood is playing out.
	if quest_completed or flood_running:
		return

	_update_zone_visibility()

	if Input.is_action_just_pressed("pickup"):
		_attempt_pickup()

	if Input.is_action_just_pressed("flood_start"):
		trigger_flood()

	if Input.is_action_just_pressed("build_canal"):
		_attempt_build()


func _update_zone_visibility() -> void:
	if tilemap == null:
		return

	var player_local: Vector2 = tilemap.to_local(player.global_position)
	var player_tile: Vector2i = tilemap.local_to_map(player_local)

	for zone in canal_zones_container.get_children():
		if not is_instance_valid(zone):
			continue
		if zone.tile_position == player_tile and not zone.canal_built:
			if zone.has_method("activate_zone"):
				zone.activate_zone()
		else:
			if zone.has_method("deactivate_zone"):
				zone.deactivate_zone()


func _attempt_build() -> void:
	if not player or not canal_zones_container or tilemap == null:
		return

	var player_local: Vector2 = tilemap.to_local(player.global_position)
	var player_tile: Vector2i = tilemap.local_to_map(player_local)

	for zone in canal_zones_container.get_children():
		if not is_instance_valid(zone):
			continue
		if zone.tile_position == player_tile:
			_on_zone_build_requested(zone.tile_position)
			return
	if DEBUG_PRINTS:
		print("[Map] No zone found under player for build")


func _on_zone_build_requested(tile_pos: Vector2i) -> void:
	if tile_pos in built_canals:
		if DEBUG_PRINTS:
			print("[Map] Canal already exists at", tile_pos)
		return
	if available_resources <= 0:
		if DEBUG_PRINTS:
			print("[Map] No resources to build")
		if player:
			_spawn_floating_text(player.global_position + Vector2(0, -14), "Need segments!", Color(1.0, 0.5, 0.35), 9)
		return

	available_resources -= 1
	_update_hud()

	_create_canal_tile_at(tile_pos)
	built_canals.append(tile_pos)
	if DEBUG_PRINTS:
		print("[Map] Built canal at", tile_pos)


func _on_zone_built(tile_pos: Vector2i) -> void:
	if DEBUG_PRINTS:
		print("[Map] zone built event:", tile_pos)


func _create_canal_tile_at(tile_pos: Vector2i) -> void:
	if canal_tile_scene == null or tilemap == null or placed_canals_container == null:
		if DEBUG_PRINTS:
			print("[Map] Missing references to create canal tile")
		return

	var target_zone = null
	for z in canal_zones_container.get_children():
		if is_instance_valid(z) and z.tile_position == tile_pos:
			target_zone = z
			break

	var spawn_global: Vector2 = Vector2.ZERO
	if target_zone != null:
		spawn_global = target_zone.global_position
		# Mark the tile as taken so its "Press C" highlight stops showing.
		target_zone.canal_built = true
		if target_zone.has_method("deactivate_zone"):
			target_zone.deactivate_zone()
	else:
		var local_center: Vector2 = tilemap.map_to_local(tile_pos)
		spawn_global = tilemap.to_global(local_center)

	var inst = canal_tile_scene.instantiate()
	inst.global_position = spawn_global
	# Ground-level: the canal is dug into the terrain, so it draws above the
	# ground tiles but below the player/houses (PlacedCanals sits before the
	# Player in the scene tree, so equal z_index resolves in the player's favour).
	inst.z_index = 0
	if "tile_position" in inst:
		inst.tile_position = tile_pos
	if "tile_size" in inst and tilemap.tile_set:
		inst.tile_size = float(tilemap.tile_set.tile_size.x)
	placed_canals_container.add_child(inst)

	canal_nodes[tile_pos] = inst
	_refresh_canal_and_neighbors(tile_pos)

	# placement juice
	_splash(spawn_global)
	_play_sfx("place")

	if DEBUG_PRINTS:
		print("[Map] Created canal visual at", spawn_global)


# --- Canal autotiling ---------------------------------------------------------
# Each canal segment shows arms toward neighbouring canals so adjacent pieces
# read as one continuous waterway. Recompute the placed tile and its 4
# neighbours whenever a canal is added.

const _CANAL_DIRS := {
	"N": Vector2i(0, -1),
	"E": Vector2i(1, 0),
	"S": Vector2i(0, 1),
	"W": Vector2i(-1, 0),
}

func _refresh_canal_and_neighbors(tile_pos: Vector2i) -> void:
	_refresh_canal(tile_pos)
	for d in _CANAL_DIRS.values():
		_refresh_canal(tile_pos + d)

func _refresh_canal(tile_pos: Vector2i) -> void:
	var node = canal_nodes.get(tile_pos)
	if node == null or not is_instance_valid(node):
		return
	var mask := 0
	if canal_nodes.has(tile_pos + _CANAL_DIRS["N"]): mask |= 1  # N
	if canal_nodes.has(tile_pos + _CANAL_DIRS["E"]): mask |= 2  # E
	if canal_nodes.has(tile_pos + _CANAL_DIRS["S"]): mask |= 4  # S
	if canal_nodes.has(tile_pos + _CANAL_DIRS["W"]): mask |= 8  # W
	if node.has_method("set_connections"):
		node.set_connections(mask)


func _update_hud() -> void:
	if hud and hud.has_method("set_canal_count"):
		hud.call("set_canal_count", available_resources)
		return

	# Fallback: write the label directly (it lives at Control/CanalCountLabel).
	var lbl = null
	if hud:
		lbl = hud.get_node_or_null("Control/CanalCountLabel")
		if lbl == null:
			lbl = hud.find_child("CanalCountLabel", true, false)
	if lbl:
		if lbl is Label:
			lbl.text = "Canals: %d" % available_resources
		elif lbl.has_method("set_text"):
			lbl.call("set_text", "Canals: %d" % available_resources)
		return

	if not _hud_missing_warned:
		if DEBUG_PRINTS:
			print("[Map] HUD missing or set_canal_count not found (will not spam)")
		_hud_missing_warned = true


func _attempt_pickup() -> void:
	if resource_piles_container == null or player == null:
		if DEBUG_PRINTS:
			print("[Map] Missing resource piles or player")
		return

	for pile in resource_piles_container.get_children():
		if not is_instance_valid(pile):
			continue
		var dist = player.global_position.distance_to(pile.global_position)
		if dist < 32:
			available_resources += CANALS_PER_PILE
			total_capacity += CANALS_PER_PILE
			_update_hud()
			_spawn_floating_text(pile.global_position + Vector2(0, -10), "+%d" % CANALS_PER_PILE, Color(0.55, 1.0, 0.6), 11)
			_splash(pile.global_position)
			_play_sfx("pickup")
			pile.queue_free()
			if DEBUG_PRINTS:
				print("[Map] Pickup collected +", CANALS_PER_PILE, " now", available_resources, " total_capacity:", total_capacity)
			return
	if DEBUG_PRINTS:
		print("[Map] No pile close enough to pick up")


func trigger_flood() -> void:
	if DEBUG_PRINTS:
		print("[Map] Triggering flood simulation...")

	if flood_zones_container == null or reservoirs_container == null or tilemap == null:
		if DEBUG_PRINTS:
			print("[Map] Missing flood/reservoir/tilemap nodes")
		_show_quest_completion(0)
		return

	flood_running = true
	_bfs_order.clear()
	_play_sfx("flood")
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)

	var built_set := {}
	for v in built_canals:
		var key = str(int(v.x)) + ":" + str(int(v.y))
		built_set[key] = true

	if DEBUG_PRINTS:
		var built_keys_list := []
		for k in built_set.keys():
			built_keys_list.append(k)
			if built_keys_list.size() >= DEBUG_SAMPLE_LIMIT:
				break
		print("[Map] built_set size:", built_set.size(), " sample:", built_keys_list)

	var flood_cells := []
	for fz in flood_zones_container.get_children():
		if not is_instance_valid(fz):
			continue
		var tiles = _collect_tiles_from_node_polygon(fz, tilemap)
		if tiles.size() == 0:
			tiles.append(_resolve_node_to_tile_cell(fz))
		for t in tiles:
			flood_cells.append(t)
		if DEBUG_PRINTS:
			print("[Map][flood] zone:", fz.name, "tiles:", tiles.size())

	var flood_keys := {}
	for c in flood_cells:
		var key_str = str(int(c.x)) + ":" + str(int(c.y))
		flood_keys[key_str] = true

	if DEBUG_PRINTS:
		var sample = []
		for k in flood_keys.keys():
			sample.append(k)
			if sample.size() >= DEBUG_SAMPLE_LIMIT:
				break
		print("[Map] flood cells unique count:", flood_keys.size(), " sample:", sample)

	var reservoir_cells := []
	var reservoir_tile_to_node := {}
	for res in reservoirs_container.get_children():
		if not is_instance_valid(res):
			continue
		var tiles = _collect_tiles_from_node_polygon(res, tilemap)
		if tiles.size() == 0:
			tiles.append(_resolve_node_to_tile_cell(res))
		for t in tiles:
			reservoir_cells.append(t)
			var tk = "%d:%d" % [int(t.x), int(t.y)]
			reservoir_tile_to_node[tk] = res
		if DEBUG_PRINTS:
			print("[Map][res] zone:", res.name, "tiles:", tiles.size())

	var reservoir_keys := {}

	for c in reservoir_cells:
		reservoir_keys["%d:%d" % [int(c.x), int(c.y)]] = true

	if DEBUG_PRINTS:
		var sample_res = []
		for k in reservoir_keys.keys():
			sample_res.append(k)
			if sample_res.size() >= DEBUG_SAMPLE_LIMIT:
				break

		print("[Map] reservoir tiles unique count:", reservoir_keys.size(), " sample:", sample_res)

	var visited := {}
	var queue := []

	for fk in flood_keys.keys():
		visited[fk] = true
		var parts = fk.split(":")
		queue.append(Vector2i(int(parts[0]), int(parts[1])))

	if DEBUG_PRINTS:
		print("[Map] BFS seed queue size:", queue.size())

	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		var curk = str(int(cur.x)) + ":" + str(int(cur.y))
		for d in dirs:
			var nb = cur + d
			var nbk = str(int(nb.x)) + ":" + str(int(nb.y))
			if visited.has(nbk):
				continue
			if built_set.has(nbk) or flood_keys.has(nbk):
				visited[nbk] = true
				queue.append(nb)
				if built_set.has(nbk):
					_bfs_order.append(nb)  # canal reached: wave travels here
				if DEBUG_PRINTS and visited.size() <= 30:
					print("[Map] BFS expand:", curk, "->", nbk)

	var reached_reservoirs := {}
	for rk in reservoir_keys.keys():
		var reservoir_node = reservoir_tile_to_node.get(rk)
		if reservoir_node == null:
			continue
			
		if visited.has(rk):
			reached_reservoirs[reservoir_node] = true
			if DEBUG_PRINTS:
				print("[Map] Reservoir " + str(reservoir_node.name) + " tile " + rk + " is visited -> reached")
		else:
			var parts = rk.split(":")
			var rcell = Vector2i(int(parts[0]), int(parts[1]))
			var adjacent_found = false
			for d in dirs:
				var adj = rcell + d
				var adjk = str(int(adj.x)) + ":" + str(int(adj.y))
				if visited.has(adjk):
					adjacent_found = true
					break
			if adjacent_found:
				reached_reservoirs[reservoir_node] = true
				if DEBUG_PRINTS:
					print("[Map] Reservoir " + str(reservoir_node.name) + " tile " + rk + " is adjacent to visited -> reached")

	var reached_count = reached_reservoirs.size()
	total_score += reached_count * 10

	if DEBUG_PRINTS:
		var vis_sample = []
		for k in visited.keys():
			vis_sample.append(k)
			if vis_sample.size() >= DEBUG_SAMPLE_LIMIT:
				break
		print("[Map] Flood complete — reservoirs filled:", reached_count, " visited count:", visited.size(), " visited sample:", vis_sample)

	# Animate the water rushing along the canals, fill the reservoirs that were
	# reached, then show the completion UI.
	await _play_flood_animation(reached_reservoirs)
	_show_quest_completion(reached_count)


func _show_quest_completion(reservoirs_filled: int) -> void:
	quest_completed = true

	# Check achievements
	
	print("[Map] _show_quest_completion called with reservoirs_filled:", reservoirs_filled)
	print("[Map] level_complete_ui is:", level_complete_ui)
	
	# Disable player movement
	if player:
		if player.has_method("set_can_move"):
			player.set_can_move(false)
			print("[Map] Player movement disabled via set_can_move")
		else:
			player.set_process(false)
			player.set_physics_process(false)
			print("[Map] Player movement disabled via set_process")
	
	# Show narrator dialogue first, UI will show AFTER player dismisses it
	if narrator and narrator.has_method("start_dialogue"):
		if reservoirs_filled > 0:
			narrator.start_dialogue([
				"The canals successfully redirected floodwaters!",
				"%d reservoir(s) received water." % reservoirs_filled
			])
		else:
			narrator.start_dialogue([
				"None of the reservoirs received water.",
				"The farmland has been flooded!"
			])
		
		# Wait for narrator to be completely dismissed (player pressed enter on last dialogue)
		if narrator.has_signal("dialogue_finished"):
			if not narrator.is_connected("dialogue_finished", Callable(self, "_on_narrator_finished")):
				narrator.connect("dialogue_finished", Callable(self, "_on_narrator_finished").bind(reservoirs_filled), CONNECT_ONE_SHOT)
		else:
			# Fallback: if no signal exists, show UI after delay
			print("[Map] No dialogue_finished signal, using timer fallback")
			await get_tree().create_timer(4.0).timeout
			_show_completion_ui(reservoirs_filled)
	else:
		# No narrator, show UI immediately
		_show_completion_ui(reservoirs_filled)


func _on_narrator_finished(reservoirs_filled: int) -> void:
	print("[Map] Narrator dialogue completely finished (player dismissed), showing completion UI")
	_show_completion_ui(reservoirs_filled)


func _show_completion_ui(reservoirs_filled: int) -> void:
	# Show completion UI
	if level_complete_ui:
		print("[Map] level_complete_ui exists, checking for show_completion method")
		if level_complete_ui.has_method("show_completion"):
			print("[Map] Calling show_completion on level_complete_ui")
			level_complete_ui.show_completion(reservoirs_filled)
		else:
			print("[Map] ERROR: level_complete_ui doesn't have show_completion method!")
	else:
		print("[Map] ERROR: level_complete_ui is null!")


func _on_return_to_hub():
	# Return to main hub scene
	get_tree().change_scene_to_file("res://scenes/maps/EngineeringHouse.tscn")


func _collect_tiles_from_node_polygon(node: Node, p_tilemap: TileMap) -> Array:
	var tiles = []
	_collect_tiles_recursive(node, p_tilemap, tiles)
	return tiles

func _collect_tiles_recursive(node: Node, p_tilemap: TileMap, tiles: Array) -> void:
	if node is Polygon2D or node is CollisionPolygon2D:
		var poly = node.polygon
		if poly.size() > 0:
			var world_points = []
			for p in poly:
				world_points.append(node.to_global(p))

			var min_x = INF
			var max_x = -INF
			var min_y = INF
			var max_y = -INF
			for wp in world_points:
				min_x = min(min_x, wp.x)
				max_x = max(max_x, wp.x)
				min_y = min(min_y, wp.y)
				max_y = max(max_y, wp.y)

			var start_cell = p_tilemap.local_to_map(Vector2(min_x, min_y))
			var end_cell = p_tilemap.local_to_map(Vector2(max_x, max_y))

			for y in range(start_cell.y, end_cell.y + 1):
				for x in range(start_cell.x, end_cell.x + 1):
					var cell_center = p_tilemap.map_to_local(Vector2i(x, y))
					if Geometry2D.is_point_in_polygon(cell_center, world_points):
						tiles.append(Vector2i(x, y))
	
	for child in node.get_children():
		_collect_tiles_recursive(child, p_tilemap, tiles)


func _gather_polygon_global_points(node: Node) -> Array:
	var polys := []
	for child in node.get_children():
		if not is_instance_valid(child):
			continue
		if child is Polygon2D:
			var pts := []
			for p in child.polygon:
				pts.append(child.to_global(p))
			if pts.size() > 0:
				polys.append(pts)
		elif child is CollisionPolygon2D:
			var pts2 := []
			for p2 in child.polygon:
				pts2.append(child.to_global(p2))
			if pts2.size() > 0:
				polys.append(pts2)
		else:
			var rec = _gather_polygon_global_points(child)
			for r in rec:
				polys.append(r)
	return polys


func _resolve_node_to_tile_cell(node: Node) -> Vector2i:
	if canal_zones_container and canal_zones_container.get_child_count() > 0:
		var best_zone = null
		var best_dist = 1e9
		for z in canal_zones_container.get_children():
			if not is_instance_valid(z):
				continue
			var d = z.global_position.distance_to(node.global_position)
			if d < best_dist:
				best_dist = d
				best_zone = z
		var tol = max(tile_size.x, tile_size.y) * 0.75
		if best_zone and best_dist <= tol:
			return Vector2i(int(best_zone.tile_position.x), int(best_zone.tile_position.y))
	var centroid = _find_polygon_centroid_in_node(node)
	if centroid != Vector2.ZERO:
		return _world_to_map_cell(centroid)
	return _world_to_map_cell(node.global_position)


func _find_polygon_centroid_in_node(node: Node) -> Vector2:
	for child in node.get_children():
		if not is_instance_valid(child):
			continue
		if child is CollisionPolygon2D:
			var poly = child.polygon
			if poly.size() > 0:
				var sum = Vector2.ZERO
				for p in poly:
					sum += child.to_global(p)
				return sum / poly.size()
		if child is Polygon2D:
			var poly2 = child.polygon
			if poly2.size() > 0:
				var sum2 = Vector2.ZERO
				for p2 in poly2:
					sum2 += child.to_global(p2)
				return sum2 / poly2.size()
		var found = _find_polygon_centroid_in_node(child)
		if found != Vector2.ZERO:
			return found
	return Vector2.ZERO


func _world_to_map_cell(world_pos: Vector2) -> Vector2i:
	if tilemap == null:
		return Vector2i.ZERO
	if tilemap.has_method("world_to_map"):
		var c = tilemap.world_to_map(world_pos)
		return Vector2i(int(c.x), int(c.y))
	var local_v = tilemap.to_local(world_pos)
	var cell = tilemap.local_to_map(local_v)
	return Vector2i(int(cell.x), int(cell.y))


func _notify_narrator_with_reached_count(reached_count: int) -> void:
	if narrator and narrator.has_method("start_dialogue"):
		if reached_count > 0:
			narrator.start_dialogue([
				"The canals successfully redirected floodwaters!",
				"%d reservoir(s) received water." % reached_count
			])
		else:
			narrator.start_dialogue([
				"None of the reservoirs received water.",
				"Try connecting canals directly from flood zones to reservoirs."
			])
	else:
		if reached_count > 0:
			print("The canals successfully redirected floodwaters!")
			print("%d reservoir(s) received water." % reached_count)
		else:
			print("None of the reservoirs received water.")
			print("Try connecting canals directly from flood zones to reservoirs.")


# --- Juice helpers ------------------------------------------------------------

func _setup_audio() -> void:
	var files := {
		"place": "res://assets/generated/sfx/place_canal.wav",
		"pickup": "res://assets/generated/sfx/pickup.wav",
		"flood": "res://assets/generated/sfx/flood.wav",
	}
	for k in files.keys():
		var path: String = files[k]
		if ResourceLoader.exists(path):
			var pl := AudioStreamPlayer.new()
			pl.stream = load(path)
			pl.volume_db = -8.0
			add_child(pl)
			_sfx[k] = pl

func _play_sfx(n: String) -> void:
	if _sfx.has(n) and is_instance_valid(_sfx[n]):
		_sfx[n].play()


func _setup_zone_theming() -> void:
	_flood_polys.clear()
	_reservoir_polys.clear()
	if flood_zones_container:
		_collect_polys(flood_zones_container, _flood_polys)
	if reservoirs_container:
		_collect_polys(reservoirs_container, _reservoir_polys)
	for p in _flood_polys:
		p.self_modulate = Color.WHITE
		p.color = FLOOD_BASE
		_add_rim(p, FLOOD_RIM, 1.5)
	for p in _reservoir_polys:
		p.self_modulate = Color.WHITE
		p.color = RESERVOIR_BASE
		_add_rim(p, RESERVOIR_RIM, 2.0)

func _collect_polys(node: Node, arr: Array) -> void:
	for c in node.get_children():
		if c is Polygon2D and c.polygon.size() >= 3:
			arr.append(c)
		_collect_polys(c, arr)

func _add_rim(poly: Polygon2D, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = poly.polygon
	line.closed = true
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = 1
	poly.add_child(line)

func _update_zone_theming() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var fa: float = clampf(FLOOD_BASE.a + sin(t * 2.6) * 0.12, 0.0, 1.0)
	for p in _flood_polys:
		if is_instance_valid(p) and not (p in _filled_polys):
			p.color = Color(FLOOD_BASE.r, FLOOD_BASE.g, FLOOD_BASE.b, fa)
	var ra: float = clampf(RESERVOIR_BASE.a + sin(t * 1.5) * 0.10, 0.0, 1.0)
	for p in _reservoir_polys:
		if is_instance_valid(p) and not (p in _filled_polys):
			p.color = Color(RESERVOIR_BASE.r, RESERVOIR_BASE.g, RESERVOIR_BASE.b, ra)


func _spawn_floating_text(gpos: Vector2, text: String, color: Color, size: int = 10) -> void:
	var l := Label.new()
	l.text = ""
	l.modulate = color
	l.z_index = 60
	l.add_theme_font_override("font", GAME_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.12))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	l.global_position = gpos - Vector2(size * 0.6, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector2(0, -16), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func _splash(gpos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = gpos
	p.z_index = 40
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 55.0
	p.gravity = Vector2(0, 240)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Color(0.45, 0.82, 1.0)
	add_child(p)
	p.finished.connect(p.queue_free)


func _flash_canal(node: Node2D) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color(1.6, 1.7, 1.9, 1.0), 0.10)
	tw.tween_property(node, "modulate", Color(1.12, 1.16, 1.25, 1.0), 0.25)


func _play_flood_animation(reached: Dictionary) -> void:
	# Water rushes along the connected canals in the order it reached them.
	for cell in _bfs_order:
		var node = canal_nodes.get(cell)
		if node and is_instance_valid(node):
			_flash_canal(node)
		await get_tree().create_timer(0.025).timeout
	await get_tree().create_timer(0.25).timeout
	# Fill the reservoirs that got water; flash the ones that didn't.
	if reservoirs_container:
		for res in reservoirs_container.get_children():
			if is_instance_valid(res):
				_fill_reservoir(res, reached.has(res))
	await get_tree().create_timer(0.9).timeout


func _fill_reservoir(res_node: Node, ok: bool) -> void:
	var polys: Array = []
	_collect_polys(res_node, polys)
	for p in polys:
		if not is_instance_valid(p):
			continue
		_filled_polys.append(p)
		var tw: Tween = p.create_tween()
		if ok:
			tw.tween_property(p, "color", RESERVOIR_FILLED, 0.5)
		else:
			tw.tween_property(p, "color", Color(0.9, 0.2, 0.15, 0.6), 0.18)
			tw.tween_property(p, "color", RESERVOIR_BASE, 0.4)
	var centroid := _find_polygon_centroid_in_node(res_node)
	if centroid == Vector2.ZERO and res_node is Node2D:
		centroid = (res_node as Node2D).global_position
	_pop_marker(centroid, ok)


func _pop_marker(gpos: Vector2, ok: bool) -> void:
	var holder := Node2D.new()
	holder.global_position = gpos
	holder.z_index = 60
	holder.scale = Vector2.ZERO
	add_child(holder)
	if ok:
		var l := Line2D.new()
		l.points = PackedVector2Array([Vector2(-5, 0), Vector2(-1.5, 4), Vector2(6, -5)])
		l.width = 2.5
		l.default_color = Color(0.45, 1.0, 0.55)
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		holder.add_child(l)
	else:
		for seg in [[Vector2(-5, -5), Vector2(5, 5)], [Vector2(5, -5), Vector2(-5, 5)]]:
			var l := Line2D.new()
			l.points = PackedVector2Array(seg)
			l.width = 2.5
			l.default_color = Color(1.0, 0.4, 0.32)
			l.begin_cap_mode = Line2D.LINE_CAP_ROUND
			l.end_cap_mode = Line2D.LINE_CAP_ROUND
			holder.add_child(l)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector2(3, 3), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(holder, "modulate:a", 0.0, 0.4)
	tw.tween_callback(holder.queue_free)
