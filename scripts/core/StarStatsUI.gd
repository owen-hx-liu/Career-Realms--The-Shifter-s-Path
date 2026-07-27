# StarStatsUI.gd  (remastered — "STAR CODEX")
# Press R to toggle a polished, pixel-art cosmic codex of the player's stars.
# Self-contained: loads its own determination font + generated 9-slice art so it
# looks identical in every house (only MainHub used to wire the font).
extends CanvasLayer

@export var background_texture: Texture2D   # legacy export, no longer required
@export var ui_font: Font                   # optional override

@export var title_font_size := 24
@export var header_font_size := 17
@export var body_font_size := 15

const ART  := "res://assets/generated/star_ui/"
const FONT_PATH := "res://art/Cute_Fantasy_Free2/Outdoor decoration/determination/determination.ttf"

# --- palette -------------------------------------------------------------
const COL_GOLD     := Color(1.0, 0.82, 0.33)
const COL_GOLD_DIM := Color(0.78, 0.64, 0.34)
const COL_TEXT     := Color(0.93, 0.95, 1.0)
const COL_DIM      := Color(0.68, 0.73, 0.9)
const COL_OUTLINE  := Color(0.04, 0.05, 0.13)
const CONTENT_W    := 416
const BAR_W        := 348

var _font: Font
var _t_panel: Texture2D
var _t_plate: Texture2D
var _t_ribbon: Texture2D
var _t_star: Texture2D
var _t_star_empty: Texture2D

var root: Control
var dim: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var menu_open := false
var _busy := false


func _ready():
	_load_assets()
	_build_shell()
	root.visible = false


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		toggle_stats()


# ---------------------------------------------------------------- assets
func _load_assets():
	_font = ui_font
	if _font == null and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_t_panel       = _tex("panel.png")
	_t_plate       = _tex("plate.png")
	_t_ribbon      = _tex("ribbon.png")
	_t_star        = _tex("star_full.png")
	_t_star_empty  = _tex("star_empty.png")

func _tex(name: String) -> Texture2D:
	var p := ART + name
	return load(p) if ResourceLoader.exists(p) else null


# ---------------------------------------------------------------- shell
func _build_shell():
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		var th := Theme.new()
		th.default_font = _font
		root.theme = th
	add_child(root)

	# soft dim so the codex pops; never eats gameplay input
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.09, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sb(_t_panel, 34, 40, 34, 40, 30))
	center.add_child(panel)

	var margin := MarginContainer.new()
	panel.add_child(margin)

	content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)


# StyleBoxTexture from a 9-slice art file (with content insets).
func _sb(tex: Texture2D, m: int, cl: int, ct: int, cr: int, cb: int) -> StyleBox:
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = m
		sb.texture_margin_top = m
		sb.texture_margin_right = m
		sb.texture_margin_bottom = m
		sb.content_margin_left = cl
		sb.content_margin_top = ct
		sb.content_margin_right = cr
		sb.content_margin_bottom = cb
		return sb
	# fallback so the menu still works if art is missing
	var f := StyleBoxFlat.new()
	f.bg_color = Color(0.07, 0.1, 0.22, 0.96)
	f.border_color = COL_GOLD_DIM
	f.set_border_width_all(2)
	f.content_margin_left = cl
	f.content_margin_top = ct
	f.content_margin_right = cr
	f.content_margin_bottom = cb
	f.set_corner_radius_all(2)
	return f


# ---------------------------------------------------------------- toggle
func toggle_stats():
	if _busy:
		return
	if menu_open:
		_close()
	else:
		_open()

func _open():
	menu_open = true
	refresh_stats()
	root.visible = true
	_busy = true
	await get_tree().process_frame      # let containers compute their size
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	await tw.finished
	_busy = false

func _close():
	menu_open = false
	_busy = true
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "modulate:a", 0.0, 0.14)
	await tw.finished
	root.visible = false
	_busy = false


# ---------------------------------------------------------------- content
func refresh_stats():
	for child in content.get_children():
		child.queue_free()

	var total := StarManager.get_total_stars()
	var max_stars := StarManager.get_max_possible_stars()
	var done := StarManager.get_completed_quest_count()
	var total_q := StarManager.get_total_quest_count()
	var pct := 0.0
	if max_stars > 0:
		pct = float(total) / float(max_stars) * 100.0

	_add_title("STAR CODEX")
	_add_hero(total, max_stars, pct)
	_add_quests_line(done, total_q)
	_add_divider()
	_add_domains_header()
	_add_domains()
	_add_footer()


