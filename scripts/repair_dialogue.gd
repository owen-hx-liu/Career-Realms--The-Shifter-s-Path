extends Node2D

const TYPE_SPEED_SECONDS: float = 0.018
const ENGINEER_LINES: Array[String] = [
	"You the one they sent? Good.",
	"Half this city is one aftershock away from being completely unlivable. We've got maybe a week before the damage becomes irreversible.",
	"Here's how it works. I pull up a damaged building on that screen. You choose your materials, rebuild it floor by floor. Left side mirrors the right - every floor, no exceptions. You get that wrong, the whole thing comes down.",
	"Use the X-ray when you're unsure. It'll show you exactly where the stress is.",
	"First building is already loaded. Press E when you're ready."
]

@export var npc_trigger_path: NodePath = NodePath("../repair_npc/Area2D")
@export var repair_entry_path: NodePath = NodePath("../Area2D")
@export var custom_frame_scene: PackedScene
@export var custom_frame_texture: Texture2D

@onready var dialogue_frame: Node2D = $dialogue_frame
@onready var npc_trigger: Area2D = get_node_or_null(npc_trigger_path) as Area2D
@onready var repair_entry_area: Area2D = get_node_or_null(repair_entry_path) as Area2D

var dialogue_canvas: CanvasLayer
var dialogue_root: Control
var frame_panel: PanelContainer
var message_label: RichTextLabel
var prompt_label: Label

var player_in_range: bool = false
var dialogue_active: bool = false
var is_typing: bool = false
var current_line_index: int = 0
var current_visible_chars: int = 0
var typing_accumulator: float = 0.0

# Connects the Engineer trigger, builds dialogue UI, and locks repair entry until dialogue ends.
func _ready() -> void:
	_build_dialogue_ui()
	if npc_trigger != null:
		if not npc_trigger.body_entered.is_connected(_on_npc_trigger_body_entered):
			npc_trigger.body_entered.connect(_on_npc_trigger_body_entered)
		if not npc_trigger.body_exited.is_connected(_on_npc_trigger_body_exited):
			npc_trigger.body_exited.connect(_on_npc_trigger_body_exited)
	_set_repair_entry_enabled(false)

# Advances the typewriter animation while an Engineer line is actively typing.
func _process(delta: float) -> void:
	if not dialogue_active:
		return
	if not is_typing:
		return

	typing_accumulator += delta
	var current_line: String = ENGINEER_LINES[current_line_index]
	while typing_accumulator >= TYPE_SPEED_SECONDS and current_visible_chars < current_line.length():
		typing_accumulator -= TYPE_SPEED_SECONDS
		current_visible_chars += 1
		message_label.text = current_line.substr(0, current_visible_chars)

	if current_visible_chars >= current_line.length():
		is_typing = false
		prompt_label.text = "Click or press any key to continue"

# Handles E to open dialogue and click/key to advance lines.
func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_active:
		if player_in_range and event.is_action_pressed("collect"):
			_start_dialogue()
		return

	if not _is_advance_input(event):
		return

	get_viewport().set_input_as_handled()
	if is_typing:
		_reveal_full_line()
		return

	current_line_index += 1
	if current_line_index >= ENGINEER_LINES.size():
		_finish_dialogue()
		return

	_begin_line()

# Tracks when the player enters the NPC range.
func _on_npc_trigger_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	player_in_range = true

# Tracks when the player leaves the NPC range.
func _on_npc_trigger_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	player_in_range = false

# Builds the bottom dialogue frame used for Engineer lines.
func _build_dialogue_ui() -> void:
	dialogue_canvas = CanvasLayer.new()
	dialogue_canvas.layer = 30
	add_child(dialogue_canvas)

	dialogue_root = Control.new()
	dialogue_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_canvas.add_child(dialogue_root)
	dialogue_root.visible = false

	if dialogue_frame != null:
		dialogue_frame.set_meta("placeholder_note", "replace with custom asset later")

	frame_panel = PanelContainer.new()
	frame_panel.anchor_left = 0.5
	frame_panel.anchor_right = 0.5
	frame_panel.anchor_top = 1.0
	frame_panel.anchor_bottom = 1.0
	frame_panel.offset_left = -560.0
	frame_panel.offset_right = 560.0
	frame_panel.offset_top = -208.0
	frame_panel.offset_bottom = -18.0
	dialogue_root.add_child(frame_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.07, 0.92)
	style.border_color = Color(0.41, 0.50, 0.62, 1.0)
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
	padding.add_theme_constant_override("margin_top", 20)
	padding.add_theme_constant_override("margin_bottom", 20)
	frame_panel.add_child(padding)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	padding.add_child(vbox)

	message_label = RichTextLabel.new()
	message_label.scroll_active = false
	message_label.fit_content = true
	message_label.bbcode_enabled = false
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_label.custom_minimum_size = Vector2(0, 60)
	message_label.add_theme_font_size_override("normal_font_size", 20)
	message_label.add_theme_color_override("default_color", Color.BLACK)
	vbox.add_child(message_label)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color.BLACK)
	vbox.add_child(prompt_label)

# Starts the Engineer dialogue sequence from the beginning.
func _start_dialogue() -> void:
	dialogue_active = true
	current_line_index = 0
	dialogue_root.visible = true
	_begin_line()

# Begins typing the currently selected Engineer line.
func _begin_line() -> void:
	is_typing = true
	current_visible_chars = 1
	typing_accumulator = 0.0
	var current_line: String = ENGINEER_LINES[current_line_index]
	message_label.text = current_line.substr(0, current_visible_chars)
	prompt_label.text = "Click or press any key to skip"

# Reveals the entire current Engineer line instantly.
func _reveal_full_line() -> void:
	is_typing = false
	var current_line: String = ENGINEER_LINES[current_line_index]
	current_visible_chars = current_line.length()
	message_label.text = current_line
	prompt_label.text = "Click or press any key to continue"

# Ends Engineer dialogue and unlocks the repair console prompt.
func _finish_dialogue() -> void:
	dialogue_active = false
	dialogue_root.visible = false
	_set_repair_entry_enabled(true)

# Enables or disables the repair entry trigger through its scene script API.
func _set_repair_entry_enabled(enabled: bool) -> void:
	if repair_entry_area == null:
		return
	repair_entry_area.call("set_interaction_enabled", enabled)

# Returns true when this event should advance the dialogue line.
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

# Returns true only for the player body.
func _is_player_body(body: Node) -> bool:
	if body == null:
		return false
	return body.is_in_group("player") or String(body.name).to_lower() == "player"

# Adds an optional custom frame asset so the dialogue look can be swapped in the Inspector.
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
