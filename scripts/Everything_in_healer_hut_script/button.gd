extends Button

@export var item: InvItem
@export var recipe: Dictionary  # {InvItem: amount}

signal craft_requested(item: InvItem, recipe: Dictionary)

func _ready():
	
	connect("pressed", Callable(self, "_on_pressed"))

func _on_pressed():
	emit_signal("craft_requested", item, recipe)
