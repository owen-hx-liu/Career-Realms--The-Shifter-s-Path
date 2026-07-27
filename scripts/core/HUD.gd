extends CanvasLayer

# The label lives at Control/CanalCountLabel in HUD.tscn. Fall back to a
# recursive search so the counter still works if the tree is rearranged.
@onready var canal_label: Label = _find_canal_label()

func _find_canal_label() -> Label:
	var lbl := get_node_or_null("Control/CanalCountLabel") as Label
	if lbl == null:
		lbl = get_node_or_null("CanalCountLabel") as Label
	if lbl == null:
		lbl = find_child("CanalCountLabel", true, false) as Label
	return lbl

func set_canal_count(value: int) -> void:
	if canal_label:
		canal_label.text = "Canals: %d" % value
	else:
		push_warning("CanalCountLabel not found in HUD scene.")
