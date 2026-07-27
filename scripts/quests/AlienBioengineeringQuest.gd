extends Node2D
# =============================================================================
#  XENO LAB — Alien Gene Splicing   (Medicine domain, quest 2)
# -----------------------------------------------------------------------------
#  A 5-stage bio-engineering adventure. EVERY stage is a different mini-game,
#  tied together by a story: an alien spore infects the greenhouse — study it,
#  engineer a cure, and contain the bloom.
#
#   1. CONTAINMENT CATCH  (arcade reflex) — net good spores, dodge toxic ones.
#   2. GENE SEQUENCER     (action/typing) — zap incoming bases with their pair.
#   3. SPLICE MEMORY      (Simon-says)    — watch a gene sequence, repeat it.
#   4. BIOREACTOR         (balance)       — keep the culture gauge in the green.
#   5. FINAL CONTAINMENT  (boss)          — pair-fire the antidote cannon.
#
#  Story beats between stages. Twists throughout (mutations, decoys, reversals,
#  boss phases). Shared "integrity" meter; stars from overall performance.
#  Visuals load pixel-art textures from ART_DIR if present, else clean fallbacks.
# =============================================================================

@export var quest_id: String = "medicine_quest_2"
@export var domain: String = "Medicine"
@export var return_scene: String = "res://scenes/maps/MedicineHouse.tscn"
@export var auto_return_delay: float = 7.0

# ---- Bases ------------------------------------------------------------------
enum Base { A, T, C, G, U }
const BASE_LETTER := {Base.A:"A", Base.T:"T", Base.C:"C", Base.G:"G", Base.U:"U"}
const BASE_NAME := {Base.A:"Adenine", Base.T:"Thymine", Base.C:"Cytosine", Base.G:"Guanine", Base.U:"Uracil"}
const BASE_COLOR := {
	Base.A: Color("5fd36a"), Base.T: Color("ff6f61"), Base.C: Color("49a7ff"),
	Base.G: Color("ffc23d"), Base.U: Color("b27bff"),
}

# ---- Phases -----------------------------------------------------------------
enum Phase { INTRO, CATCH, SEQUENCER, MEMORY, BIOREACTOR, BOSS, VICTORY, DEFEAT }
var phase: int = Phase.INTRO

# ---- Shared state -----------------------------------------------------------
const INTEGRITY_MAX := 100.0
var integrity := INTEGRITY_MAX
var score := 0
var retries := 0
var finished := false
var _flashing := false
var record_on_win := true   # harness sets false so screenshots don't touch the save

# per-frame / input dispatch (set by the active stage)
var tick: Callable = Callable()
var input_handler: Callable = Callable()

# ---- UI refs ----------------------------------------------------------------
var ui_layer: CanvasLayer
var bg_rect: TextureRect
var stage_layer: Control          # each mini-game builds into this; cleared on switch
var hud: Control
var phase_label: Label
var score_label: Label
var integ_bar: ProgressBar
var integ_label: Label
var objective_label: Label
var overlay: Panel                 # story / result cards
var ui_root: Control               # themed root so all UI inherits the pixel font

# ---- Art --------------------------------------------------------------------
const ART_DIR := "res://assets/generated/splice_lab/"
const FONT_PATH := "res://art/Cute_Fantasy_Free2/Outdoor decoration/determination/determination.ttf"
var tex := {}                      # name -> Texture2D or null
var ui_font: Font = null

# =============================================================================
#  Lifecycle
# =============================================================================
func _ready() -> void:
	randomize()
	_load_art()
	_build_shell()
	_show_intro()

func _load_art() -> void:
	for n in ["lab_background","alien_cell","cured_cell","boss","collector",
			"spore_good","spore_toxic","reactor","helix",
			"base_a","base_t","base_c","base_g","base_u",
			"panel_frame","card_frame","button_frame","star_full","star_empty"]:
		var p: String = ART_DIR + str(n) + ".png"
		tex[n] = load(p) if ResourceLoader.exists(p) else null
	if ResourceLoader.exists(FONT_PATH):
		ui_font = load(FONT_PATH)