func _add_title(text: String):
	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", _sb(_t_ribbon, 14, 16, 7, 16, 7))
	ribbon.size_flags_horizontal = Control.SIZE_FILL
	var lbl := _label(text, title_font_size, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ribbon.add_child(lbl)
	content.add_child(ribbon)


func _add_hero(total: int, max_stars: int, pct: float):
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _sb(_t_plate, 16, 18, 14, 18, 14))
	content.add_child(plate)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	plate.add_child(vb)

	vb.add_child(_label("TOTAL STARS COLLECTED", 12, COL_GOLD_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var big := _label("%d  /  %d" % [total, max_stars], 30, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	big.add_theme_constant_override("outline_size", 6)
	big.add_theme_color_override("font_outline_color", COL_OUTLINE)
	vb.add_child(big)

	# five-star overview gauge (gold)
	var filled := 0
	if max_stars > 0:
		filled = int(round(float(total) / float(max_stars) * 5.0))
	vb.add_child(_star_gauge(filled, 5, COL_GOLD, 24, 3))

	# progress bar
	var ratio := 0.0
	if max_stars > 0:
		ratio = clamp(float(total) / float(max_stars), 0.0, 1.0)
	var bar_wrap := CenterContainer.new()
	bar_wrap.add_child(_progress_bar(ratio, BAR_W, 16, COL_GOLD))
	vb.add_child(bar_wrap)

	vb.add_child(_label("%.0f%% COMPLETE" % pct, 12, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _add_quests_line(done: int, total_q: int):
	content.add_child(_label("Quests Completed:   %d / %d" % [done, total_q],
		body_font_size, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER))


func _add_divider():
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", 2)
	wrap.add_theme_constant_override("margin_bottom", 2)
	var line := ColorRect.new()
	line.color = COL_GOLD_DIM
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(line)
	content.add_child(wrap)


func _add_domains_header():
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(_star_icon(18, COL_GOLD, true))
	var lbl := _label("DOMAINS", header_font_size, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lbl)
	content.add_child(hb)


func _add_domains():
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _sb(_t_plate, 16, 14, 12, 14, 12))
	content.add_child(plate)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	plate.add_child(vb)

	var domain_order := ["Medicine", "Engineering", "Farming", "Art", "Leadership"]
	for d in StarManager.get_all_domains():
		if d not in domain_order:
			domain_order.append(d)

	for i in range(domain_order.size()):
		var d: String = domain_order[i]
		vb.add_child(_domain_row(d))
		if i < domain_order.size() - 1:
			var sep := ColorRect.new()
			sep.color = Color(0.4, 0.45, 0.62, 0.28)
			sep.custom_minimum_size = Vector2(0, 1)
			vb.add_child(sep)


func _domain_row(domain: String) -> Control:
	var stars := StarManager.get_domain_stars(domain)
	var maxs := StarManager.get_domain_max_stars(domain)
	var quests := StarManager.get_domain_quest_count(domain)
	var tint := _bright(StarManager.get_domain_color(domain))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 28)

	row.add_child(_star_icon(22, tint, true))

	var name_lbl := _label(domain, body_font_size, tint, HORIZONTAL_ALIGNMENT_LEFT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_lbl)

	var filled := 0
	if maxs > 0:
		filled = int(round(float(stars) / float(maxs) * 5.0))
	var gauge := _star_gauge(filled, 5, tint, 14, 2)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gauge)

	var count := _label("%d / %d" % [stars, maxs], 13, COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	count.custom_minimum_size = Vector2(52, 0)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)

	return row


func _add_footer():
	var f := _label("Press  R  to close", 12, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	f.modulate.a = 0.9
	content.add_child(f)


# ---------------------------------------------------------------- widgets
func _label(text: String, size: int, color: Color, halign: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = halign
	l.add_theme_color_override("font_color", color)
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", COL_OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	return l

func _star_icon(px: int, tint: Color, full: bool) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _t_star if full else _t_star_empty
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _star_gauge(filled: int, total: int, tint: Color, px: int, sep: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", sep)
	for i in range(total):
		if i < filled:
			hb.add_child(_star_icon(px, tint, true))
		else:
			var e := _star_icon(px, Color(1, 1, 1, 0.85), false)
			hb.add_child(e)
	return hb

func _progress_bar(ratio: float, w: int, h: int, fill_col: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h)

	var track := Panel.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.05, 0.07, 0.16, 1.0)
	ts.border_color = COL_GOLD_DIM
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(2)
	track.add_theme_stylebox_override("panel", ts)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(track)

	if ratio > 0.0:
		var fill := Panel.new()
		var fs := StyleBoxFlat.new()
		fs.bg_color = fill_col
		fs.border_color = Color(1, 1, 1, 0.6)
		fs.border_width_top = 1
		fs.set_corner_radius_all(1)
		fill.add_theme_stylebox_override("panel", fs)
		fill.position = Vector2(2, 2)
		fill.size = Vector2(max(2.0, (w - 4) * ratio), h - 4)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fill)

	return holder

func _bright(c: Color) -> Color:
	return c.lerp(Color.WHITE, 0.28)
