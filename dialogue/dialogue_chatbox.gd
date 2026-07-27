extends Control

@export_file("*.json") var d_file
var dialogue =[]
var current_dialogue_id = 0



# Called when the node enters the scene tree for the first time.
func _ready():
	start() # Replace with function body.

func start():
	dialogue = load_dialogue()
	current_dialogue_id = -1
	next_script()
	
func load_dialogue():
	var file = FileAccess.open("res://dialogue/villager_dialogue1.json", FileAccess.READ)
	var content = file.get_as_text()
	var parsed = JSON.parse_string(content)
	return parsed
 # ✅ This is the actual array of dictionaries
		
	
func _input(event):
	if event.is_action_pressed("ui_accept"):
		next_script()
	
	
func next_script():
	current_dialogue_id +=1
	if current_dialogue_id >= dialogue.size():
			return
			
	$NinePatchRect/name.text = dialogue[current_dialogue_id]['name']
	$NinePatchRect/text.text = dialogue[current_dialogue_id]['text']
	
	

	# Called every frame. 'delta' is the elapsed time since the previous frame.

func _process(delta: float) -> void:
	pass
