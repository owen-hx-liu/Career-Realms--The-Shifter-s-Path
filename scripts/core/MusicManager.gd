extends Node

enum MusicGroup {
	NONE,
	TITLE,
	ENDING_CUTSCENE,
	MAIN_HUB,
	ANCIENT_EGYPT,
	FOREST_CLUSTER,
	LASER_MAP,
	WORLD_ONE,
	WORLD_TWO,
	FARMING_CLUSTER,
	BARN_CLUSTER
}

@export_category("Music Tracks")
@export var title_music: AudioStream
@export var ending_cutscene_music: AudioStream
@export var main_hub_music: AudioStream
@export var ancient_egypt_music: AudioStream
@export var forest_cluster_music: AudioStream
@export var laser_map_music: AudioStream
@export var world_music: AudioStream
@export var world2_music: AudioStream
@export var farming_cluster_music: AudioStream
@export var barn_cluster_music: AudioStream

@export_category("Playback")
@export var autoplay_music: bool = true
@export_range(-40.0, 12.0, 0.1) var music_volume_db: float = -8.0

@export_category("Scene Groups (Advanced)")
@export var title_scene_paths: PackedStringArray = PackedStringArray([
	"res://titlescreen.tscn",
	"res://scenes/TitleScreen.tscn",
	"res://scenes/titlescreenreal.tscn",
	"res://scenes/intro/IntroCutscene.tscn"
])
@export var ending_cutscene_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/ending/EndingCutscene.tscn",
	"res://scenes/ending/EngingCutscene.tscn"
])
@export var main_hub_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/maps/MainHub.tscn",
	"res://scenes/maps/EngineeringHouse.tscn",
	"res://scenes/maps/FarmingHouse.tscn",
	"res://scenes/maps/ArtHouse.tscn",
	"res://scenes/maps/MedicineHouse.tscn",
	"res://scenes/maps/LeadershipHouse.tscn",
	"res://scenes/maps/StarHouse.tscn",
	"res://scenes/maps/starcontainerroom.tscn",
	"res://scenes/maps/Starcontainerroom2.tscn",
	"res://scenes/maps/Starcontainerroom3.tscn",
	"res://scenes/maps/Starcontainerroom4.tscn",
	"res://scenes/maps/Starcontainerroom5.tscn"
])
@export var ancient_egypt_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/maps/AncientEgyptMap.tscn"
])
@export var forest_cluster_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/world_scenes/forest.tscn",
	"res://scenes/world_scenes/AlienBioengineeringQuest.tscn",
	"res://scenes/world_scenes/cave.tscn",
	"res://scenes/Everything_in_healer_hut_scene/healer_hut.tscn",
	"res://scenes/villager_house_scene/village_house_1.tscn",
	"res://scenes/villager_house_scene/village_house_2.tscn",
	"res://scenes/villager_house_scene/village_house_3.tscn",
	"res://scenes/villager_house_scene/village_house_4.tscn",
	"res://scenes/villager_house_scene/village_house_5.tscn",
	"res://scenes/villager_house_scene/village_house_6.tscn",
	"res://scenes/maps/forest.tscn",
	"res://scenes/forest.tscn"
])
@export var laser_map_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/world_scenes/laser_map.tscn",
	"res://scenes/laser_quest.tscn"
])
@export var world_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/World.tscn"
])
@export var world2_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/World2.tscn",
	"res://scenes/map_view.tscn"
])
@export var farming_cluster_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/maps/FamingQuest.tscn",
	"res://scenes/maps/Storehouse.tscn"
])
@export var barn_cluster_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/world_scenes/barnquest.tscn",
	"res://scenes/barn.tscn",
	"res://scenes/control_room.tscn"
])

var _player: AudioStreamPlayer
var _scene_to_group: Dictionary = {}
var _current_group: int = MusicGroup.NONE
var _last_scene_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusic"
	_player.bus = "Master"
	_player.volume_db = music_volume_db
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	if not _player.finished.is_connected(_on_music_finished):
		_player.finished.connect(_on_music_finished)

	_build_scene_lookup()
	refresh_music()

