extends CanvasLayer
# ============================================================================
#  Hub Tutorial — a one-time, professional "welcome" sequence that plays the
#  first time the player reaches the MainHub after the intro cutscene.
#
#  Astra, an original star-spirit guide, walks the player through the game's
#  premise, objectives, controls and first steps. Reuses the game's own
#  dialogue-box art + determination font + dark-brown text so it feels native.
#
#  Built entirely in code (matching titlescreen.gd / introcutscene.gd style),
#  fully anchored so it looks right at any window size, and modal: it pauses
#  the tree behind it while it runs.
#
#  Triggered from MainHub.gd when global.show_hub_tutorial is true.
# ============================================================================

const FONT_PATH := "res://art/Cute_Fantasy_Free2/Outdoor decoration/determination/determination.ttf"
const BOX_PATH  := "res://art/Copilot_20251115_204344 (2).png"
const ART_DIR   := "res://assets/generated/tutorial/"

# --- palette (tuned to read on the cream parchment box) ---
const C_BODY   := Color(0.20, 0.11, 0.05)
const C_HEADER := Color(0.50, 0.28, 0.04)
const C_GOLD   := Color(1.0, 0.82, 0.29)
const C_GOLD_D := Color(0.62, 0.40, 0.06)
const C_CREAM  := Color(1.0, 0.96, 0.86)
const C_NAVY   := Color(0.16, 0.13, 0.28)
const EMPH     := "#8a4f10"   # amber highlight for key words inside body bbcode

# --- box geometry (box coordinate space; assembly is centered/anchored) ---
const BW := 916.0
const BH := 286.0
const TX := 262.0   # left edge of the text column (clears the portrait)

var pages := [
	{
		"header": "Welcome, Shifter!",
		"body": "I am [color=%s]Astra[/color], your guide. Long ago, the five great Realms were torn apart by the Great Fracture. You are the last Shifter — the only one who can weave them back together." % EMPH,
	},
	{
		"header": "The Five Realms",
		"body": "Each house around this hub is a doorway into one Realm: [color=%s]Engineering, Farming, Leadership, Medicine, and Art[/color]. Step inside, take on its quest, and you'll master real skills as you play." % EMPH,
	},
	{
		"header": "Earning Stars",
		"body": "Finish a Realm's quest and you'll earn shining [color=%s]Stars[/color]. The brighter your mastery, the more the world heals around you. Every Star counts." % EMPH,
	},
	{
		"header": "Finding Your Way",
		"body": "Let's cover the basics. Use the [color=%s]Arrow Keys[/color] to walk around the hub, then simply stroll up to any door to step into that Realm." % EMPH,
		"keys": [ {"caps": ["Arrow Keys"], "label": "Move"} ],
	},
	{
		"header": "Talk & Explore",
		"body": "Press [color=%s]Enter[/color] to speak with characters and begin quests. Open your bag with I, and check your Stars and progress with R at any time." % EMPH,
		"keys": [
			{"caps": ["Enter"], "label": "Talk / Accept"},
			{"caps": ["I"],     "label": "Inventory"},
			{"caps": ["R"],     "label": "Stats"},
		],
	},
	{
		"header": "Your First Step",
		"body": "Pick any Realm that calls to you — there's no wrong choice. Walk to its house, head inside, and speak with the soul who waits there to begin your very first quest.",
	},
	{
		"header": "Restore the Realms",
		"body": "Earn Stars across all five Realms to awaken the [color=%s]portal[/color] at the heart of the hub — and decide the fate of this world. I'll be with you the whole way. Now go, Shifter... your journey begins!" % EMPH,
	},
]

# --- assets ---
var font: Font
var tex_idle: Texture2D
var tex_talk: Texture2D
var tex_blink: Texture2D
var tex_star: Texture2D
var tex_box: Texture2D

# --- nodes ---
var root: Control
var backdrop: ColorRect
var box: TextureRect
var portrait: TextureRect
var name_label: Label
var header_icon: TextureRect
var header_label: Label
var body_label: RichTextLabel
var keys_row: HBoxContainer
var dots_row: HBoxContainer
var arrow_box: Control
var skip_label: Label

# --- state ---
var page_idx := 0
var typing := false
var shown := 0.0
var full_len := 0
const CPS := 52.0          # typewriter characters/second
var talk_t := 0.0
var mouth_open := false
var blink_t := 0.0
var blinking := false
var portrait_base_y := 0.0
var closing := false
var ready_done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running while the tree is paused
	layer = 200
	_load_assets()
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	# let MainHub finish positioning the player, then freeze the world behind us
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = true
	ready_done = true
	_animate_in()
	_show_page(0)