func _process(delta: float) -> void:
	if tick.is_valid():
		tick.call(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_return_to_domain(); return
	if input_handler.is_valid():
		input_handler.call(event)

# =============================================================================
#  Shell UI (persistent HUD + background)
# =============================================================================
func _build_shell() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var solid := ColorRect.new()
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.color = Color("0a1118")
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(solid)

	bg_rect = TextureRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.texture = tex.get("lab_background")
	ui_layer.add_child(bg_rect)

	# Themed root — gives every label/button the determination pixel font
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	if ui_font:
		var th := Theme.new()
		th.default_font = ui_font
		ui_root.theme = th
	ui_layer.add_child(ui_root)

	# HUD (top bar)
	hud = _panel(Color("12202b", 0.95), Color("2f5d72"))
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 14; hud.offset_top = 12
	hud.offset_right = -14; hud.offset_bottom = 70
	ui_root.add_child(hud)
	var hrow := HBoxContainer.new()
	hrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	hrow.offset_left = 14; hrow.offset_right = -14
	hrow.add_theme_constant_override("separation", 16)
	hrow.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(hrow)
	phase_label = _label("XENO LAB", 20, Color("8defc0"))
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(phase_label)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(sp)
	hrow.add_child(_label("INTEGRITY", 13, Color("bcd6e6")))
	integ_bar = ProgressBar.new()
	integ_bar.max_value = INTEGRITY_MAX; integ_bar.value = integrity
	integ_bar.show_percentage = false
	integ_bar.custom_minimum_size = Vector2(200, 18)
	integ_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # line up with the HUD text
	_style_progress(integ_bar, Color("3ad17a"))
	hrow.add_child(integ_bar)
	integ_label = _label("100%", 13, Color("d8f5e6"))
	hrow.add_child(integ_label)
	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(20,0)
	hrow.add_child(sp2)
	score_label = _label("Score 0", 16, Color("ffe08a"))
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(score_label)

	# Objective strip (below HUD)
	var ob := _panel(Color("0e1a24", 0.9), Color("28506a"))
	ob.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ob.offset_left = 14; ob.offset_top = 76
	ob.offset_right = -14; ob.offset_bottom = 108
	ui_root.add_child(ob)
	objective_label = _label("", 14, Color("cfe9f7"))
	objective_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ob.add_child(objective_label)

	# Stage layer (the playfield) — between objective strip and bottom
	stage_layer = Control.new()
	stage_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_layer.offset_top = 118
	stage_layer.offset_left = 14
	stage_layer.offset_right = -14
	stage_layer.offset_bottom = -14
	stage_layer.clip_contents = true
	ui_root.add_child(stage_layer)

	# Overlay (story / results) — created hidden
	overlay = Panel.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var osb := StyleBoxFlat.new(); osb.bg_color = Color(0.02,0.05,0.07,0.86)
	overlay.add_theme_stylebox_override("panel", osb)
	overlay.visible = false
	ui_root.add_child(overlay)

func _set_hud(title: String, objective: String) -> void:
	phase_label.text = title
	objective_label.text = objective

func _update_hud() -> void:
	score_label.text = "Score %d" % score
	integ_bar.value = integrity
	integ_label.text = "%d%%" % int(round(integrity))
	var c := Color("3ad17a")
	if integrity < 50: c = Color("e8c64a")
	if integrity < 25: c = Color("e8654a")
	_style_progress(integ_bar, c)

func _hurt(amount: float) -> void:
	integrity = maxf(0.0, integrity - amount)
	_update_hud()
	_flash_damage()
	if integrity <= 0.0 and not finished:
		_defeat()

func _heal(amount: float) -> void:
	integrity = minf(INTEGRITY_MAX, integrity + amount)
	_update_hud()

func _add_score(n: int) -> void:
	score += n
	_update_hud()

func _clear_stage() -> void:
	tick = Callable()
	input_handler = Callable()
	for c in stage_layer.get_children():
		c.queue_free()

# =============================================================================
#  Story beats / phase routing
# =============================================================================
func _show_intro() -> void:
	_set_hud("XENO LAB", "A meteor fell on the greenhouse...")
	_story("Xeno Lab — Alien Gene Splicing", [
		"A meteor crashed into the greenhouse and cracked open.",
		"Inside: a spore that mutates everything it touches.",
		"Paya needs you to study it, engineer a cure, and contain the bloom",
		"— before it spreads beyond the lab.",
	], "Enter the Lab  ▶", func(): _goto(Phase.CATCH))

func _goto(p: int) -> void:
	phase = p
	overlay.visible = false
	for c in overlay.get_children(): c.queue_free()
	_clear_stage()
	_heal(18.0)  # small breather between stages
	match p:
		Phase.CATCH: _start_catch()
		Phase.SEQUENCER: _start_sequencer()
		Phase.MEMORY: _start_memory()
		Phase.BIOREACTOR: _start_bioreactor()
		Phase.BOSS: _start_boss()
		Phase.VICTORY: _victory()

func _beat(title: String, lines: Array, next_label: String, next_phase: int) -> void:
	tick = Callable(); input_handler = Callable()
	_story(title, lines, next_label, func(): _goto(next_phase))

# =============================================================================
#  STAGE 1 — CONTAINMENT CATCH  (arcade reflex)
# =============================================================================
var c_collector: Control
var c_spores: Array = []
var c_samples := 0
var c_goal := 12
var c_spawn := 0.0
var c_elapsed := 0.0

func _start_catch() -> void:
	_set_hud("Stage 1/5 · Containment Catch",
		"Move your collector to net GREEN spores. Avoid RED toxic ones! Collect %d samples." % c_goal)
	c_spores.clear(); c_samples = 0; c_spawn = 0.0; c_elapsed = 0.0
	c_collector = _sprite_node(tex.get("collector"), Vector2(64,64), Color("6fe3c2"))
	c_collector.z_index = 5
	stage_layer.add_child(c_collector)
	tick = _catch_tick

func _catch_tick(delta: float) -> void:
	var field := stage_layer.size
	# collector follows mouse
	var m := stage_layer.get_local_mouse_position()
	var cs := c_collector.size
	c_collector.position = Vector2(
		clampf(m.x - cs.x*0.5, 0, field.x - cs.x),
		clampf(m.y - cs.y*0.5, 0, field.y - cs.y))
	# spawn
	c_elapsed += delta
	c_spawn -= delta
	var rate := lerpf(0.85, 0.35, clampf(c_elapsed/30.0, 0, 1))  # speeds up
	if c_spawn <= 0.0:
		c_spawn = rate
		_spawn_spore(field)
	# move + collide
	var col_center := c_collector.position + cs*0.5
	for s in c_spores.duplicate():
		s.t += delta
		s.pos += s.vel * delta
		s.vel.x += sin(s.t*3.0 + s.seed) * 12.0 * delta
		s.pos.y += 0.0
		# multiply twist: good spores can split once after a while
		if not s.toxic and not s.split and s.t > 3.2 and c_spores.size() < 16:
			s.split = true
			_spawn_spore(field, false, s.pos + Vector2(18,0))
		var node: Control = s.node
		if is_instance_valid(node):
			node.position = s.pos
		# off bottom
		if s.pos.y > field.y + 30:
			_remove_spore(s); continue
		# collision
		if (s.pos + node.size*0.5).distance_to(col_center) < 44.0:
			if s.toxic:
				_add_score(-25); _hurt(10.0)
			else:
				c_samples += 1; _add_score(40)
				_burst(s.pos, BASE_COLOR[Base.A])
			_remove_spore(s)
	objective_label.text = "Samples %d / %d   ·   net the green, dodge the red" % [c_samples, c_goal]
	if c_samples >= c_goal:
		tick = Callable()
		_beat("Sample Secured", [
			"Genome captured. The sequencer can read it now.",
			"Bases will stream past a scan window — tap the base that PAIRS:",
			"A–T and C–G. Clear them before they breach the cell!",
		], "Start Sequencing  ▶", Phase.SEQUENCER)

func _spawn_spore(field: Vector2, force_toxic = null, at = null) -> void:
	var toxic: bool = (randf() < 0.28) if force_toxic == null else force_toxic
	var node := _sprite_node(
		tex.get("spore_toxic") if toxic else tex.get("spore_good"),
		Vector2(34,34), Color("ff5d5d") if toxic else Color("6ad06a"))
	node.z_index = 3
	stage_layer.add_child(node)
	var pos: Vector2 = at if at != null else Vector2(randf_range(10, field.x-44), -30)
	node.position = pos
	c_spores.append({
		"node": node, "pos": pos,
		"vel": Vector2(randf_range(-20,20), randf_range(70,120)),
		"toxic": toxic, "t": 0.0, "split": false, "seed": randf()*6.28,
	})

func _remove_spore(s) -> void:
	if is_instance_valid(s.node): s.node.queue_free()
	c_spores.erase(s)

# =============================================================================
#  STAGE 2 — GENE SEQUENCER  (action / pair-typing)
# =============================================================================
var q_bases: Array = []
var q_spawn := 0.0
var q_speed := 95.0
var q_cleared := 0
var q_goal := 16
var q_combo := 0
var q_wall_x := 60.0
var q_track_y := 0.0
var q_rna := false

func _start_sequencer() -> void:
	_set_hud("Stage 2/5 · Gene Sequencer",
		"Press the base that PAIRS with the leftmost one. Don't let bases reach the cell!")
	q_bases.clear(); q_spawn = 0.0; q_speed = 95.0; q_cleared = 0; q_combo = 0; q_rna = false
	q_track_y = stage_layer.size.y * 0.5 - 30
	# cell wall on the left
	var wall := _sprite_node(tex.get("alien_cell"), Vector2(86,86), Color("7cc24f"))
	wall.name = "Wall"
	wall.position = Vector2(-6, q_track_y - 14)
	wall.z_index = 2
	stage_layer.add_child(wall)
	q_wall_x = 80.0
	tick = _sequencer_tick
	input_handler = _sequencer_input

func _sequencer_tick(delta: float) -> void:
	q_spawn -= delta
	q_speed = lerpf(95.0, 165.0, clampf(float(q_cleared)/float(q_goal), 0, 1))
	if q_spawn <= 0.0 and q_bases.size() < 6:
		q_spawn = randf_range(1.1, 1.7)
		_spawn_seq_base()
	for b in q_bases.duplicate():
		b.x -= q_speed * delta
		# mutation twist (rare): flip a traveling base
		if randf() < 0.07 * delta and b.x > q_wall_x + 120:
			b.base = _rand_dna()
			_repaint_base(b.node, b.base)
			_shake(b.node)
		if is_instance_valid(b.node):
			b.node.position = Vector2(b.x, q_track_y)
		if b.x <= q_wall_x:
			_remove_seq(b)
			q_combo = 0
			_hurt(12.0)
	objective_label.text = "Cleared %d / %d   ·   Combo x%d   %s" % [
		q_cleared, q_goal, q_combo, "(RNA: A–U!)" if q_rna else ""]
	if q_cleared >= q_goal:
		tick = Callable(); input_handler = Callable()
		_beat("Genome Decoded", [
			"The antidote gene is designed. Now SYNTHESIZE it.",
			"The synthesizer will flash a sequence of bases.",
			"Watch closely, then repeat it back in order. It grows each round...",
		], "Begin Synthesis  ▶", Phase.MEMORY)

func _sequencer_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var pressed := _key_to_base(event.keycode)
	if pressed == -1 or q_bases.is_empty():
		return
	# leftmost (closest to wall) is active
	var active = q_bases[0]
	for b in q_bases:
		if b.x < active.x: active = b
	if pressed == _partner(active.base):
		q_cleared += 1; q_combo += 1
		_add_score(50 * maxi(1, q_combo))
		_zap(active.node)
		_remove_seq(active)
	else:
		q_combo = 0
		_hurt(5.0)

func _spawn_seq_base() -> void:
	var b := _rand_dna()
	var node := _base_node(b, 52)
	node.position = Vector2(stage_layer.size.x + 10, q_track_y)
	node.z_index = 3
	stage_layer.add_child(node)
	q_bases.append({"node": node, "base": b, "x": stage_layer.size.x + 10})

func _remove_seq(b) -> void:
	if is_instance_valid(b.node): b.node.queue_free()
	q_bases.erase(b)

# =============================================================================
#  STAGE 3 — SPLICE MEMORY  (Simon-says)
# =============================================================================
var m_seq: Array = []
var m_pads := {}                 # base -> pad node
var m_input_idx := 0
var m_round := 0
var m_goal_round := 5
var m_showing := false
var m_reverse := false

func _start_memory() -> void:
	_set_hud("Stage 3/5 · Splice Memory", "Watch the gene sequence, then repeat it.")
	m_seq.clear(); m_input_idx = 0; m_round = 0; m_reverse = false
	# 2x2 grid of base pads
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(grid)
	stage_layer.add_child(cc)
	m_pads.clear()
	for b in [Base.A, Base.T, Base.C, Base.G]:
		var pad := _base_node(b, 120)
		pad.mouse_filter = Control.MOUSE_FILTER_STOP
		pad.gui_input.connect(_memory_pad_input.bind(b))
		grid.add_child(pad)
		m_pads[b] = pad
	input_handler = _memory_key_input
	_next_memory_round()

func _next_memory_round() -> void:
	m_round += 1
	if m_round > m_goal_round:
		_beat("Cure Synthesized", [
			"The antidote compound is assembled.",
			"Now CULTIVATE it in the bioreactor.",
			"Keep the culture gauge inside the green band — heat rises, then drifts.",
		], "Enter Bioreactor  ▶", Phase.BIOREACTOR)
		return
	# reverse twist on the 4th round
	m_reverse = (m_round == 4)
	m_seq.append(_rand_dna())
	m_input_idx = 0
	objective_label.text = "Round %d / %d%s — watch..." % [
		m_round, m_goal_round, "   (REVERSE!)" if m_reverse else ""]
	_play_memory_sequence()

func _play_memory_sequence() -> void:
	m_showing = true
	await get_tree().create_timer(0.5).timeout
	for b in m_seq:
		if finished or not is_inside_tree(): return
		_flash_pad(b)
		await get_tree().create_timer(0.62).timeout
	m_showing = false
	if is_inside_tree():
		objective_label.text = "Round %d / %d%s — your turn!" % [
			m_round, m_goal_round, "   (REVERSE!)" if m_reverse else ""]

func _flash_pad(b: int) -> void:
	var pad: Control = m_pads.get(b)
	if not pad: return
	var tw := pad.create_tween()
	tw.tween_property(pad, "modulate", Color(2,2,2,1), 0.12)
	tw.tween_property(pad, "modulate", Color(1,1,1,1), 0.32)

func _memory_pad_input(event: InputEvent, b: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_memory_guess(b)

func _memory_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var b := _key_to_base(event.keycode)
		if b != -1 and b != Base.U:
			_memory_guess(b)

func _memory_guess(b: int) -> void:
	if m_showing or phase != Phase.MEMORY:
		return
	var expected_seq := m_seq.duplicate()
	if m_reverse: expected_seq.reverse()
	var expected = expected_seq[m_input_idx]
	if b == expected:
		_flash_pad(b)
		_add_score(40)
		m_input_idx += 1
		if m_input_idx >= m_seq.size():
			_add_score(120)
			_burst(stage_layer.size*0.5, Color("8defc0"))
			await get_tree().create_timer(0.5).timeout
			_next_memory_round()
	else:
		_hurt(12.0)
		objective_label.text = "Wrong! Watch again..."
		m_input_idx = 0
		await get_tree().create_timer(0.7).timeout
		if not finished:
			_play_memory_sequence()

# =============================================================================
#  STAGE 4 — BIOREACTOR  (balance / timing)
# =============================================================================
var r_needle := 0.5
var r_vel := 0.0
var r_zone_lo := 0.4
var r_zone_hi := 0.62
var r_growth := 0.0
var r_event := 0.0
var r_gauge: Control
var r_zone_rect: ColorRect
var r_needle_rect: ColorRect
var r_growth_bar: ProgressBar
var r_push := false
var r_gauge_h := 360.0

func _start_bioreactor() -> void:
	_set_hud("Stage 4/5 · Bioreactor", "HOLD SPACE (or the HEAT button) to raise the gauge. Keep it GREEN to grow the culture.")
	r_needle = 0.55; r_vel = 0.0; r_growth = 0.0; r_event = 3.0
	r_zone_lo = 0.45; r_zone_hi = 0.70; r_push = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_layer.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	center.add_child(row)

	# reactor art (optional) on the left
	var vessel := _sprite_node(tex.get("reactor"), Vector2(150,300), Color("123040"))
	row.add_child(vessel)

	# gauge column
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 10)
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(gv)
	gv.add_child(_center(_label("CULTURE GAUGE", 14, Color("bfe9ff"))))
	r_gauge = Panel.new()
	r_gauge.custom_minimum_size = Vector2(90, r_gauge_h)
	var gsb := StyleBoxFlat.new(); gsb.bg_color = Color("0c1620")
	gsb.set_border_width_all(2); gsb.border_color = Color("32505f"); gsb.set_corner_radius_all(8)
	r_gauge.add_theme_stylebox_override("panel", gsb)
	gv.add_child(r_gauge)
	r_zone_rect = ColorRect.new(); r_zone_rect.color = Color(0.23,0.82,0.48,0.45)
	r_gauge.add_child(r_zone_rect)
	r_needle_rect = ColorRect.new(); r_needle_rect.color = Color("ffe066")
	r_needle_rect.size = Vector2(90, 8)
	r_gauge.add_child(r_needle_rect)

	# growth + heat button column
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 16)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(cv)
	cv.add_child(_label("GROWTH", 14, Color("bfe9ff")))
	r_growth_bar = ProgressBar.new()
	r_growth_bar.max_value = 100; r_growth_bar.value = 0; r_growth_bar.show_percentage = false
	r_growth_bar.custom_minimum_size = Vector2(220, 22)
	_style_progress(r_growth_bar, Color("8defc0"))
	cv.add_child(r_growth_bar)
	var heat := Button.new()
	heat.text = "🔥 HEAT (hold)"
	heat.custom_minimum_size = Vector2(220, 64)
	heat.focus_mode = Control.FOCUS_NONE
	_style_button(heat, Color("e8654a"))
	heat.button_down.connect(func(): r_push = true)
	heat.button_up.connect(func(): r_push = false)
	cv.add_child(heat)
	cv.add_child(_label("…or hold SPACE", 12, Color("9fb6c4")))
	tick = _bioreactor_tick

