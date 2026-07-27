extends Area2D

# ---------------------------------------------------------------------------
# STAR PEDESTAL  (remastered)
# A trophy pedestal the player fills with an earned domain star (press C).
# Placing a star now plays a juicy sequence: ghost preview -> glow flash ->
# pop-in with a bounce + spin -> sparkle burst -> shockwave ring -> idle
# twinkle.  Crisp generated pixel-art star, tinted to the domain colour.
# ---------------------------------------------------------------------------

@export var star_sprite_texture: Texture2D
@export var star_scale: Vector2 = Vector2(0.05, 0.05)
@export var tilemap_node_path: NodePath = NodePath("../TileMap")
@export var tilemap_layer: int = 1
@export var domain: String = "Engineering"

const STAR_TEX  := "res://assets/generated/star_ui/star_full.png"
const GLOW_TEX  := "res://assets/generated/star_ui/glow.png"
const SPARK_TEX := "res://assets/generated/star_ui/sparkle.png"
const RING_TEX  := "res://assets/generated/star_ui/ring.png"
const FONT_PATH := "res://art/Cute_Fantasy_Free2/Outdoor decoration/determination/determination.ttf"

var has_star: bool = false
var player_nearby: bool = false
var state_loaded: bool = false

var star_pos: Vector2 = Vector2.ZERO     # local offset the star rests at
var star_visual: Sprite2D                # the persistent placed star
var glow_visual: Sprite2D                # soft halo behind the star
var hint_root: Node2D                    # floating "press C" + ghost preview
var ghost_star: Sprite2D
var ghost_halo: Sprite2D

var _placed_scale: Vector2 = Vector2(0.5, 0.5)
var _star_color: Color = Color.WHITE
var _animating: bool = false
var _t: float = 0.0


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	star_pos = find_pedestal_tile_position()
	_build_visuals()
	call_deferred("load_star_state")


# ---------------------------------------------------------------- helpers
func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _domain_color() -> Color:
	return StarManager.get_domain_color(domain)


# ---------------------------------------------------------------- build
func _build_visuals():
	var tex := _tex(STAR_TEX)
	if tex:
		_placed_scale = Vector2(0.5, 0.5)        # 40px art -> ~20px trophy
	else:
		tex = star_sprite_texture                # fall back to the scene's texture
		_placed_scale = star_scale

	# soft halo that sits behind the star
	glow_visual = Sprite2D.new()
	glow_visual.texture = _tex(GLOW_TEX)
	glow_visual.position = star_pos
	glow_visual.scale = Vector2(0.55, 0.55)
	glow_visual.z_index = 2
	glow_visual.modulate = Color(1, 1, 1, 0)
	glow_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if glow_visual.texture:
		glow_visual.material = _additive()
	add_child(glow_visual)

	# the trophy star itself
	star_visual = Sprite2D.new()
	star_visual.texture = tex
	star_visual.position = star_pos
	star_visual.scale = _placed_scale
	star_visual.z_index = 3
	star_visual.visible = false
	star_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(star_visual)

	_build_hint(tex)


func _build_hint(star_tex: Texture2D):
	var dc := _domain_color()

	hint_root = Node2D.new()
	hint_root.position = star_pos + Vector2(0, -15)
	hint_root.visible = false
	hint_root.z_index = 7
	add_child(hint_root)

	# glow behind the ghost
	ghost_halo = Sprite2D.new()
	ghost_halo.texture = _tex(GLOW_TEX)
	ghost_halo.position = Vector2(0, -3)
	ghost_halo.scale = Vector2(0.5, 0.5)
	ghost_halo.modulate = Color(dc.r, dc.g, dc.b, 0.3)
	ghost_halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ghost_halo.texture:
		ghost_halo.material = _additive()
	hint_root.add_child(ghost_halo)

	# translucent preview of the star that will land here
	ghost_star = Sprite2D.new()
	ghost_star.texture = star_tex
	ghost_star.position = Vector2(0, -3)
	ghost_star.scale = _placed_scale * 0.92
	ghost_star.modulate = Color(dc.r, dc.g, dc.b, 0.5)
	ghost_star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hint_root.add_child(ghost_star)

	# "PRESS C" prompt — determination font, heavy outline so it always reads
	var lbl := Label.new()
	lbl.text = "PRESS C"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(FONT_PATH):
		var f: Font = load(FONT_PATH)
		lbl.add_theme_font_override("font", f)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.12))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.size = Vector2(64, 12)
	lbl.position = Vector2(-32, 8)
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hint_root.add_child(lbl)


