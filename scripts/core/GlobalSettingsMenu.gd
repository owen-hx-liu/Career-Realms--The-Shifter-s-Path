extends CanvasLayer
## Global accessibility / settings overlay — opens with ESC in any realm.
## Pixel-art remaster (matches the game's house style: determination font,
## 9-slice frames from tools/make_settings.py, NEAREST filtering) with a full
## animation suite: pop-in/out, backdrop fade, a rotating gear, bobbing icons,
## pulsing grabber glows, value punches and sparkle bursts on change.

const ART := "res://assets/generated/settings/"
const FONT_PATH := "res://art/Dialogue/determination.ttf"

@export var custom_font: FontFile
@export_range(0.0, 100.0, 1.0) var default_music_volume_percent: float = 70.0
@export_range(0.0, 100.0, 1.0) var default_brightness_percent: float = 50.0

# --- accent colours (cohesive with the generated art) ---
const COL_GOLD := Color("ffe08a")
const COL_GOLD_DK := Color("1f1606")
const COL_CYAN := Color("9ef0ff")
const COL_INK := Color("0c141b")
const COL_LABEL := Color("d6e6ef")
const COL_VALUE := Color("8fe7ff")
const COL_HINT := Color("7fa0b0")

var _menu_open: bool = false
var _brightness_percent: float = 50.0
var _time: float = 0.0

# nodes
var _brightness_overlay: ColorRect
var _settings_root: Control
var _backdrop: ColorRect
var _vignette: TextureRect
var _sparkle_layer: Control
var _panel: PanelContainer
var _music_slider: HSlider
var _brightness_slider: HSlider
var _music_value_label: Label
var _brightness_value_label: Label
var _title_label: Label
var _music_label: Label
var _brightness_label: Label
var _hint_label: Label
var _close_button: Button

# animated icon TextureRects + their resting positions
var _gear_icon: TextureRect
var _music_icon: TextureRect
var _bright_icon: TextureRect
var _music_icon_home: Vector2 = Vector2.ZERO
var _bright_icon_home: Vector2 = Vector2.ZERO

# per-slider glow halos that track the grabber
var _glows: Array = []          # [{ "slider": HSlider, "node": TextureRect, "phase": float }]

# ambient drifting sparkles
var _ambient: Array = []        # [{ "node": TextureRect, "vy": float, "phase": float, "amp": float }]

var _font: Font
var _add_mat: CanvasItemMaterial
var _anim_tween: Tween
var _punch_tweens: Dictionary = {}
var _last_burst: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 190
	_font = custom_font if custom_font != null else (load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null)

	_build_ui()
	_load_initial_values()
	_set_menu_open(false, true)


func _input(event: InputEvent) -> void:
	if not _is_escape_input(event):
		return
	_toggle_menu()
	get_viewport().set_input_as_handled()


# =============================================================== textures ===
func _tex(name: String) -> Texture2D:
	var p := ART + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null


func _add_material() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


func _frame_box(name: String, tmargin: int, cl: int = 0, ct: int = 0) -> StyleBox:
	var t := _tex(name)
	if t == null:
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0.07, 0.11, 0.15, 0.92)
		fb.set_corner_radius_all(8)
		fb.set_content_margin_all(maxi(cl, ct))
		return fb
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = tmargin
	sb.texture_margin_top = tmargin
	sb.texture_margin_right = tmargin
	sb.texture_margin_bottom = tmargin
	sb.content_margin_left = cl
	sb.content_margin_right = cl
	sb.content_margin_top = ct
	sb.content_margin_bottom = ct
	return sb


# ============================================================== build UI ====
func _build_ui() -> void:
	# brightness overlay sits behind everything and is always present
	_brightness_overlay = ColorRect.new()
	_brightness_overlay.name = "BrightnessOverlay"
	_brightness_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brightness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brightness_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_brightness_overlay)

	_settings_root = Control.new()
	_settings_root.name = "SettingsRoot"
	_settings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _font:
		var th := Theme.new()
		th.default_font = _font
		_settings_root.theme = th
	add_child(_settings_root)

	# dim backdrop
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.04, 0.07, 0.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_root.add_child(_backdrop)

	# soft vignette to focus attention (smooth -> linear filter)
	_vignette = TextureRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.texture = _tex("vignette")
	_vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_root.add_child(_vignette)

	# ambient sparkle layer (behind panel)
	_sparkle_layer = Control.new()
	_sparkle_layer.name = "Sparkles"
	_sparkle_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sparkle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_root.add_child(_sparkle_layer)
	_spawn_ambient_sparkles()

	# centered panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(660.0, 0.0)
	_panel.add_theme_stylebox_override("panel", _frame_box("panel", 16, 0, 0))
	center.add_child(_panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 30)
	margins.add_theme_constant_override("margin_top", 26)
	margins.add_theme_constant_override("margin_right", 30)
	margins.add_theme_constant_override("margin_bottom", 26)
	_panel.add_child(margins)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margins.add_child(vbox)

	_build_banner(vbox)
	_build_rows(vbox)
	_build_footer(vbox)

	# grabber glows live on top so they read as emitted light
	_add_glow(_music_slider)
	_add_glow(_brightness_slider)