func _bioreactor_tick(delta: float) -> void:
	r_push = r_push or Input.is_key_pressed(KEY_SPACE)
	# needle physics
	r_vel -= 0.55 * delta                       # gravity
	if r_push: r_vel += 1.25 * delta            # heat lifts
	r_vel = clampf(r_vel, -0.9, 0.9)
	r_needle = clampf(r_needle + r_vel*delta, 0.0, 1.0)
	if r_needle <= 0.0 or r_needle >= 1.0: r_vel = 0.0
	r_push = false
	# random events: shift the safe zone / jolt
	r_event -= delta
	if r_event <= 0.0:
		r_event = randf_range(3.0, 5.5)
		var span := r_zone_hi - r_zone_lo
		r_zone_lo = randf_range(0.2, 0.82 - span)
		r_zone_hi = r_zone_lo + span
		r_vel += randf_range(-0.35, 0.35)
	# growth when in green
	var in_zone := r_needle >= r_zone_lo and r_needle <= r_zone_hi
	if in_zone:
		r_growth = minf(100.0, r_growth + 17.0*delta)
	else:
		# out of the green band only stalls/loses growth — no integrity damage
		r_growth = maxf(0.0, r_growth - 9.0*delta)
	# layout gauge visuals
	var h := r_gauge.size.y
	r_zone_rect.position = Vector2(0, h*(1.0 - r_zone_hi))
	r_zone_rect.size = Vector2(r_gauge.size.x, h*(r_zone_hi - r_zone_lo))
	r_needle_rect.position = Vector2(0, clampf(h*(1.0 - r_needle) - 4, 0, h-8))
	r_needle_rect.color = Color("8defc0") if in_zone else Color("ffce5a")
	r_growth_bar.value = r_growth
	objective_label.text = "Growth %d%%   ·   keep the needle in the green band" % int(r_growth)
	if r_growth >= 100.0:
		tick = Callable()
		_add_score(300)
		_beat("Culture Ready", [
			"The cure is grown and weaponized into a containment serum.",
			"But the spore has bloomed into something huge...",
			"Pair-fire the antidote cannon to bring it down. It WILL adapt.",
		], "Face the Bloom  ▶", Phase.BOSS)

