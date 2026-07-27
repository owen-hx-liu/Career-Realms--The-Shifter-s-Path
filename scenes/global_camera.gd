extends Camera2D

var target = null

func _ready():
	# Make this camera current
	make_current()

func _process(_delta):
	# Follow the target if it exists
	if target:
		global_position = target.global_position

func set_target(new_target):
	target = new_target
	print("Camera now following: ", target.name if target else "nothing")
