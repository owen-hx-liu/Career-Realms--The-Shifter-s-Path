extends StaticBody2D

@export var nanobot_level: String = ""
@export var patient_id: String = ""

@onready var label = $Label
@onready var interaction_zone = $InteractionZone
@onready var checkmark = $Checkmark

var player_nearby: bool = false

func _ready():
	label.visible = false
	checkmark.visible = Global.completed_patients.has(patient_id)
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		label.visible = true
		player_nearby = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		label.visible = false
		player_nearby = false

func _process(delta):
	if player_nearby and Input.is_action_just_pressed("ui_interact"):
		SceneManager.change_scene(nanobot_level)