# =============================================================================
#  STAGE 5 — FINAL CONTAINMENT  (boss)
# =============================================================================
var boss_hp := 100.0
var boss_max := 100.0
var boss_phase := 0
var boss_node: Control
var boss_hp_bar: ProgressBar
var b_proj: Array = []
var b_spawn := 0.0
var b_speed := 70.0
var b_rna := false
var b_floor_y := 0.0

func _start_boss() -> void:
	_set_hud("Stage 5/5 · Final Containment", "Press the PAIR of each falling base to blast the bloom. Don't let bases reach the floor!")
	boss_max = 100.0; boss_hp = boss_max; boss_phase = 0; b_proj.clear()
	b_spawn = 0.0; b_speed = 70.0; b_rna = false
	b_floor_y = stage_layer.size.y - 30
	boss_node = _sprite_node(tex.get("boss"), Vector2(150,150), Color("8a4fd0"))
	boss_node.position = Vector2(stage_layer.size.x*0.5 - 75, 8)
	stage_layer.add_child(boss_node)
	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.max_value = boss_max; boss_hp_bar.value = boss_hp; boss_hp_bar.show_percentage = false
	boss_hp_bar.custom_minimum_size = Vector2(stage_layer.size.x*0.6, 16)
	boss_hp_bar.position = Vector2(stage_layer.size.x*0.2, 168)
	_style_progress(boss_hp_bar, Color("ff6f61"))
	stage_layer.add_child(boss_hp_bar)
	# floor line
	var floor_line := ColorRect.new()
	floor_line.color = Color("ff5d5d", 0.5)
	floor_line.position = Vector2(0, b_floor_y + 24)
	floor_line.size = Vector2(stage_layer.size.x, 3)
	stage_layer.add_child(floor_line)
	tick = _boss_tick
	input_handler = _boss_input

