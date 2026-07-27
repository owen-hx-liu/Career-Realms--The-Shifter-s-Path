extends Area2D

# Ward-entrance NPC for the hospital (scenes/world_3.tscn).
# Walk into the Area2D -> a floating "Press [E]" prompt pill appears above the
# attending. Press E once for a short paged briefing (the remastered
# DialogueBox child), then press E again to launch the NANOBOT SURGEON quest
# (scenes/nanobot_quest.tscn).
#
# The presentation here is built in code in the same pixel-art language as the
# minigame: a screen-space prompt pill (keycap sprite + determination font), a
# fading "CRITICAL CARE WARD" title card on entry, and a soft vignette — so the
# lead-in feels as finished as the minigame.
#
# The DialogueBox child consumes the E key while it is open, so a short
# cooldown is started the moment it closes — that stops the same key press
# that closed the last page from immediately launching the quest.

const QUEST_SCENE := "res://scenes/nanobot_quest.tscn"
const ART := "res://assets/generated/hospital/"
const FONT_PATH := "res://art/Dialogue/determination.ttf"
const SPEAKER := "Dr. Almeida"

@onready var dialogue_box: CanvasLayer = $DialogueBox

var player_nearby: bool = false
var briefed: bool = false
var was_visible: bool = false
var cooldown: float = 0.0
var _t: float = 0.0

var _font: Font
var _tex: Dictionary = {}

var _prompt_layer: CanvasLayer
var _prompt_panel: PanelContainer
var _prompt_text: Label

var dialogue_pages: Array = [
	"Welcome to the ward, Doctor. Three patients are in critical condition and the surgical team is out of options.",
	"Each one needs a medical nanobot piloted through the bloodstream to seal the damaged tissue by hand. Press E when you're ready to scrub in.",
]


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	for n in ["prompt_box", "key_e", "cross", "banner_frame"]:
		var p: String = ART + n + ".png"
		_tex[n] = load(p) if ResourceLoader.exists(p) else null

	_build_prompt()
	_build_vignette()
	_show_title_card()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		_prompt_layer.visible = false


func _process(delta: float) -> void:
	_t += delta
	if cooldown > 0.0:
		cooldown -= delta

	# the briefing just closed -> guard against the closing key press
	var vis: bool = dialogue_box.visible
	if was_visible and not vis:
		cooldown = 0.35
	was_visible = vis

	if vis or not player_nearby:
		_prompt_layer.visible = false
		return

	_prompt_text.text = "Begin Operation" if briefed else "Talk"
	_prompt_layer.visible = true
	_update_prompt_position()

	if cooldown <= 0.0 and Input.is_action_just_pressed("ui_interact"):
		if not briefed:
			briefed = true
			_prompt_layer.visible = false
			# defer one frame so DialogueBox doesn't eat this same press
			dialogue_box.call_deferred("start_dialogue", dialogue_pages, SPEAKER)
		else:
			_launch_quest()


# ----------------------------------------------------- floating prompt pill --
func _build_prompt() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = 30
	_prompt_layer.visible = false
	add_child(_prompt_layer)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", _frame_box("prompt_box", 10, 5, 8))
	_prompt_layer.add_child(_prompt_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_prompt_panel.add_child(row)
	row.add_child(_icon("key_e", 22))
	_prompt_text = _label("Talk", 18, Color("dff6f2"))
	_prompt_text.add_theme_color_override("font_outline_color", Color("08161a"))
	_prompt_text.add_theme_constant_override("outline_size", 4)
	row.add_child(_prompt_text)


func _update_prompt_position() -> void:
	var xform := get_viewport().get_canvas_transform()
	# a point just above the attending's head, in world space
	var screen: Vector2 = xform * (global_position + Vector2(8.0, -40.0))
	var sz: Vector2 = _prompt_panel.size
	var bob: float = sin(_t * 3.2) * 4.0
	_prompt_panel.position = Vector2(round(screen.x - sz.x * 0.5),
									 round(screen.y - sz.y + bob))


# ----------------------------------------------------------- ward ambiance --
func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.42, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.0, 0.02, 0.03, 0.5)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 320
	gt.height = 320
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)


func _show_title_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)

	# the fade target must be a CanvasItem -- CanvasLayer has no `modulate`
	var fade := Control.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", 60)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _frame_box("banner_frame", 26, 14, 9))
	center.add_child(banner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	banner.add_child(row)
	row.add_child(_icon("cross", 34))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var sub := _label("MERIDIAN GENERAL", 16, Color("e7c356"))
	sub.add_theme_constant_override("outline_size", 3)
	sub.add_theme_color_override("font_outline_color", Color("2a1d05"))
	col.add_child(sub)
	var title := _label("CRITICAL CARE WARD", 34, Color("eef6f5"))
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color("08161a"))
	col.add_child(title)

	fade.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.4)
	tw.tween_property(fade, "modulate:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)


# --------------------------------------------------------------- launch -----
func _launch_quest() -> void:
	var sm = get_node_or_null("/root/SceneManager")
	if sm and sm.has_method("change_scene"):
		sm.change_scene(QUEST_SCENE)
	else:
		get_tree().change_scene_to_file(QUEST_SCENE)


# ----------------------------------------------- themed control factories ---
func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _icon(tex_name: String, sz: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex.get(tex_name)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = Vector2(sz, sz)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


func _frame_box(frame_name: String, content := 12, tmargin := 7, slice := 7) -> StyleBox:
	var tex: Texture2D = _tex.get(frame_name)
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = slice
		sb.texture_margin_top = slice
		sb.texture_margin_right = slice
		sb.texture_margin_bottom = slice
		sb.content_margin_left = content
		sb.content_margin_right = content
		sb.content_margin_top = tmargin
		sb.content_margin_bottom = tmargin
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = Color("0c1c22")
	f.border_color = Color("37b8c4")
	f.set_border_width_all(2)
	f.set_corner_radius_all(6)
	return f