func _load_assets() -> void:
	font     = load(FONT_PATH)
	tex_box  = load(BOX_PATH)
	tex_idle = load(ART_DIR + "astra_idle.png")
	tex_talk = load(ART_DIR + "astra_talk.png")
	tex_blink= load(ART_DIR + "astra_blink.png")
	tex_star = load(ART_DIR + "star_badge.png")

# ---------------------------------------------------------------- UI build ---
func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if font:
		var theme := Theme.new()
		theme.default_font = font
		theme.default_font_size = 20
		root.theme = theme
	add_child(root)

	# dimmed backdrop
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0)
	root.add_child(backdrop)

	# "Esc  Skip" hint, top-right of the screen
	skip_label = Label.new()
	skip_label.text = "Esc   Skip"
	skip_label.add_theme_font_size_override("font_size", 18)
	skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	skip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_label.anchor_left = 1.0
	skip_label.offset_left = -180
	skip_label.offset_top = 16
	skip_label.offset_right = -20
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.modulate.a = 0.0
	root.add_child(skip_label)

	# the dialogue box (plain stretched TextureRect — matches how NPCs use it)
	box = TextureRect.new()
	box.texture = tex_box
	box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.stretch_mode = TextureRect.STRETCH_SCALE
	box.size = Vector2(BW, BH)
	box.modulate.a = 0.0
	root.add_child(box)

	# portrait — Astra, rising above the box's left third
	portrait = TextureRect.new()
	portrait.texture = tex_idle
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(216, 288)
	portrait.position = Vector2(30, -92)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_base_y = portrait.position.y
	box.add_child(portrait)

	# name plate under the portrait
	var plate := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_NAVY
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = C_GOLD
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 4;   sb.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", sb)
	plate.position = Vector2(54, 196)
	box.add_child(plate)
	name_label = Label.new()
	name_label.text = "Astra"
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", C_CREAM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(116, 0)
	plate.add_child(name_label)

	# header icon (star) + header text
	header_icon = TextureRect.new()
	header_icon.texture = tex_star
	header_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_icon.size = Vector2(30, 30)
	header_icon.position = Vector2(TX, 36)
	box.add_child(header_icon)

	header_label = Label.new()
	header_label.add_theme_font_size_override("font_size", 30)
	header_label.add_theme_color_override("font_color", C_HEADER)
	header_label.position = Vector2(TX + 40, 34)
	header_label.size = Vector2(BW - TX - 64, 38)
	box.add_child(header_label)

	# body text (RichTextLabel for emphasis + typewriter via visible_characters)
	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("normal_font_size", 21)
	body_label.add_theme_color_override("default_color", C_BODY)
	if font:
		body_label.add_theme_font_override("normal_font", font)
		body_label.add_theme_font_override("bold_font", font)
	body_label.position = Vector2(TX, 86)
	body_label.size = Vector2(BW - TX - 50, 118)
	box.add_child(body_label)

	# keycap row (populated per page)
	keys_row = HBoxContainer.new()
	keys_row.add_theme_constant_override("separation", 22)
	keys_row.position = Vector2(TX, 196)
	box.add_child(keys_row)

	# page-progress star pips, centred near the bottom
	dots_row = HBoxContainer.new()
	dots_row.add_theme_constant_override("separation", 10)
	box.add_child(dots_row)
	for i in pages.size():
		var pip := TextureRect.new()
		pip.texture = tex_star
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pip.custom_minimum_size = Vector2(16, 16)
		dots_row.add_child(pip)

	# blinking "continue" indicator, bottom-right (clear of the bottom frame)
	arrow_box = Control.new()
	arrow_box.position = Vector2(BW - 200, BH - 74)
	box.add_child(arrow_box)
	var cont := Label.new()
	cont.text = "Enter"
	cont.add_theme_font_size_override("font_size", 20)
	cont.add_theme_color_override("font_color", C_GOLD_D)
	cont.position = Vector2(0, 0)
	arrow_box.add_child(cont)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, 14), Vector2(12, 7)])
	tri.color = C_GOLD_D
	tri.position = Vector2(70, 6)
	arrow_box.add_child(tri)
	arrow_box.modulate.a = 0.0

func _layout() -> void:
	if box == null:
		return
	var vp := get_viewport().get_visible_rect().size
	box.size = Vector2(BW, BH)
	box.position = Vector2((vp.x - BW) * 0.5, vp.y - BH - 34.0)
	# progress pips, pinned to the top-right of the box, inside the cream area
	if dots_row:
		var dw := pages.size() * 16.0 + (pages.size() - 1) * 10.0
		dots_row.position = Vector2(BW - 114.0 - dw, 46.0)