func _boss_tick(delta: float) -> void:
	b_spawn -= delta
	var fire_rate := lerpf(1.3, 0.7, 1.0 - boss_hp/boss_max)
	if b_spawn <= 0.0 and b_proj.size() < 7:
		b_spawn = fire_rate
		_boss_fire()
	for p in b_proj.duplicate():
		p.y += b_speed * delta
		if is_instance_valid(p.node):
			p.node.position = Vector2(p.x, p.y)
		if p.y >= b_floor_y:
			_remove_proj(p)
			_hurt(9.0)
	# boss idle bob
	if is_instance_valid(boss_node):
		boss_node.position.x = stage_layer.size.x*0.5 - 75 + sin(Time.get_ticks_msec()*0.002)*40.0
	objective_label.text = "Bloom integrity %d%%   ·   %s" % [
		int(boss_hp), "PHASE %d %s" % [boss_phase+1, "(RNA: A–U!)" if b_rna else ""]]

func _boss_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	var pressed := _key_to_base(event.keycode)
	if pressed == -1 or b_proj.is_empty(): return
	# target the lowest projectile
	var target = b_proj[0]
	for p in b_proj:
		if p.y > target.y: target = p
	if pressed == _partner(target.base):
		_add_score(120)
		_zap(target.node)
		_remove_proj(target)
		_damage_boss(7.0)
	else:
		_hurt(4.0)