func _process(_delta: float) -> void:
	var scene_path: String = _get_current_scene_path()
	if scene_path == _last_scene_path:
		return

	_last_scene_path = scene_path
	_apply_music_for_scene(scene_path)

func refresh_music() -> void:
	_player.volume_db = music_volume_db
	_last_scene_path = _get_current_scene_path()
	_apply_music_for_scene(_last_scene_path)

func set_music_volume_db(value: float) -> void:
	music_volume_db = value
	if _player:
		_player.volume_db = music_volume_db

func get_music_volume_db() -> float:
	return music_volume_db

func _build_scene_lookup() -> void:
	_scene_to_group.clear()
	_register_scene_group(title_scene_paths, MusicGroup.TITLE)
	_register_scene_group(ending_cutscene_scene_paths, MusicGroup.ENDING_CUTSCENE)
	_register_scene_group(main_hub_scene_paths, MusicGroup.MAIN_HUB)
	_register_scene_group(ancient_egypt_scene_paths, MusicGroup.ANCIENT_EGYPT)
	_register_scene_group(forest_cluster_scene_paths, MusicGroup.FOREST_CLUSTER)
	_register_scene_group(laser_map_scene_paths, MusicGroup.LASER_MAP)
	_register_scene_group(world_scene_paths, MusicGroup.WORLD_ONE)
	_register_scene_group(world2_scene_paths, MusicGroup.WORLD_TWO)
	_register_scene_group(farming_cluster_scene_paths, MusicGroup.FARMING_CLUSTER)
	_register_scene_group(barn_cluster_scene_paths, MusicGroup.BARN_CLUSTER)

func _register_scene_group(scene_paths: PackedStringArray, group: int) -> void:
	for index in range(scene_paths.size()):
		var raw_path: String = scene_paths[index]
		var normalized: String = _normalize_path(raw_path)
		if normalized.is_empty():
			continue
		_scene_to_group[normalized] = group

func _get_current_scene_path() -> String:
	var tree: SceneTree = get_tree()
	if tree == null:
		return ""

	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return ""

	return _normalize_path(current_scene.scene_file_path)

func _apply_music_for_scene(scene_path: String) -> void:
	var group: int = _get_group_for_scene(scene_path)
	if group == MusicGroup.NONE:
		return

	_play_group(group)

func _get_group_for_scene(scene_path: String) -> int:
	var normalized: String = _normalize_path(scene_path)
	if normalized.is_empty():
		return MusicGroup.NONE

	if _scene_to_group.has(normalized):
		return int(_scene_to_group[normalized])

	return MusicGroup.NONE

func _play_group(group: int) -> void:
	var next_track: AudioStream = _get_track_for_group(group)
	if next_track == null:
		_current_group = group
		return

	if group == _current_group and _player.stream == next_track and _player.playing:
		return

	if _player.stream == next_track:
		_current_group = group
		if autoplay_music and not _player.playing:
			_player.play()
		return

	_current_group = group
	_player.stream = next_track

	if autoplay_music:
		_player.play()

func _get_track_for_group(group: int) -> AudioStream:
	match group:
		MusicGroup.TITLE:
			return title_music
		MusicGroup.ENDING_CUTSCENE:
			return ending_cutscene_music
		MusicGroup.MAIN_HUB:
			return main_hub_music
		MusicGroup.ANCIENT_EGYPT:
			return ancient_egypt_music
		MusicGroup.FOREST_CLUSTER:
			return forest_cluster_music
		MusicGroup.LASER_MAP:
			return laser_map_music
		MusicGroup.WORLD_ONE:
			return world_music
		MusicGroup.WORLD_TWO:
			return world2_music
		MusicGroup.FARMING_CLUSTER:
			return farming_cluster_music
		MusicGroup.BARN_CLUSTER:
			return barn_cluster_music
		_:
			return null

func _on_music_finished() -> void:
	if autoplay_music and _player.stream != null:
		_player.play()

func _normalize_path(path: String) -> String:
	return path.strip_edges().to_lower()
