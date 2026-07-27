extends Node2D

const TYPE_SPEED_SECONDS: float = 0.018
const NARRATOR_LINES: Array[String] = [
	"Three days ago, a 7.8 magnitude earthquake tore through the city of Varen. In under four minutes, decades of construction collapsed into dust.",
	"Power is failing. Water systems are down. Thousands are still trapped.",
	"The government has one option left. They need engineers. They need you.",
	"You don't know this city. But you know what it needs. Get to the control center. The work starts now."
]

@export var custom_frame_scene: PackedScene
@export var custom_frame_texture: Texture2D

@onready var narrator_frame: Node2D = $narrator_frame
@onready var player_node: CharacterBody2D = get_node_or_null("player") as CharacterBody2D

var dialogue_canvas: CanvasLayer
var dialogue_root: Control
var frame_panel: PanelContainer
var message_label: RichTextLabel
var prompt_label: Label

var dialogue_active: bool = false
var is_typing: bool = false
var current_line_index: int = 0
var current_visible_chars: int = 0
var typing_accumulator: float = 0.0

# Starts the opening narrator sequence and temporarily locks player movement.
func _ready() -> void:
	_build_dialogue_ui()
	_set_player_control(false)
	_start_dialogue()

# Advances the typewriter animation while a line is actively typing.
func _process(delta: float) -> void:
	if not dialogue_active:
		return
	if not is_typing:
		return

	typing_accumulator += delta
	var current_line: String = NARRATOR_LINES[current_line_index]
	while typing_accumulator >= TYPE_SPEED_SECONDS and current_visible_chars < current_line.length():
		typing_accumulator -= TYPE_SPEED_SECONDS
		current_visible_chars += 1
		message_label.text = current_line.substr(0, current_visible_chars)

	if current_visible_chars >= current_line.length():
		is_typing = false
		prompt_label.text = "Click or press any key to continue"

# Handles click/key input to skip typing or advance to the next line.
func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_active:
		return
	if not _is_advance_input(event):
		return

	get_viewport().set_input_as_handled()
	if is_typing:
		_reveal_full_line()
		return

	current_line_index += 1
	if current_line_index >= NARRATOR_LINES.size():
		_finish_dialogue()
		return

	_begin_line()

# Builds the bottom-centered placeholder dialogue frame UI.
func _build_dialogue_ui() -> void:
	dialogue_canvas = CanvasLayer.new()
	dialogue_canvas.layer = 30
	add_child(dialogue_canvas)

	dialogue_root = Control.new()
	dialogue_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_canvas.add_child(dialogue_root)

	if narrator_frame != null:
		narrator_frame.set_meta("placeholder_note", "replace with custom asset later")

	frame_panel = PanelContainer.new()
	frame_panel.anchor_left = 0.5
	frame_panel.anchor_right = 0.5
	frame_panel.anchor_top = 1.0
	frame_panel.anchor_bottom = 1.0
	frame_panel.offset_left = -560.0
	frame_panel.offset_right = 560.0
	frame_panel.offset_top = -208.0
	frame_panel.offset_bottom = -18.0
	frame_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_root.add_child(frame_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.92)
	style.border_color = Color(0.36, 0.45, 0.56, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	frame_panel.add_theme_stylebox_override("panel", style)
	_attach_custom_frame_asset(frame_panel)

	var padding: MarginContainer = MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 58)
	padding.add_theme_constant_override("margin_right", 58)
	padding.add_theme_constant_override("margin_top", 14)
	padding.add_theme_constant_override("margin_bottom", 14)
	frame_panel.add_child(padding)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	padding.add_child(vbox)

	message_label = RichTextLabel.new()
	message_label.scroll_active = false
	message_label.fit_content = true
	message_label.bbcode_enabled = false
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(0, 106)
	message_label.add_theme_font_size_override("normal_font_size", 24)
	message_label.add_theme_color_override("default_color", Color.BLACK)
	vbox.add_child(message_label)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color.BLACK)
	vbox.add_child(prompt_label)

# Starts dialogue flow from the first line.
func _start_dialogue() -> void:
	dialogue_active = true
	current_line_index = 0
	dialogue_root.visible = true
	_begin_line()

# Begins typing the current line from the start.
func _begin_line() -> void:
	is_typing = true
	current_visible_chars = 1
	typing_accumulator = 0.0
	var current_line: String = NARRATOR_LINES[current_line_index]
	message_label.text = current_line.substr(0, current_visible_chars)
	prompt_label.text = "Click or press any key to skip"

# Fully reveals the current line immediately.
func _reveal_full_line() -> void:
	is_typing = false
	var current_line: String = NARRATOR_LINES[current_line_index]
	current_visible_chars = current_line.length()
	message_label.text = current_line
	prompt_label.text = "Click or press any key to continue"

# Ends dialogue and restores player movement control.
func _finish_dialogue() -> void:
	dialogue_active = false
	dialogue_root.visible = false
	_set_player_control(true)

# Returns true if this input should advance the narrator dialogue.
func _is_advance_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.echo:
			return false
		return key_event.pressed

	if event.is_action_pressed("collect"):
		return true
	if event.is_action_pressed("ui_accept"):
		return true
	if event.is_action_pressed("place_filter"):
		return true
	return false

# Enables or disables player movement updates while dialogue is active.
func _set_player_control(enabled: bool) -> void:
	if player_node == null:
		return
	player_node.set_physics_process(enabled)
	player_node.set_process_input(enabled)
	player_node.set_process_unhandled_input(enabled)

# Adds an optional custom frame asset so dialogue visuals can be swapped from the Inspector.
func _attach_custom_frame_asset(target_panel: PanelContainer) -> void:
	if target_panel == null:
		return

	if custom_frame_scene != null:
		var instance: Node = custom_frame_scene.instantiate()
		if instance is Control:
			var control_frame: Control = instance as Control
			control_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
			control_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target_panel.add_child(instance)
		target_panel.move_child(instance, 0)
		return

	if custom_frame_texture != null:
		var texture_frame: TextureRect = TextureRect.new()
		texture_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_frame.stretch_mode = TextureRect.STRETCH_SCALE
		texture_frame.texture = custom_frame_texture
		target_panel.add_child(texture_frame)
		target_panel.move_child(texture_frame, 0)
