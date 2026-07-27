extends Panel

@onready var item_visual: Sprite2D = $CenterContainer/Panel/item_display
@onready var amount_text: Label = $CenterContainer/Panel/Label

func update(slot: InvSlot):
	if !slot or !slot.item:
		item_visual.visible = false
		amount_text.visible = false
		amount_text.text = ""
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		
		# Apply color modulation for stars
		if slot.item.name == "Star":
			if slot.has_meta("star_color"):
				var color = slot.get_meta("star_color")
				item_visual.modulate = color
				print("[Slot] Applying star color: ", color, " for domain: ", slot.get_meta("star_domain") if slot.has_meta("star_domain") else "unknown")
			else:
				item_visual.modulate = Color(1.0, 1.0, 1.0)
				print("[Slot] Star has NO color metadata - using white")
			
			item_visual.scale = Vector2(0.1, 0.1)
		else:
			item_visual.modulate = Color(1.0, 1.0, 1.0)
			item_visual.scale = Vector2(1.0, 1.0)
		
		amount_text.visible = true
		amount_text.text = str(slot.amount)

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass
