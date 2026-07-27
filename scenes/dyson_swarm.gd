extends Node2D
# =============================================================================
#  DYSON SWARM  —  Engineering Realm, Quest 2
#  A structured quest: Briefing (story + real science) -> Controls -> Play ->
#  Debrief. The player deploys a swarm of collector mirrors around a dying star
#  to capture its energy before the launch window closes.
# =============================================================================

# --- Quest wiring (mirrors the XENO LAB pattern) ---
@export var quest_id: String = "engineering_quest_2"
@export var domain: String = "Engineering"
@export var return_scene: String = "res://scenes/maps/EngineeringHouse.tscn"
@export var auto_return_delay: float = 8.0
var record_on_win: bool = true   # harness sets false so screenshots don't touch the save

# --- World nodes (from the .tscn) ---
@onready var ring1 = $Ring1
@onready var ring2 = $Ring2
@onready var ring3 = $Ring3
@onready var ship = $Ship

# --- Tuning (energy curve lives here so it is easy to balance) ---
@export var mission_time: float = 60.0
const MAX_ENERGY := 100.0
const RING_RADII := [100, 175, 250]
const RING_RATES := [0.12, 0.22, 0.36]        # energy/sec per mirror at full efficiency
const RING_FLARE_WEIGHT := [1.0, 2.2, 3.6]    # outer rings are struck far more often

@export var flare_interval: float = 12.5
@export var flare_warn_time: float = 2.6
@export var flare_half_width: float = 0.46     # ~26 degree wedge

var debris_scene = preload("res://scenes/debris.tscn")
var flare_scene = preload("res://scenes/solar_flare.tscn")
@export var asteroid_sprites: Array[Texture2D] = []

# --- Colours ---
const RING_COLORS := [Color(0.30, 0.62, 1.0), Color(1.0, 0.82, 0.25), Color(1.0, 0.46, 0.20)]
const RING_GLOW := [Color(0.55, 0.85, 1.0), Color(1.0, 1.0, 0.45), Color(1.0, 0.70, 0.35)]
const C_BG := Color(0.02, 0.03, 0.08, 0.86)
const C_PANEL := Color(0.07, 0.10, 0.20, 0.98)
const C_GOLD := Color(1.0, 0.82, 0.32)
const C_TEXT := Color(0.86, 0.92, 1.0)
const C_DIM := Color(0.62, 0.70, 0.84)
const C_GOOD := Color(0.52, 1.0, 0.72)
const C_WARN := Color(1.0, 0.42, 0.26)

# --- State ---
enum Phase { BRIEFING, CONTROLS, PLAY, RESULT }
var phase: int = Phase.BRIEFING
var total_energy: float = 0.0
var time_left: float = 0.0
var game_over: bool = false
var finished: bool = false

var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var flare_timer: float = 0.0
var _active_flare = null

# --- UI built in code ---
const ART_DIR := "res://assets/generated/dyson/"
var font: Font = load("res://art/Dialogue/determination.ttf")
var tex := {}                    # name -> Texture2D or null (pixel-art UI chrome)
var ui: CanvasLayer
var ui_root: Control
var hud: Control
var overlay: Control
var energy_fill: ColorRect
var lbl_energy: Label
var lbl_time: Label
var lbl_reserve: Label
var lbl_rings: Array = []
var lbl_health: Label
var flare_banner: Label
var _primary_action: Callable = Callable()
var _brief_page: int = 0
var _cam: Camera2D

# =============================================================================
#  Setup
# =============================================================================
func _ready():
	_cam = $Camera2D
	_cam.enabled = true
	_cam.make_current()
	_cam.global_position = Vector2.ZERO
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)

	# Crafted pixel-art asteroids; debris.gd picks one at random for variety.
	asteroid_sprites = [
		load("res://assets/generated/dyson/asteroid_1.png"),
		load("res://assets/generated/dyson/asteroid_2.png"),
		load("res://assets/generated/dyson/asteroid_3.png"),
	]

	_draw_ring(ring1, RING_RADII[0], RING_COLORS[0])
	_draw_ring(ring2, RING_RADII[1], RING_COLORS[1])
	_draw_ring(ring3, RING_RADII[2], RING_COLORS[2])

	var tscn_ui = get_node_or_null("UI")
	if tscn_ui:
		tscn_ui.visible = false   # we build our own UI in code

	ship.active = false
	time_left = mission_time
	_build_ui()
	_show_briefing()

func _exit_tree():
	pass

# Zoom the camera so the whole play area — all three rings AND the ship's outer
# orbit — fits on screen with a margin, at any window size.
func _fit_camera():
	if _cam == null:
		return
	var vp = get_viewport().get_visible_rect().size
	var outermost = ship.orbit_radius + 48.0   # ship orbit + room for its sprite
	var pad = 16.0
	var zx = (vp.x * 0.5 - pad) / outermost
	var zy = (vp.y * 0.5 - pad) / outermost
	var z = clampf(min(zx, zy), 0.4, 2.0)
	_cam.zoom = Vector2(z, z)

# =============================================================================
#  Main loop (only ticks during PLAY)
# =============================================================================
func _process(delta):
	if phase != Phase.PLAY or game_over:
		return

	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish(true)
		return

	_collect_energy(delta)

	flare_timer += delta
	if flare_timer >= flare_interval:
		flare_timer = 0.0
		_trigger_flare()

	var t_elapsed = mission_time - time_left
	spawn_interval = max(0.7, 3.0 - (t_elapsed / 28.0))
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_debris()

	_update_ring_glow()
	_update_hud()

func _collect_energy(delta):
	for mirror in get_tree().get_nodes_in_group("mirror"):
		var i: int = mirror.ring_index
		if i >= 0 and i < RING_RATES.size():
			total_energy += RING_RATES[i] * mirror.efficiency * delta
	total_energy = min(total_energy, MAX_ENERGY)

# =============================================================================
#  Flares (telegraphed; the ship can shield the marked sector)
# =============================================================================
func _trigger_flare():
	var ring := _weighted_ring()
	var center := randf() * TAU
	_active_flare = {"ring": ring, "center": center}

	var arc := _make_arc(RING_RADII[ring], center, flare_half_width, C_WARN, 7.0)
	arc.name = "FlareWarn"
	add_child(arc)
	var tw := arc.create_tween().set_loops()
	tw.tween_property(arc, "modulate:a", 0.25, 0.25)
	tw.tween_property(arc, "modulate:a", 1.0, 0.25)

	if flare_banner:
		flare_banner.text = "!  SOLAR FLARE INCOMING  -  RING %d  -  shield it!" % (ring + 1)
		flare_banner.visible = true

	await get_tree().create_timer(flare_warn_time).timeout
	if game_over or phase != Phase.PLAY:
		arc.queue_free()
		if flare_banner: flare_banner.visible = false
		return
	_fire_flare(ring, center)
	arc.queue_free()
	if flare_banner: flare_banner.visible = false

func _fire_flare(ring: int, center: float):
	var beam = flare_scene.instantiate()
	add_child(beam)
	beam.fire(center)

	# Ship intercepts the flare if its orbit sits inside the warned sector.
	if ship and ship.angle_in_sector(center, flare_half_width + 0.22):
		ship.flash_shield()
		_announce("SHIELDED!", C_GOOD)
		return

	var lost := 0
	for m in get_tree().get_nodes_in_group("mirror"):
		if m.ring_index != ring:
			continue
		var d = abs(fmod(m.orbit_angle - center + PI, TAU) - PI)
		if d <= flare_half_width:
			m.queue_free()
			lost += 1
	if lost > 0:
		_announce("-%d mirrors" % lost, C_WARN)

func _weighted_ring() -> int:
	var total := 0.0
	for w in RING_FLARE_WEIGHT:
		total += w
	var r := randf() * total
	var acc := 0.0
	for i in range(RING_FLARE_WEIGHT.size()):
		acc += RING_FLARE_WEIGHT[i]
		if r <= acc:
			return i
	return RING_FLARE_WEIGHT.size() - 1

# =============================================================================
#  Debris
# =============================================================================
func _spawn_debris():
	var debris = debris_scene.instantiate()
	var angle = randf() * TAU
	var spawn_pos = Vector2(cos(angle), sin(angle)) * 420
	debris.position = spawn_pos
	var target = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	debris.direction = (target - spawn_pos).normalized()
	debris.sprites = asteroid_sprites
	var t_elapsed = mission_time - time_left
	debris.speed = 150.0 + (t_elapsed * 2.6)
	add_child(debris)

# =============================================================================
#  Rings
# =============================================================================
func _draw_ring(line: Line2D, radius: float, color: Color):
	line.default_color = color
	line.width = 2.0
	var points = []
	for i in range(65):
		var a = (i / 64.0) * TAU
		points.append(Vector2(cos(a), sin(a)) * radius)
	line.points = points

func _make_arc(radius: float, center: float, half: float, color: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.default_color = color
	l.width = width
	var pts := []
	var steps := 18
	for i in range(steps + 1):
		var a = center - half + (2.0 * half) * (i / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * radius)
	l.points = pts
	return l

func _update_ring_glow():
	var rings = [ring1, ring2, ring3]
	for i in range(3):
		if i == ship.selected_ring:
			rings[i].default_color = RING_GLOW[i]
			rings[i].width = 4.0
		else:
			rings[i].default_color = RING_COLORS[i]
			rings[i].width = 2.0

# =============================================================================
#  Outcome
# =============================================================================
func on_ship_destroyed():
	_finish(false)

func _finish(success: bool):
	if phase == Phase.RESULT:
		return
	phase = Phase.RESULT
	game_over = true
	finished = true
	ship.active = false

	var stars := get_star_count()
	if not success:
		stars = min(stars, 2)   # losing the ship caps the reward

	global.dyson_stars = stars
	global.dyson_energy = total_energy
	if record_on_win:
		_record_completion(stars)

	var title := "Mission Complete" if success else "The Swarm Was Lost"
	var lines := [
		"Starlight captured:  %d%%" % int(round(total_energy)),
		_rating_line(stars),
		"",
		_takeaway(success),
	]
	_show_result(title, stars, lines, success)

func get_star_count() -> int:
	if total_energy >= 84: return 5
	elif total_energy >= 63: return 4
	elif total_energy >= 43: return 3
	elif total_energy >= 23: return 2
	else: return 1

func _rating_line(stars: int) -> String:
	match stars:
		5: return "Stellar Architect — the colony basks in endless light."
		4: return "Master Engineer — their world is bright and warm again."
		3: return "Their lamps flicker back to life. Solid work."
		2: return "Barely enough to hold back the dark."
		_: return "The colony still shivers in the cold."

func _takeaway(success: bool) -> String:
	if success:
		return "A real Dyson swarm would capture more energy in a second than humanity has used in all of history."
	return "Even partial swarms matter — every collector you place buys the colony more time."

func _record_completion(stars: int) -> void:
	var sm = get_node_or_null("/root/StarManager")
	if sm and sm.has_method("record_quest_stars"):
		var best := stars
		if sm.has_method("get_quest_stars"):
			best = maxi(stars, int(sm.get_quest_stars(quest_id)))
		sm.record_quest_stars(quest_id, domain, best, 5)
	var em = get_node_or_null("/root/EndingManager")
	if em and em.has_method("complete_quest"):
		em.complete_quest(quest_id, domain, stars)
	var legacy = get_node_or_null("/root/LegacyAchievementManager")
	if legacy and legacy.has_method("check_star_achievements"):
		legacy.check_star_achievements()

# =============================================================================
#  UI construction
# =============================================================================
func _load_art():
	for n in ["space_background", "panel_frame", "card_frame", "button_frame", "bar_frame", "star_full", "star_empty"]:
		var p: String = ART_DIR + n + ".png"
		tex[n] = load(p) if ResourceLoader.exists(p) else null

func _build_background():
	# Full-screen pixel-art space backdrop on its own layer behind the world.
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -5
	add_child(bg_layer)
	if tex.get("space_background"):
		var tr := TextureRect.new()
		tr.texture = tex.get("space_background")
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_layer.add_child(tr)
	else:
		var cr := ColorRect.new()
		cr.color = Color(0.03, 0.04, 0.09)
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_layer.add_child(cr)
	# The old world-space background sprite is replaced by this layer.
	var old_bg = get_node_or_null("Background")
	if old_bg:
		old_bg.visible = false

func _build_ui():
	_load_art()
	_build_background()
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)

	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	if font:
		theme.default_font = font
	ui_root.theme = theme
	ui.add_child(ui_root)

	_build_hud()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)