func _build_banner(parent: Control) -> void:
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _frame_box("banner", 10, 20, 9))
	parent.add_child(banner)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	banner.add_child(row)

	_gear_icon = _make_icon("icon_gear", row)

	_title_label = Label.new()
	_title_label.text = "SETTINGS"
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(_title_label, 34, COL_GOLD)
	_title_label.add_theme_color_override("font_outline_color", COL_GOLD_DK)
	_title_label.add_theme_constant_override("outline_size", 6)
	row.add_child(_title_label)


func _build_rows(parent: Control) -> void:
	var music_row := _make_row(parent)
	_music_icon = _make_icon("icon_music", music_row)
	_music_label = _row_label("Music Volume")
	music_row.add_child(_music_label)
	_music_slider = _make_slider()
	_music_slider.value_changed.connect(_on_music_slider_changed)
	music_row.add_child(_music_slider)
	_music_value_label = _value_label("70%")
	music_row.add_child(_music_value_label)

	var bright_row := _make_row(parent)
	_bright_icon = _make_icon("icon_brightness", bright_row)
	_brightness_label = _row_label("Brightness")
	bright_row.add_child(_brightness_label)
	_brightness_slider = _make_slider()
	_brightness_slider.value_changed.connect(_on_brightness_slider_changed)
	bright_row.add_child(_brightness_slider)
	_brightness_value_label = _value_label("50%")
	bright_row.add_child(_brightness_value_label)


func _build_footer(parent: Control) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 4.0)
	parent.add_child(spacer)

	_close_button = Button.new()
	_close_button.text = "CLOSE"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(_close_button, Color("2f6f8c"))
	_close_button.pressed.connect(_toggle_menu)
	parent.add_child(_close_button)

	_hint_label = Label.new()
	_hint_label.text = "Press  ESC  to close"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_hint_label, 16, COL_HINT)
	parent.add_child(_hint_label)


# ---------- small builders ----------
func _make_row(parent: Control) -> HBoxContainer:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _frame_box("row", 8, 14, 12))
	parent.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	strip.add_child(row)
	return row