# ---------------------------------------------------------------- per-frame
func _process(delta):
	_t += delta

	# bobbing + breathing ghost prompt
	if hint_root and hint_root.visible:
		hint_root.position.y = star_pos.y - 15 + sin(_t * 3.2) * 1.6
		if ghost_star:
			ghost_star.modulate.a = 0.42 + 0.18 * sin(_t * 4.5)
		if ghost_halo:
			ghost_halo.modulate.a = 0.22 + 0.14 * (0.5 + 0.5 * sin(_t * 4.5))

	# idle twinkle on a placed star
	if has_star and star_visual and star_visual.visible and not _animating:
		var s := 1.0 + 0.045 * sin(_t * 2.6)
		star_visual.scale = _placed_scale * s
		if glow_visual:
			glow_visual.modulate = Color(_star_color.r, _star_color.g, _star_color.b,
				0.20 + 0.16 * (0.5 + 0.5 * sin(_t * 2.6 + 0.7)))

	if Input.is_action_just_pressed("place_star"):
		if player_nearby and not has_star:
			try_place_star()


# ---------------------------------------------------------------- proximity
func _on_body_entered(body):
	if _is_player(body):
		player_nearby = true
		if not has_star:
			show_placement_hint()

func _on_body_exited(body):
	if _is_player(body):
		player_nearby = false
		hide_placement_hint()

func _is_player(body) -> bool:
	return body.is_in_group("player") or body.name.to_lower() == "player" or body.has_method("player")


# ---------------------------------------------------------------- placement
func try_place_star():
	var hub_inv: Inv = load("res://inventory/hub_inventory.tres")
	var matching_slot = null

	for i in range(hub_inv.slots.size()):
		var slot = hub_inv.slots[i]
		if slot.item and slot.item.name == "Star":
			if slot.has_meta("star_domain") and slot.get_meta("star_domain") == domain:
				matching_slot = slot
				break

	if not matching_slot:
		# nothing of this domain to place — give a small "denied" nudge
		_deny_feedback()
		return

	_star_color = matching_slot.get_meta("star_color") if matching_slot.has_meta("star_color") else _domain_color()

	matching_slot.amount -= 1
	if matching_slot.amount <= 0:
		matching_slot.item = null
		matching_slot.amount = 0
		if matching_slot.has_meta("star_color"):
			matching_slot.remove_meta("star_color")
		if matching_slot.has_meta("star_domain"):
			matching_slot.remove_meta("star_domain")

	hub_inv.update.emit()

	has_star = true
	hide_placement_hint()
	animate_placement()
	save_star_state()