func _build_hud():
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud)

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _tex_box("panel_frame", 6, 8))
	panel.position = Vector2(14, 12)
	panel.size = Vector2(252, 196)
	hud.add_child(panel)

	lbl_energy = _mk_label("SOLAR ENERGY  0%", 18, C_GOLD)
	lbl_energy.position = Vector2(28, 22)
	hud.add_child(lbl_energy)

	var bar_bg := Panel.new()
	bar_bg.add_theme_stylebox_override("panel", _tex_box("bar_frame", 3, 0))
	bar_bg.position = Vector2(28, 48)
	bar_bg.size = Vector2(224, 16)
	hud.add_child(bar_bg)
	energy_fill = ColorRect.new()
	energy_fill.color = C_GOLD
	energy_fill.position = Vector2(31, 51)
	energy_fill.size = Vector2(0, 10)
	hud.add_child(energy_fill)

	lbl_time = _mk_label("TIME  1:15", 16, C_TEXT)
	lbl_time.position = Vector2(28, 70)
	hud.add_child(lbl_time)

	lbl_reserve = _mk_label("MIRRORS  6/6", 16, C_GOOD)
	lbl_reserve.position = Vector2(28, 94)
	hud.add_child(lbl_reserve)

	lbl_rings = []
	for i in range(3):
		var l := _mk_label("RING %d  0/0" % (i + 1), 15, RING_COLORS[i])
		l.position = Vector2(28, 118 + i * 22)
		hud.add_child(l)
		lbl_rings.append(l)

	lbl_health = _mk_label("HULL  ###", 15, C_WARN)
	lbl_health.position = Vector2(150, 94)
	hud.add_child(lbl_health)

	flare_banner = _mk_label("", 20, C_WARN)
	flare_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	flare_banner.offset_top = 18
	flare_banner.offset_bottom = 50
	flare_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flare_banner.add_theme_constant_override("outline_size", 6)
	flare_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	flare_banner.visible = false
	hud.add_child(flare_banner)

	var hint := _mk_label("← →  orbit      1 / 2 / 3  select ring      SPACE  deploy mirror", 15, C_DIM)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -38
	hint.offset_bottom = -12
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("outline_size", 4)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud.add_child(hint)

	hud.visible = false

func _update_hud():
	var pct := int(round(total_energy))
	lbl_energy.text = "SOLAR ENERGY  %d%%" % pct
	energy_fill.size.x = 218.0 * (total_energy / MAX_ENERGY)
	energy_fill.color = C_GOOD if pct >= 68 else (C_GOLD if pct >= 40 else C_WARN)

	var m := int(time_left)
	lbl_time.text = "TIME  %d:%02d" % [m / 60, m % 60]
	if time_left <= 10:
		lbl_time.add_theme_color_override("font_color", C_WARN)

	lbl_reserve.text = "MIRRORS  %d" % ship.mirrors_left
	lbl_reserve.add_theme_color_override("font_color", C_GOOD if ship.mirrors_left > 0 else C_DIM)

	for i in range(3):
		var sel := "> " if ship.selected_ring == i else "  "
		lbl_rings[i].text = "%sRING %d  %d/%d" % [sel, i + 1, ship.ring_mirror_counts[i], ship.MAX_MIRRORS_PER_RING[i]]
		lbl_rings[i].add_theme_color_override("font_color", RING_GLOW[i] if ship.selected_ring == i else RING_COLORS[i])

	lbl_health.text = "HULL  " + "#".repeat(max(0, ship.health))

func _announce(text: String, color: Color):
	var lbl := _mk_label(text, 26, color)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(-160, -40)
	lbl.size = Vector2(320, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 40, 1.0)
	tw.parallel().tween_interval(0.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)

# =============================================================================
#  Overlay cards (briefing / controls / result)
# =============================================================================
func _show_briefing():
	phase = Phase.BRIEFING
	_brief_page = 0
	_briefing_page()

func _briefing_page():
	var pages := [
		{
			"title": "The Dimming Star",
			"body": "A distant colony is freezing in the dark — their star is fading and their machines are starving for power.\n\nAs the Shifter, you answer their distress call. You will build a [color=#ffd24f]Dyson Swarm[/color] to capture the star's light and bring their world back to life.",
			"btn": "Continue",
		},
		{
			"title": "What is a Dyson Swarm?",
			"body": "In 1960, physicist [color=#ffd24f]Freeman Dyson[/color] imagined surrounding a star with a vast fleet of solar collectors.\n\nUnlike a solid shell, a [i]swarm[/i] is built piece by piece. Each mirror orbits on its own and captures a sliver of the star's enormous output. More collectors on closer orbits means more power.",
			"btn": "Continue",
		},
		{
			"title": "Your Mission",
			"body": "Deploy collectors across three orbital rings before the launch window closes.\n\n[color=#7fd0ff]Inner ring[/color]: safe, but low yield.\n[color=#ffd24f]Middle ring[/color]: a balanced bet.\n[color=#ff8a5a]Outer ring[/color]: the most energy — but solar storms strike it often.\n\nCapture as much starlight as you can to earn Stars for the Engineering Realm.",
			"btn": "Flight Controls",
		},
	]
	var p = pages[_brief_page]
	_build_card(p.title, -1, p.body, p.btn, func():
		_brief_page += 1
		if _brief_page < pages.size():
			_briefing_page()
		else:
			_show_controls())

func _show_controls():
	phase = Phase.CONTROLS
	var body := "[color=#ffd24f]← / →[/color]   speed up / slow your collector ship's orbit\n"
	body += "[color=#ffd24f]1 / 2 / 3[/color]   select the inner / middle / outer ring\n"
	body += "[color=#ffd24f]SPACE[/color]   deploy a mirror onto the selected ring\n\n"
	body += "•  Mirrors [color=#ff8a5a]burn out[/color] over time — keep replacing them.\n"
	body += "•  Your mirror reserve refills slowly, so spend it wisely.\n"
	body += "•  When a [color=#ff8a5a]SOLAR FLARE[/color] is marked on a ring, fly your ship\n   into that sector to [color=#8defc0]shield[/color] it from destruction."
	_build_card("Flight Controls", -1, body, "Begin Mission  ▶", func(): _start_play())

func _start_play():
	phase = Phase.PLAY
	overlay.visible = false
	for c in overlay.get_children():
		c.queue_free()
	_primary_action = Callable()
	hud.visible = true
	flare_timer = 0.0
	spawn_timer = 0.0
	time_left = mission_time
	ship.active = true
	_update_hud()

func _show_result(title: String, stars: int, lines: Array, success: bool):
	hud.visible = false
	var body := ""
	for ln in lines:
		body += ln + "\n"
	_build_card(title, stars, body.strip_edges(), "", Callable(), true)
	if success and auto_return_delay > 0.0:
		_auto_return()

func _auto_return():
	await get_tree().create_timer(auto_return_delay).timeout
	if is_inside_tree() and finished:
		_return_to_domain()

func _return_to_domain():
	if return_scene != "":
		get_tree().change_scene_to_file(return_scene)

func _restart():
	get_tree().change_scene_to_file("res://scenes/dyson_swarm.tscn")