func _boss_fire() -> void:
	var b := _rand_dna()
	var node := _base_node(b, 48)
	var x := randf_range(10, stage_layer.size.x - 58)
	node.position = Vector2(x, 180)
	node.z_index = 4
	stage_layer.add_child(node)
	b_proj.append({"node": node, "base": b, "x": x, "y": 180.0})

func _remove_proj(p) -> void:
	if is_instance_valid(p.node): p.node.queue_free()
	b_proj.erase(p)

func _damage_boss(amount: float) -> void:
	boss_hp = maxf(0.0, boss_hp - amount)
	boss_hp_bar.value = boss_hp
	_shake(boss_node)
	# phase transitions at 66% and 33%
	var pct := boss_hp / boss_max
	if boss_phase == 0 and pct <= 0.66:
		boss_phase = 1; b_speed = 95.0
		_announce("PHASE 2 — it speeds up!")
	elif boss_phase == 1 and pct <= 0.33:
		boss_phase = 2; b_speed = 120.0; b_rna = true
		_announce("PHASE 3 — it mutates to RNA! A pairs with U!")
	if boss_hp <= 0.0:
		_goto(Phase.VICTORY)

# =============================================================================
#  Victory / defeat
# =============================================================================
func _victory() -> void:
	if finished: return
	finished = true
	tick = Callable(); input_handler = Callable()
	_clear_stage()
	_set_hud("XENO LAB", "Mission complete — bloom contained.")
	var stars := _calc_stars()
	_record_completion(stars)
	_result("Bloom Contained!", stars, [
		"You captured, decoded, synthesized, cultivated, and contained the alien organism.",
		"Score %d   ·   Integrity %d%%" % [score, int(integrity)],
		"Stars earned: %d / 5" % stars,
	], true)

func _defeat() -> void:
	if finished: return
	finished = true
	tick = Callable(); input_handler = Callable()
	_result("Containment Breached", -1, [
		"The lab was overwhelmed. The alien organism escaped this attempt.",
		"Steady hands and quick pairing will hold the line — try again.",
	], false)

func _calc_stars() -> int:
	var stars := 2
	if score >= 4500: stars += 1
	if integrity >= 50.0: stars += 1
	if integrity >= 85.0: stars += 1
	return clampi(stars, 1, 5)

func _record_completion(stars: int) -> void:
	if not record_on_win:
		return
	var sm := get_node_or_null("/root/StarManager")
	if sm and sm.has_method("record_quest_stars"):
		var best := stars
		if sm.has_method("get_quest_stars"):
			best = maxi(stars, int(sm.get_quest_stars(quest_id)))
		sm.record_quest_stars(quest_id, domain, best, 5)
	var em := get_node_or_null("/root/EndingManager")
	if em and em.has_method("complete_quest"):
		em.complete_quest(quest_id, domain, stars)
	var legacy := get_node_or_null("/root/LegacyAchievementManager")
	if legacy and legacy.has_method("check_star_achievements"):
		legacy.check_star_achievements()

# =============================================================================
#  Overlay: story cards & results
# =============================================================================
func _story(title: String, lines: Array, btn_label: String, on_continue: Callable) -> void:
	_build_overlay(title, -1, lines, btn_label, on_continue, true)

