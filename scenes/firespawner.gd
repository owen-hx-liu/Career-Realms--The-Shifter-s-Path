extends Node2D

@onready var fire_scene = preload("res://scenes/fire.tscn")
@onready var sinkhole_scene = preload("res://scenes/sinkhole.tscn")

@export var spawn_count: int = 10
@export var sinkhole_spawn_count: int = 8
@export var map_left_x: float = -792
@export var map_right_x: float = 408
@export var map_top_y: float = -801
@export var map_bottom_y: float = 400

func _ready():
	print("FireSpawner _ready() called!")
	await get_tree().create_timer(0.5).timeout
	spawn_fires()
	spawn_sinkholes()

func spawn_fires():
	print("Spawning ", spawn_count, " fires randomly across the map...")
	
	for i in range(spawn_count):
		var fire = fire_scene.instantiate()
		
		var random_x = randf_range(map_left_x, map_right_x)
		var random_y = randf_range(map_top_y, map_bottom_y)
		
		fire.global_position = Vector2(random_x, random_y)
		
		get_parent().add_child(fire)
		print("Fire #", i, " spawned at: ", fire.global_position)

func spawn_sinkholes():
	print("Spawning ", sinkhole_spawn_count, " sinkholes randomly across the map...")
	
	for i in range(sinkhole_spawn_count):
		var sinkhole = sinkhole_scene.instantiate()
		
		var random_x = randf_range(map_left_x, map_right_x)
		var random_y = randf_range(map_top_y, map_bottom_y)
		
		sinkhole.global_position = Vector2(random_x, random_y)
		
		get_parent().add_child(sinkhole)
		print("Sinkhole #", i, " spawned at: ", sinkhole.global_position)