# Builds a centered card. stars >= 0 shows a star row; result cards (is_result)
# show Try Again / Return instead of a single continue button.
func _build_card(title: String, stars: int, body: String, btn_label: String, on_continue: Callable, is_result := false):
	overlay.visible = true
	for c in overlay.get_children():
		c.queue_free()

	var dim := ColorRect.new()
	dim.color = C_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)

	var vp_w := get_viewport().get_visible_rect().size.x
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _tex_box("card_frame", 7, 16))
	card.custom_minimum_size = Vector2(min(640.0, vp_w - 48.0), 0)
	cc.add_child(card)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26)
	card.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)

	var title_lbl := _mk_label(title, 30, C_GOLD)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_lbl)

	if stars >= 0:
		v.add_child(_star_row(stars))

	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.custom_minimum_size = Vector2(min(588.0, vp_w - 100.0), 0)
	rich.add_theme_font_override("normal_font", font)
	rich.add_theme_font_override("italics_font", font)
	rich.add_theme_font_size_override("normal_font_size", 17)
	rich.add_theme_color_override("default_color", C_TEXT)
	rich.text = "[center]" + body + "[/center]"
	v.add_child(rich)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)

	if is_result:
		var again := _mk_button("Try Again", Color(0.20, 0.42, 0.66))
		again.pressed.connect(_restart)
		row.add_child(again)
		var leave := _mk_button("Return to Realm", Color(0.18, 0.55, 0.34))
		leave.pressed.connect(_return_to_domain)
		row.add_child(leave)
		_primary_action = Callable()
	else:
		var b := _mk_button(btn_label, Color(0.18, 0.55, 0.34))
		b.pressed.connect(func(): _do_primary(on_continue))
		row.add_child(b)
		_primary_action = func(): _do_primary(on_continue)

func _do_primary(on_continue: Callable):
	_primary_action = Callable()
	if on_continue.is_valid():
		on_continue.call()

func _input(event):
	# Enter / Space / click advances briefing & controls cards.
	if _primary_action.is_valid() and phase in [Phase.BRIEFING, Phase.CONTROLS]:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_drop") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			var act = _primary_action
			act.call()
			get_viewport().set_input_as_handled()

# =============================================================================
#  Small widget helpers
# =============================================================================
func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l

func _mk_button(text: String, base: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _tex_box("button_frame", 5, 12, base))
	b.add_theme_stylebox_override("hover", _tex_box("button_frame", 5, 12, base.lightened(0.18)))
	b.add_theme_stylebox_override("pressed", _tex_box("button_frame", 5, 12, base.darkened(0.2)))
	return b

func _star_row(n: int) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	for i in range(5):
		if tex.get("star_full"):
			var st := TextureRect.new()
			st.texture = tex.get("star_full") if i < n else tex.get("star_empty")
			st.custom_minimum_size = Vector2(42, 42)
			st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			st.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			h.add_child(st)
		else:
			h.add_child(_mk_label("★", 34, C_GOLD if i < n else Color(0.3, 0.34, 0.42)))
	return h

func _tex_box(frame_name: String, tmargin: int, cmargin: int, mod: Color = Color.WHITE) -> StyleBox:
	# Pixel-art 9-slice frame (falls back to a flat box if the art is missing).
	if tex.get(frame_name):
		var sb := StyleBoxTexture.new()
		sb.texture = tex.get(frame_name)
		sb.modulate_color = mod
		sb.texture_margin_left = tmargin; sb.texture_margin_right = tmargin
		sb.texture_margin_top = tmargin; sb.texture_margin_bottom = tmargin
		sb.content_margin_left = cmargin; sb.content_margin_right = cmargin
		sb.content_margin_top = cmargin; sb.content_margin_bottom = cmargin
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = (mod if mod != Color.WHITE else C_PANEL)
	f.border_color = C_GOLD
	f.set_border_width_all(2)
	f.set_corner_radius_all(8)
	f.set_content_margin_all(max(8, cmargin))
	return f

# =============================================================================
#  Harness hooks
# =============================================================================
func debug_setup(state: String) -> void:
	record_on_win = false
	match state:
		"briefing":
			pass
		"controls":
			_show_controls()
		"play":
			_start_play()
		"result":
			total_energy = 78.0
			_start_play()
			_finish(true)
