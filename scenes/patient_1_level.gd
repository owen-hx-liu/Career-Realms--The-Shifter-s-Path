extends Node2D

@onready var nanobots = [$Nanobot1, $Nanobot2, $Nanobot3, $Nanobot4]
var active_index: int = 0
@export var patient_room_scene: String = ""

var total_sites: int = 0
var repaired_sites: int = 0

func _ready():
	set_active_nanobot(0)
	total_sites = get_tree().get_nodes_in_group("repair_sites").size()

func set_active_nanobot(index: int):
	for i in nanobots.size():
		nanobots[i].is_active = (i == index)
	active_index = index

func _process(delta):
	if Input.is_action_just_pressed("ui_1"):
		set_active_nanobot(0)
	if Input.is_action_just_pressed("ui_2"):
		set_active_nanobot(1)
	if Input.is_action_just_pressed("ui_3"):
		set_active_nanobot(2)
	if Input.is_action_just_pressed("ui_4"):
		set_active_nanobot(3)

func on_site_repaired():
	repaired_sites += 1
	var percent = float(repaired_sites) / float(total_sites) * 100
	print("Repaired: ", percent, "%")
	
	if repaired_sites >= total_sites:
		await get_tree().create_timer(2.0).timeout
		Global.completed_patients.append("patient_1")
		Global.spawn_point = "from_level"
		SceneManager.change_scene(patient_room_scene)