# ------------------------------------------------------------- page display ---
func _show_page(i: int) -> void:
	page_idx = i
	var p: Dictionary = pages[i]
	header_label.text = p.get("header", "")
	body_label.text = p.get("body", "")
	body_label.visible_characters = 0
	full_len = body_label.get_total_character_count()
	shown = 0.0
	typing = true
	mouth_open = false
	talk_t = 0.0

	# rebuild keycaps for this page
	for c in keys_row.get_children():
		c.queue_free()
	if p.has("keys"):
		for entry in p["keys"]:
			keys_row.add_child(_make_key_group(entry))
	keys_row.visible = p.has("keys")

	# hide the continue indicator until the line finishes
	arrow_box.modulate.a = 0.0

	# update progress pips (solid colours so they read on the cream box)
	for idx in dots_row.get_child_count():
		var pip: TextureRect = dots_row.get_child(idx)
		if idx == i:
			pip.modulate = C_GOLD
		elif idx < i:
			pip.modulate = Color(0.80, 0.54, 0.14, 1.0)
		else:
			pip.modulate = Color(0.52, 0.42, 0.30, 1.0)

func _make_key_group(entry: Dictionary) -> Control:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	for cap in entry.get("caps", []):
		group.add_child(_make_keycap(cap))
	var lbl := Label.new()
	lbl.text = entry.get("label", "")
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", C_BODY)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	group.add_child(lbl)
	return group

func _make_keycap(txt: String) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_NAVY
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(2)
	sb.border_color = C_GOLD
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 11; sb.content_margin_right = 11
	sb.content_margin_top = 5;   sb.content_margin_bottom = 5
	pc.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", C_CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc

# ----------------------------------------------------------------- animation --
func _animate_in() -> void:
	var t := backdrop.create_tween()
	t.tween_property(backdrop, "color:a", 0.72, 0.45)

	skip_label.create_tween().tween_property(skip_label, "modulate:a", 1.0, 0.6).set_delay(0.3)

	var start_y := box.position.y + 70.0
	box.position.y = start_y
	var bt := box.create_tween()
	bt.set_parallel(true)
	bt.tween_property(box, "modulate:a", 1.0, 0.45)
	bt.tween_property(box, "position:y", box.position.y - 70.0, 0.55) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# gentle idle bob on the portrait
	var pb := portrait.create_tween()
	pb.set_loops()
	pb.tween_property(portrait, "position:y", portrait_base_y - 5.0, 1.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pb.tween_property(portrait, "position:y", portrait_base_y + 3.0, 1.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _pulse_arrow() -> void:
	arrow_box.modulate.a = 1.0
	var at := arrow_box.create_tween()
	at.set_loops()
	at.tween_property(arrow_box, "modulate:a", 0.25, 0.6).set_ease(Tween.EASE_IN_OUT)
	at.tween_property(arrow_box, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_IN_OUT)

# ------------------------------------------------------------------ process ---
func _process(delta: float) -> void:
	if not ready_done or closing:
		return

	if typing:
		shown += CPS * delta
		body_label.visible_characters = int(shown)
		if int(shown) >= full_len:
			_finish_typing()
		# flap the mouth while talking
		talk_t += delta
		if talk_t >= 0.11:
			talk_t = 0.0
			mouth_open = not mouth_open
			portrait.texture = tex_talk if mouth_open else tex_idle
	else:
		# occasional idle blink when not talking
		blink_t += delta
		if not blinking and blink_t >= 3.0:
			blinking = true
			portrait.texture = tex_blink
		elif blinking and blink_t >= 3.16:
			blinking = false
			blink_t = 0.0
			portrait.texture = tex_idle

func _finish_typing() -> void:
	typing = false
	body_label.visible_characters = -1
	portrait.texture = tex_idle
	mouth_open = false
	blink_t = 0.0
	_pulse_arrow()

# -------------------------------------------------------------------- input ---
func _input(event: InputEvent) -> void:
	if not ready_done or closing:
		return
	var advance := false
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				advance = true
			KEY_ESCAPE:
				skip = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true

	if skip:
		get_viewport().set_input_as_handled()
		_close()
		return
	if advance:
		get_viewport().set_input_as_handled()
		if typing:
			_finish_typing()
		elif page_idx >= pages.size() - 1:
			_close()
		else:
			_show_page(page_idx + 1)

# -------------------------------------------------------------------- close ---
func _close() -> void:
	if closing:
		return
	closing = true
	var t := box.create_tween()
	t.set_parallel(true)
	t.tween_property(box, "modulate:a", 0.0, 0.35)
	t.tween_property(box, "position:y", box.position.y + 60.0, 0.4).set_ease(Tween.EASE_IN)
	t.tween_property(backdrop, "color:a", 0.0, 0.4)
	t.tween_property(skip_label, "modulate:a", 0.0, 0.25)
	await t.finished
	get_tree().paused = false
	queue_free()