func _result(title: String, stars_n: int, lines: Array, won: bool) -> void:
	_build_overlay(title, stars_n, lines, "", Callable(), false)
	if won:
		_start_auto_return()

func _build_overlay(title: String, stars_n: int, lines: Array, btn_label: String, on_continue: Callable, is_story: bool) -> void:
	for c in overlay.get_children(): c.queue_free()
	overlay.visible = true
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	# PanelContainer wraps + sizes to its content (a plain Panel would draw at 0 height)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _frame_box(20, Color.WHITE, "card_frame"))
	card.custom_minimum_size = Vector2(680, 0)
	cc.add_child(card)
	var m := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		m.add_theme_constant_override("margin_"+side, 8)
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var title_col := Color("8defc0") if (is_story or stars_n >= 0) else Color("ff8a7a")
	v.add_child(_center(_label(title, 26, title_col)))
	if stars_n >= 0:
		v.add_child(_center(_star_row(stars_n)))
	for ln in lines:
		var l := _label(ln, 15, Color("dcecf5"))
		l.custom_minimum_size = Vector2(620, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_center(l))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(_center(row))
	if btn_label != "":
		var b := Button.new()
		b.text = btn_label
		b.custom_minimum_size = Vector2(240, 50)
		b.focus_mode = Control.FOCUS_NONE
		_style_button(b, Color("2f9e5a"))
		b.pressed.connect(func():
			overlay.visible = false
			for c in overlay.get_children(): c.queue_free()
			if on_continue.is_valid(): on_continue.call())
		row.add_child(b)
	else:
		# result buttons
		var again := Button.new()
		again.text = "Try Again"; again.custom_minimum_size = Vector2(180,48); again.focus_mode = Control.FOCUS_NONE
		_style_button(again, Color("2f6f9e"))
		again.pressed.connect(_restart)
		row.add_child(again)
		var leave := Button.new()
		leave.text = "Return to Lab"; leave.custom_minimum_size = Vector2(200,48); leave.focus_mode = Control.FOCUS_NONE
		_style_button(leave, Color("2f9e5a"))
		leave.pressed.connect(_return_to_domain)
		row.add_child(leave)

func _announce(text: String) -> void:
	var lbl := _label(text, 24, Color("ffe9a8"))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.85))
	lbl.position = Vector2(20, stage_layer.size.y*0.38)
	lbl.size = Vector2(stage_layer.size.x - 40, 80)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)

func _start_auto_return() -> void:
	if auto_return_delay > 0.0:
		await get_tree().create_timer(auto_return_delay).timeout
		if is_inside_tree() and finished:
			_return_to_domain()

func _restart() -> void:
	finished = false
	integrity = INTEGRITY_MAX
	score = 0
	retries += 1
	overlay.visible = false
	for c in overlay.get_children(): c.queue_free()
	_update_hud()
	_goto(Phase.CATCH)

func _return_to_domain() -> void:
	if return_scene != "":
		get_tree().change_scene_to_file(return_scene)

# =============================================================================
#  Shared helpers
# =============================================================================
func _rand_dna() -> int:
	return [Base.A, Base.T, Base.C, Base.G][randi() % 4]

func _partner(b: int) -> int:
	var rna := (phase == Phase.BOSS and b_rna)
	match b:
		Base.A: return Base.U if rna else Base.T
		Base.T: return Base.A
		Base.U: return Base.A
		Base.C: return Base.G
		Base.G: return Base.C
	return Base.A

func _key_to_base(keycode: int) -> int:
	match keycode:
		KEY_A: return Base.A
		KEY_T: return Base.T
		KEY_C: return Base.C
		KEY_G: return Base.G
		KEY_U: return Base.U
	return -1

func _stars(n: int) -> String:
	var s := ""
	for i in 5: s += "★" if i < n else "☆"
	return s

func _star_row(n: int) -> Control:
	# pixel-art star row (falls back to text glyphs if star art is missing)
	if not tex.get("star_full"):
		return _label(_stars(n), 40, Color("ffd54a"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in 5:
		var st := TextureRect.new()
		st.texture = tex.get("star_full") if i < n else tex.get("star_empty")
		st.custom_minimum_size = Vector2(40, 40)
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		st.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(st)
	return row

# ---- visual node factories --------------------------------------------------
func _sprite_node(texture, sz: Vector2, fallback: Color) -> Control:
	if texture:
		var tr := TextureRect.new()
		tr.texture = texture
		tr.custom_minimum_size = sz
		tr.size = sz
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var p := Panel.new()
	p.custom_minimum_size = sz; p.size = sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = fallback.darkened(0.2)
	sb.border_color = fallback.lightened(0.3)
	sb.set_border_width_all(2); sb.set_corner_radius_all(int(min(sz.x,sz.y)*0.4))
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _base_node(b: int, sz: int) -> Control:
	var key: String = "base_" + str(BASE_LETTER[b]).to_lower()
	if tex.get(key):
		var n := _sprite_node(tex.get(key), Vector2(sz, sz), BASE_COLOR[b])
		return n
	# fallback styled tile + letter
	var p := Panel.new()
	p.custom_minimum_size = Vector2(sz, sz); p.size = Vector2(sz, sz)
	var col: Color = BASE_COLOR[b]
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.35); sb.border_color = col
	sb.set_border_width_all(3); sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.name = "L"; lbl.text = BASE_LETTER[b]
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(sz*0.5))
	lbl.add_theme_color_override("font_color", col.lightened(0.5))
	p.add_child(lbl)
	return p

