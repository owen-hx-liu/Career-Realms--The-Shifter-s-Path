extends CanvasLayer
#
# Remastered ward dialogue box (used by scenes/world_3.tscn's ward NPC).
#
# The whole panel is built in code in the same pixel-art language as the
# NANOBOT SURGEON minigame it leads into: a bottom-anchored 9-slice frame, a
# framed surgeon portrait, a gold name plate, the determination font, a
# typewriter text reveal, and a tidy "Press [E]" continue chip with a keycap
# sprite. Nothing is hard-positioned, so the text never floats out of place.
#
# Public API kept identical for scenes/npc.gd:
#     start_dialogue(pages: Array, speaker := "Dr. Almeida")
# and `visible` still reflects whether the box is open.

const ART := "res://assets/generated/hospital/"
const FONT_PATH := "res://art/Dialogue/determination.ttf"
const CPS := 48.0          # typewriter characters per second

var pages: Array = []
var current_page: int = 0
var _speaker: String = "Dr. Almeida"

var _font: Font
var _tex: Dictionary = {}

var _name_label: Label
var _text_label: Label
var _chip: Control
var _chip_text: Label

var _full_text: String = ""
var _revealed: float = 0.0
var _revealing: bool = false
var _blink: float = 0.0


func _ready() -> void:
	layer = 50
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	for n in ["frame_panel", "nameplate", "prompt_box", "key_e", "arrow", "cross", "portrait_doc"]:
		var p: String = ART + n + ".png"
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
	_build_ui()
	visible = false


# ---------------------------------------------------------------- build -----
func _build_ui() -> void:
	# subtle dim so the eye lands on the dialogue (kept light)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.06, 0.32)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# pin the box to the bottom edge and let it grow UPWARD: that keeps the
	# "[E] continue" chip a fixed distance above the screen bottom no matter
	# how many lines a page wraps to, so it can never slide off-screen.
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.add_theme_constant_override("margin_top", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _frame_box("frame_panel", 20, 16, 7))
	margin.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	# --- portrait, framed ---
	var pframe := PanelContainer.new()
	pframe.add_theme_stylebox_override("panel", _frame_box("frame_panel", 6, 6, 7))
	pframe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait := TextureRect.new()
	portrait.texture = _tex.get("portrait_doc")
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(116, 116)
	pframe.add_child(portrait)
	hbox.add_child(pframe)

	# --- text column ---
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	hbox.add_child(col)

	# name plate (cross + name)
	var name_wrap := HBoxContainer.new()
	col.add_child(name_wrap)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _frame_box("nameplate", 12, 6, 4))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_wrap.add_child(plate)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	plate.add_child(prow)
	prow.add_child(_icon("cross", 22))
	_name_label = _label(_speaker, 26, Color("ffe79a"))
	_name_label.add_theme_color_override("font_outline_color", Color("2a1d05"))
	_name_label.add_theme_constant_override("outline_size", 4)
	prow.add_child(_name_label)

	# dialogue text (reserve height so the box doesn't resize page to page)
	_text_label = _label("", 28, Color("eaf6f4"))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(0, 96)
	_text_label.add_theme_color_override("font_outline_color", Color("08161a"))
	_text_label.add_theme_constant_override("outline_size", 4)
	_text_label.add_theme_constant_override("line_spacing", 6)
	col.add_child(_text_label)

	# continue chip, right-aligned
	var chip_row := HBoxContainer.new()
	col.add_child(chip_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_row.add_child(spacer)

	_chip = PanelContainer.new()
	_chip.add_theme_stylebox_override("panel", _frame_box("prompt_box", 12, 7, 8))
	chip_row.add_child(_chip)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	_chip.add_child(crow)
	crow.add_child(_icon("key_e", 26))
	_chip_text = _label("continue", 20, Color("d8f4f0"))
	crow.add_child(_chip_text)
	crow.add_child(_icon("arrow", 18))


# ------------------------------------------------------------- public API ---
func start_dialogue(dialogue_pages: Array, speaker := "Dr. Almeida") -> void:
	pages = dialogue_pages
	current_page = 0
	_speaker = speaker
	if _name_label:
		_name_label.text = speaker
	show()
	_show_page(current_page)


func _show_page(index: int) -> void:
	_full_text = String(pages[index])
	_text_label.text = _full_text
	_text_label.visible_characters = 0
	_revealed = 0.0
	_revealing = true
	var last := index >= pages.size() - 1
	_chip_text.text = "close" if last else "continue"
	_chip.modulate.a = 0.0


func _process(delta: float) -> void:
	if not visible:
		return

	if _revealing:
		_revealed += delta * CPS
		_text_label.visible_characters = int(_revealed)
		if _revealed >= float(_full_text.length()):
			_text_label.visible_characters = -1
			_revealing = false
	else:
		# gently pulse the continue chip once the line is fully shown
		_blink += delta
		_chip.modulate.a = 0.65 + 0.35 * (0.5 + 0.5 * sin(_blink * 4.5))

	if Input.is_action_just_pressed("ui_interact"):
		_advance()


func _advance() -> void:
	if _revealing:
		# first press finishes the reveal instead of skipping the page
		_text_label.visible_characters = -1
		_revealing = false
		return
	current_page += 1
	if current_page >= pages.size():
		visible = false
	else:
		_show_page(current_page)


# --------------------------------------------------- themed control factories
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
	f.bg_color = Color("10242b")
	f.border_color = Color("37b8c4")
	f.set_border_width_all(2)
	f.set_corner_radius_all(4)
	return f
