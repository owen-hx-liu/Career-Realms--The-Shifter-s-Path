extends CanvasLayer

@onready var control_node: Control = $Control
@onready var message_label: RichTextLabel = $Control/MessageLabel
@onready var prompt_label: RichTextLabel = $Control/PromptLabel

var steps: Array[String] = [
	"Welcome, traveler.",
	"Our trade villages have become isolated, and the old roads have long since fallen apart. It is now your task to restore the trade network and reconnect the lands.",
	"Beyond this plaza lie three villages in need of supplies. Food, resources, and trade can only flow if safe and efficient roads are built between them and the central hub.",
	"You will enter the planning chamber and study the region map carefully. The land is unpredictable, and every route carries its own risks.",
	"Forests and mountains will slow your caravans, costing valuable time. Lakes cannot be crossed and must be routed around. More dangerous still are the cursed skeleton zones. Any caravan that enters one will be lost immediately.",
	"Your road tiles are limited, so every placement matters. A short route may be dangerous, while a safer path may consume too many resources. You must decide how to balance speed, safety, and efficiency.",
	"Once your routes are complete, the caravans will begin their journey automatically. If all deliveries arrive safely and quickly, your network will prosper.",
	"Plan wisely, strategist.",
	"The success of these villages now rests in your hands."
]

var current_step := 0
var bar_height := 200.0

func _ready() -> void:
	control_node.set_anchors_preset(Control.PRESET_FULL_RECT)

	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var screen_width := get_viewport().get_visible_rect().size.x
	message_label.position = Vector2.ZERO
	message_label.custom_minimum_size = Vector2(screen_width, bar_height)
	message_label.add_theme_font_size_override("font_size", 24)

	prompt_label.text = "Press [E] or [Space] to Continue"
	prompt_label.custom_minimum_size = Vector2(360, 40)
	prompt_label.scroll_active = false
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	prompt_label.position = Vector2(screen_width - 380, bar_height - 40)
	prompt_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)

	control_node.draw.connect(_on_control_draw)

	if global.has_trading_narrator_been_shown():
		visible = false
	else:
		show_narrator()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("collect") or event.is_action_pressed("ui_accept") or event.is_action_pressed("place_filter"):
		get_viewport().set_input_as_handled()
		current_step += 1
		if current_step < steps.size():
			update_text()
		else:
			close_narrator()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reopen_narrator"):
		show_narrator()

func _on_control_draw() -> void:
	var screen_width := get_viewport().get_visible_rect().size.x
	var rect := Rect2(0, 0, screen_width, bar_height)
	control_node.draw_rect(rect, Color(0, 0, 0, 0.8), true)
	control_node.draw_line(Vector2(0, bar_height), Vector2(screen_width, bar_height), Color.WHITE, 2.0)

func show_narrator() -> void:
	current_step = 0
	visible = true
	update_text()
	control_node.queue_redraw()

func update_text() -> void:
	message_label.text = steps[current_step]

func close_narrator() -> void:
	visible = false
	global.mark_trading_narrator_shown()