func _make_icon(name: String, parent: Control) -> TextureRect:
	var tex := _tex(name)
	var box := 36.0
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(box, box)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(wrap)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := tex.get_size() if tex else Vector2(28, 28)
	tr.size = sz
	tr.position = (Vector2(box, box) - sz) * 0.5
	tr.pivot_offset = sz * 0.5
	wrap.add_child(tr)
	return tr


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(168.0, 30.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(l, 21, COL_LABEL)
	return l


func _value_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(72.0, 30.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(l, 21, COL_VALUE)
	l.add_theme_color_override("font_outline_color", COL_INK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _make_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	s.custom_minimum_size = Vector2(250.0, 28.0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# vertical content margin sets how tall Godot draws the rail (and the fill that
	# matches it) — without it the track renders as an invisible ~2px sliver.
	var track := _frame_box("slider_track", 7, 0, 6)
	var fill := _frame_box("slider_fill", 7, 0, 6)
	var fill_hi := _frame_box("slider_fill", 7, 0, 6)
	if fill_hi is StyleBoxTexture:
		(fill_hi as StyleBoxTexture).modulate_color = Color(1.25, 1.25, 1.25, 1.0)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill_hi)

	var grab := _tex("grabber")
	var grab_hi := _tex("grabber_hi")
	if grab:
		s.add_theme_icon_override("grabber", grab)
		s.add_theme_icon_override("grabber_disabled", grab)
	if grab_hi:
		s.add_theme_icon_override("grabber_highlight", grab_hi)
	return s


func _add_glow(slider: HSlider) -> void:
	var tex := _tex("grabber_glow")
	if tex == null or slider == null:
		return
	var g := TextureRect.new()
	g.texture = tex
	g.size = tex.get_size()
	g.pivot_offset = tex.get_size() * 0.5
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.material = _add_material()
	g.modulate.a = 0.0
	_settings_root.add_child(g)
	_glows.append({"slider": slider, "node": g, "phase": randf() * TAU})


func _spawn_ambient_sparkles() -> void:
	var tex := _tex("sparkle")
	if tex == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var vp := Vector2(1152, 648)
	for i in range(14):
		var s := TextureRect.new()
		s.texture = tex
		s.size = tex.get_size()
		s.pivot_offset = tex.get_size() * 0.5
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.material = _add_material()
		var sc := rng.randf_range(0.4, 1.1)
		s.scale = Vector2(sc, sc)
		s.position = Vector2(rng.randf_range(0, vp.x), rng.randf_range(0, vp.y))
		_sparkle_layer.add_child(s)
		_ambient.append({
			"node": s,
			"vy": rng.randf_range(8.0, 22.0),
			"phase": rng.randf_range(0.0, TAU),
			"amp": rng.randf_range(0.18, 0.5),
		})


# ---------- styling helpers ----------
func _style_label(l: Label, size: int, col: Color) -> void:
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)


func _style_button(b: Button, col: Color) -> void:
	if _font:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_stylebox_override("normal", _button_box(col))
	b.add_theme_stylebox_override("hover", _button_box(col.lightened(0.18)))
	b.add_theme_stylebox_override("pressed", _button_box(col.darkened(0.22)))
	b.add_theme_stylebox_override("focus", _button_box(col))
	b.add_theme_color_override("font_color", Color("eaf6ff"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.add_theme_color_override("font_pressed_color", Color("cfe6f0"))


func _button_box(col: Color) -> StyleBox:
	var t := _tex("button")
	if t == null:
		var fb := StyleBoxFlat.new()
		fb.bg_color = col
		fb.set_corner_radius_all(6)
		fb.set_content_margin_all(12)
		return fb
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = 6
	sb.texture_margin_top = 6
	sb.texture_margin_right = 6
	sb.texture_margin_bottom = 6
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	sb.modulate_color = col
	return sb


# ============================================================== values ======
func _load_initial_values() -> void:
	var starting_music_percent: float = default_music_volume_percent
	var manager: Node = get_node_or_null("/root/MusicManager")
	if manager and manager.has_method("get_music_volume_db"):
		var music_db: float = float(manager.call("get_music_volume_db"))
		starting_music_percent = _db_to_percent(music_db)

	_music_slider.set_value_no_signal(starting_music_percent)
	_apply_music_volume_percent(starting_music_percent)

	_brightness_slider.set_value_no_signal(default_brightness_percent)
	_apply_brightness_percent(default_brightness_percent)


func _on_music_slider_changed(value: float) -> void:
	_apply_music_volume_percent(value)
	_react(_music_slider, _music_value_label)


func _on_brightness_slider_changed(value: float) -> void:
	_apply_brightness_percent(value)
	_react(_brightness_slider, _brightness_value_label)


func _apply_music_volume_percent(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 100.0)
	_music_value_label.text = "%d%%" % [int(round(clamped))]
	var music_db: float = _percent_to_db(clamped)
	var manager: Node = get_node_or_null("/root/MusicManager")
	if manager and manager.has_method("set_music_volume_db"):
		manager.call("set_music_volume_db", music_db)


func _apply_brightness_percent(value: float) -> void:
	_brightness_percent = clampf(value, 0.0, 100.0)
	_brightness_value_label.text = "%d%%" % [int(round(_brightness_percent))]
	var brightness_level: float = _brightness_percent_to_signed_level(_brightness_percent)
	var alpha: float = float(abs(brightness_level))
	if brightness_level < 0.0:
		_brightness_overlay.color = Color(0.0, 0.0, 0.0, alpha)
	else:
		_brightness_overlay.color = Color(1.0, 1.0, 1.0, alpha)


# =========================================================== open / close ===
func _toggle_menu() -> void:
	_set_menu_open(not _menu_open)


func _set_menu_open(open: bool, instant: bool = false) -> void:
	_menu_open = open
	_settings_root.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	if open:
		_settings_root.visible = true
		_panel.pivot_offset = _panel.size * 0.5
		if instant:
			_panel.scale = Vector2.ONE
			_panel.modulate.a = 1.0
			_backdrop.color.a = 0.62
			_vignette.modulate.a = 1.0
		else:
			_animate_open()
		_music_slider.grab_focus()
	else:
		if instant:
			_settings_root.visible = false
			_panel.modulate.a = 0.0
			_backdrop.color.a = 0.0
			_vignette.modulate.a = 0.0
		else:
			_animate_close()


func _animate_open() -> void:
	_panel.scale = Vector2(0.6, 0.6)
	_panel.modulate.a = 0.0
	_backdrop.color.a = 0.0
	_vignette.modulate.a = 0.0
	# re-center pivot once layout has settled this frame
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5

	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_panel, "scale", Vector2.ONE, 0.36) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_panel, "modulate:a", 1.0, 0.26) \
		.set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_backdrop, "color:a", 0.62, 0.28) \
		.set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_vignette, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_SINE)


