extends Node2D

@export_range(1, 12, 1) var terraform_radius_tiles: int = 4
@export var tilemap_layer: int = 0
@export var purple_source_id: int = -1
@export var purple_atlas_coords: Vector2i = Vector2i(-1, -1)
@export var green_source_id: int = -1
@export var green_atlas_coords: Vector2i = Vector2i(-1, -1)
@export var green_alternative_tile: int = 0
@export var auto_terraform_on_ready: bool = true

@export_group("Art Slots")
@export var mother_plant_texture: Texture2D = preload("res://assets/generated/alien_quest/mother_plant_texture.png")
@export var life_energy_particle_texture: Texture2D = preload("res://assets/generated/alien_quest/life_energy_particle_texture.png")

@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: CPUParticles2D = $CPUParticles2D
@onready var terraform_patch: Polygon2D = $TerraformPatch

func _ready() -> void:
	if mother_plant_texture:
		sprite.texture = mother_plant_texture

	if life_energy_particle_texture:
		particles.texture = life_energy_particle_texture

	_build_patch_visual()
	particles.restart()

	if auto_terraform_on_ready:
		terraform_world()

func terraform_world() -> void:
	var tilemap: TileMap = _find_first_tilemap(get_tree().current_scene)
	if tilemap == null:
		return

	var center_cell: Vector2i = tilemap.local_to_map(tilemap.to_local(global_position))
	var changed_cells: int = 0

	for x in range(-terraform_radius_tiles, terraform_radius_tiles + 1):
		for y in range(-terraform_radius_tiles, terraform_radius_tiles + 1):
			if Vector2(x, y).length() > float(terraform_radius_tiles) + 0.2:
				continue

			var cell: Vector2i = center_cell + Vector2i(x, y)
			var source_id: int = tilemap.get_cell_source_id(tilemap_layer, cell)
			if source_id < 0:
				continue

			var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(tilemap_layer, cell)
			if not _matches_purple_filter(source_id, atlas_coords):
				continue

			var target_source: int = green_source_id if green_source_id >= 0 else source_id
			var target_atlas: Vector2i = green_atlas_coords if green_atlas_coords != Vector2i(-1, -1) else atlas_coords
			tilemap.set_cell(tilemap_layer, cell, target_source, target_atlas, green_alternative_tile)
			changed_cells += 1

	if changed_cells > 0:
		print("[MotherPlantTerraformer] Terraform complete. Cells changed:", changed_cells)

func _matches_purple_filter(source_id: int, atlas_coords: Vector2i) -> bool:
	if purple_source_id >= 0 and source_id != purple_source_id:
		return false
	if purple_atlas_coords != Vector2i(-1, -1) and atlas_coords != purple_atlas_coords:
		return false
	return true

func _find_first_tilemap(node: Node) -> TileMap:
	if node == null:
		return null
	if node is TileMap:
		return node as TileMap

	for child in node.get_children():
		var found: TileMap = _find_first_tilemap(child)
		if found:
			return found

	return null

func _build_patch_visual() -> void:
	var points := PackedVector2Array()
	var radius_px: float = float(terraform_radius_tiles) * 16.0
	var segments: int = 32
	for i in range(segments):
		var angle: float = (TAU * float(i)) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius_px)

	terraform_patch.polygon = points
	terraform_patch.color = Color(0.31, 0.88, 0.42, 0.28)