# Drives the full place-a-star spectacle.
func animate_placement():
	_animating = true
	var dc := _star_color

	star_visual.modulate = dc
	star_visual.visible = true
	star_visual.scale = Vector2.ZERO
	star_visual.rotation = -0.7
	star_visual.position = star_pos + Vector2(0, -11)

	# glow flash
	glow_visual.modulate = Color(dc.r, dc.g, dc.b, 0.0)
	glow_visual.scale = Vector2(0.18, 0.18)
	var gt := create_tween()
	gt.set_parallel(true)
	gt.tween_property(glow_visual, "modulate:a", 0.95, 0.10)
	gt.tween_property(glow_visual, "scale", Vector2(1.05, 1.05), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gt.set_parallel(false)
	gt.tween_property(glow_visual, "modulate:a", 0.30, 0.45)

	_spawn_ring(dc)
	_spawn_sparkles(dc)

	# the star drops in, overshoots its size, bounces to rest and spins upright
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(star_visual, "scale", _placed_scale, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(star_visual, "position", star_pos, 0.46).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(star_visual, "rotation", 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	star_visual.scale = _placed_scale
	star_visual.rotation = 0.0
	star_visual.position = star_pos
	_animating = false


func _spawn_ring(col: Color):
	var tex := _tex(RING_TEX)
	if not tex:
		return
	var r := Sprite2D.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.position = star_pos
	r.scale = Vector2(0.12, 0.12)
	r.modulate = Color(col.r, col.g, col.b, 0.95)
	r.z_index = 4
	r.material = _additive()
	add_child(r)
	var t := r.create_tween()
	t.set_parallel(true)
	t.tween_property(r, "scale", Vector2(0.95, 0.95), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "modulate:a", 0.0, 0.5)
	t.set_parallel(false)
	t.tween_callback(r.queue_free)


func _spawn_sparkles(col: Color):
	var tex := _tex(SPARK_TEX)
	if not tex:
		return
	var bright := Color((col.r + 1.0) * 0.5, (col.g + 1.0) * 0.5, (col.b + 1.0) * 0.5, 1.0)
	var p := CPUParticles2D.new()
	p.texture = tex
	p.position = star_pos
	p.z_index = 5
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.92
	p.amount = 18
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 34)
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 46.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.05
	p.color = bright
	p.material = _additive()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)


# A quick shake of the ghost prompt when there's no matching star to place.
func _deny_feedback():
	if not hint_root or not hint_root.visible:
		return
	var t := hint_root.create_tween()
	for i in range(3):
		t.tween_property(hint_root, "position:x", star_pos.x + 2.5, 0.04)
		t.tween_property(hint_root, "position:x", star_pos.x - 2.5, 0.04)
	t.tween_property(hint_root, "position:x", star_pos.x, 0.04)


func show_placement_hint():
	if hint_root:
		var dc := _domain_color()
		if ghost_star:
			ghost_star.modulate = Color(dc.r, dc.g, dc.b, 0.5)
		if ghost_halo:
			ghost_halo.modulate = Color(dc.r, dc.g, dc.b, 0.3)
		hint_root.visible = true

func hide_placement_hint():
	if hint_root:
		hint_root.visible = false


# Show an already-earned star with no fanfare (used on scene load).
func show_static_star(col: Color):
	has_star = true
	_star_color = col
	if star_visual:
		star_visual.visible = true
		star_visual.scale = _placed_scale
		star_visual.rotation = 0.0
		star_visual.position = star_pos
		star_visual.modulate = col
	if glow_visual:
		glow_visual.modulate = Color(col.r, col.g, col.b, 0.3)


# Test/debug hook (harness uses it) — place a star with no inventory check.
func debug_force_place(col: Color = Color.WHITE):
	if has_star:
		return
	has_star = true
	_star_color = col if col.a > 0.0 and col != Color.WHITE else _domain_color()
	hide_placement_hint()
	animate_placement()


# ---------------------------------------------------------------- positioning
func find_pedestal_tile_position() -> Vector2:
	var possible_paths = [
		tilemap_node_path,
		NodePath("../../TileMap"),
		NodePath("/root/TileMap"),
		NodePath("../../../TileMap"),
	]

	var tilemap = null
	for path in possible_paths:
		tilemap = get_node_or_null(path)
		if tilemap:
			break

	if not tilemap:
		return Vector2(-1.0, -9.0)

	var tile_set = tilemap.tile_set
	if not tile_set:
		return Vector2(-1.0, -9.0)

	var tilemap_pos = tilemap.to_local(global_position)
	var tile_coords = tilemap.local_to_map(tilemap_pos)
	var upper_tile_coords = tile_coords + Vector2i(0, -1)
	var upper_tile_world_pos = tilemap.map_to_local(upper_tile_coords)
	var upper_tile_local = tilemap.to_local(tilemap.to_global(upper_tile_world_pos))
	var area_local = tilemap.to_local(global_position)
	var star_offset = upper_tile_local - area_local
	star_offset.y += 3

	return star_offset


# ---------------------------------------------------------------- persistence
func save_star_state():
	var scene_name = get_tree().current_scene.name if get_tree().current_scene else "Unknown"
	var pedestal_id = scene_name + "::" + str(name)
	global.mark_pedestal_has_star(pedestal_id, domain, _star_color)


func load_star_state():
	if state_loaded:
		return
	state_loaded = true

	var scene_name = get_tree().current_scene.name if get_tree().current_scene else "Unknown"
	var pedestal_id = scene_name + "::" + str(name)
	var saved_data = global.get_pedestal_star_data(pedestal_id)

	if saved_data and saved_data.get("domain", "") == domain:
		show_static_star(saved_data.get("color", _domain_color()))
	else:
		has_star = false
		if star_visual:
			star_visual.visible = false