func _animate_close() -> void:
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_panel, "scale", Vector2(0.62, 0.62), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(_panel, "modulate:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_backdrop, "color:a", 0.0, 0.2) \
		.set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_vignette, "modulate:a", 0.0, 0.2) \
		.set_trans(Tween.TRANS_SINE)
	for g in _glows:
		_anim_tween.tween_property(g["node"], "modulate:a", 0.0, 0.16)
	_anim_tween.chain().tween_callback(func() -> void: _settings_root.visible = false)


# ============================================================== juice ========
func _react(slider: HSlider, value_label: Label) -> void:
	if not _menu_open:
		return
	_punch(value_label)
	var now := _time
	if not _last_burst.has(slider) or now - float(_last_burst[slider]) > 0.05:
		_last_burst[slider] = now
		_burst_sparkle(_grabber_global_pos(slider))


func _punch(label: Label) -> void:
	var key := label.get_instance_id()
	if _punch_tweens.has(key):
		var prev: Tween = _punch_tweens[key]
		if prev and prev.is_valid():
			prev.kill()
	label.pivot_offset = label.size * 0.5
	var t := create_tween()
	t.tween_property(label, "scale", Vector2(1.28, 1.28), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tweens[key] = t


func _burst_sparkle(global_pos: Vector2) -> void:
	var tex := _tex("sparkle")
	if tex == null:
		return
	var s := TextureRect.new()
	s.texture = tex
	s.size = tex.get_size()
	s.pivot_offset = tex.get_size() * 0.5
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.material = _add_material()
	s.global_position = global_pos - tex.get_size() * 0.5
	s.scale = Vector2(0.3, 0.3)
	_settings_root.add_child(s)
	var t := create_tween().set_parallel(true)
	t.tween_property(s, "scale", Vector2(1.7, 1.7), 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, 0.4)
	t.tween_property(s, "rotation", 0.7, 0.4)
	t.chain().tween_callback(s.queue_free)


func _grabber_global_pos(slider: HSlider) -> Vector2:
	var span: float = maxf(0.001, slider.max_value - slider.min_value)
	var ratio: float = clampf((slider.value - slider.min_value) / span, 0.0, 1.0)
	var gw := 22.0
	var gx: float = slider.global_position.x + gw * 0.5 + ratio * (slider.size.x - gw)
	var gy: float = slider.global_position.y + slider.size.y * 0.5
	return Vector2(gx, gy)


# ============================================================ ambient =======
func _process(delta: float) -> void:
	_time += delta
	if not _menu_open or not _settings_root.visible:
		return

	# title gear spins; volume note bobs + tilts; sun spins + breathes
	if _gear_icon:
		_gear_icon.rotation += delta * 0.7
	if _music_icon:
		if _music_icon_home == Vector2.ZERO:
			_music_icon_home = _music_icon.position
		_music_icon.position = _music_icon_home + Vector2(0.0, sin(_time * 3.0) * 2.5)
		_music_icon.rotation = sin(_time * 2.0) * 0.07
	if _bright_icon:
		_bright_icon.rotation = _time * 0.5
		_bright_icon.scale = Vector2.ONE * (1.0 + 0.07 * sin(_time * 2.6))

	# grabber glow halos follow each knob and pulse
	for g in _glows:
		var slider: HSlider = g["slider"]
		var node: TextureRect = g["node"]
		if slider.size.x <= 0.0:
			continue
		node.global_position = _grabber_global_pos(slider) - node.size * 0.5
		var pulse: float = 0.6 + 0.4 * sin(_time * 4.0 + float(g["phase"]))
		node.modulate.a = 0.5 * pulse
		node.scale = Vector2.ONE * (0.85 + 0.18 * sin(_time * 4.0 + float(g["phase"])))

	# drifting ambient sparkles
	for a in _ambient:
		var s: TextureRect = a["node"]
		s.position.y -= float(a["vy"]) * delta
		if s.position.y < -16.0:
			s.position.y = 664.0
			s.position.x = randf() * 1152.0
		s.modulate.a = clampf(0.35 + float(a["amp"]) * sin(_time * 2.4 + float(a["phase"])), 0.05, 0.85)


# =============================================================== utils =======
func _percent_to_db(percent: float) -> float:
	var normalized: float = clampf(percent, 0.0, 100.0) / 100.0
	if normalized <= 0.0:
		return -80.0
	return linear_to_db(normalized)


func _db_to_percent(db: float) -> float:
	if db <= -80.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func _brightness_percent_to_signed_level(percent: float) -> float:
	var normalized: float = clampf(percent, 0.0, 100.0)
	return ((normalized - 50.0) / 50.0) * 0.75


func _is_escape_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	return false