func _repaint_base(node: Control, b: int) -> void:
	var key: String = "base_" + str(BASE_LETTER[b]).to_lower()
	if node is TextureRect and tex.get(key):
		node.texture = tex.get(key)
		return
	var sb := node.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		var col: Color = BASE_COLOR[b]
		sb.bg_color = col.darkened(0.35); sb.border_color = col
	var lbl := node.get_node_or_null("L") as Label
	if lbl:
		lbl.text = BASE_LETTER[b]
		lbl.add_theme_color_override("font_color", BASE_COLOR[b].lightened(0.5))

# ---- generic UI helpers -----------------------------------------------------
func _frame_box(content_margin: int = 10, mod: Color = Color.WHITE, frame_name: String = "panel_frame") -> StyleBox:
	# pixel-art 9-slice panel frame (falls back to a flat box if art missing)
	if tex.get(frame_name):
		var sb := StyleBoxTexture.new()
		sb.texture = tex.get(frame_name)
		sb.modulate_color = mod
		sb.texture_margin_left = 6; sb.texture_margin_top = 6
		sb.texture_margin_right = 6; sb.texture_margin_bottom = 6
		sb.content_margin_left = content_margin; sb.content_margin_right = content_margin
		sb.content_margin_top = content_margin; sb.content_margin_bottom = content_margin
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = Color("12202b"); f.border_color = Color("2f5d72")
	f.set_border_width_all(2); f.set_corner_radius_all(8)
	return f

func _panel(_fill: Color = Color.BLACK, _border: Color = Color.BLACK) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _frame_box())
	return p

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _center(c: Control) -> Control:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc

func _button_box(col: Color) -> StyleBox:
	if tex.get("button_frame"):
		var sb := StyleBoxTexture.new()
		sb.texture = tex.get("button_frame")
		sb.modulate_color = col
		sb.texture_margin_left = 5; sb.texture_margin_top = 5
		sb.texture_margin_right = 5; sb.texture_margin_bottom = 5
		sb.content_margin_left = 14; sb.content_margin_right = 14
		sb.content_margin_top = 9; sb.content_margin_bottom = 9
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = col.darkened(0.15); f.border_color = col.lightened(0.25)
	f.set_border_width_all(2); f.set_corner_radius_all(8)
	f.content_margin_left = 12; f.content_margin_right = 12
	f.content_margin_top = 8; f.content_margin_bottom = 8
	return f

func _style_button(btn: Button, col: Color) -> void:
	btn.add_theme_stylebox_override("normal", _button_box(col))
	btn.add_theme_stylebox_override("hover", _button_box(col.lightened(0.16)))
	btn.add_theme_stylebox_override("pressed", _button_box(col.darkened(0.2)))
	btn.add_theme_stylebox_override("disabled", _button_box(col.darkened(0.45)))
	btn.add_theme_color_override("font_color", Color("f7fffb"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))

func _style_progress(bar: ProgressBar, fill: Color) -> void:
	bar.add_theme_stylebox_override("background", _frame_box(3))   # pixel frame
	var fg := StyleBoxFlat.new(); fg.bg_color = fill               # square pixel fill
	fg.content_margin_top = 0; fg.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fg)

# ---- juice ------------------------------------------------------------------
func _flash_damage() -> void:
	if _flashing:
		return
	_flashing = true
	var f := ColorRect.new()
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.color = Color(1,0.2,0.2,0.28)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(func(): f.queue_free(); _flashing = false)

func _burst(pos: Vector2, col: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos + stage_layer.global_position
	p.amount = 16; p.lifetime = 0.7; p.one_shot = true; p.emitting = true
	p.explosiveness = 0.9; p.spread = 180; p.initial_velocity_min = 80; p.initial_velocity_max = 180
	p.scale_amount_min = 2.0; p.scale_amount_max = 3.5; p.color = col
	ui_layer.add_child(p)
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)

func _zap(node: Control) -> void:
	if not is_instance_valid(node): return
	var tw := node.create_tween()
	tw.tween_property(node, "position:y", node.position.y - 40, 0.18)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.18)

func _shake(node: Control) -> void:
	if not is_instance_valid(node): return
	var bx := node.position.x
	var tw := node.create_tween()
	for i in 4:
		tw.tween_property(node, "position:x", bx + (6 if i%2==0 else -6), 0.04)
	tw.tween_property(node, "position:x", bx, 0.04)

# =============================================================================
#  Debug hook for offline screenshots
# =============================================================================
func debug_setup(state: String) -> void:
	match state:
		"intro": _show_intro()
		"catch": _goto(Phase.CATCH)
		"sequencer": _goto(Phase.SEQUENCER)
		"memory": _goto(Phase.MEMORY)
		"bioreactor": _goto(Phase.BIOREACTOR)
		"boss": _goto(Phase.BOSS)
		"victory": score = 5200; integrity = 90.0; _victory()
