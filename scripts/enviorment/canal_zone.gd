extends Area2D

# CanalZone.gd - placement target shown on the tile under the player.
# Draws a clean, pulsing "buildable here" highlight (replaces the old stretched
# button sprite). The on-tile "Press C" text hint has been removed.

signal build_requested(tile_position: Vector2i)
signal canal_built_signal(tile_position: Vector2i)

@export var canal_built := false
@export var tile_position := Vector2i.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label

var active := false
var player_in_zone := false
var tile_size := Vector2(16, 16)
var tilemap_ref: TileMap = null
var _pulse: float = 0.0

const FILL := Color(0.25, 0.80, 1.0, 1.0)
const EDGE := Color(0.75, 0.97, 1.0, 1.0)


func _ready() -> void:
	z_index = 5
	_apply_visuals()
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_body_exited")):
		connect("body_exited", Callable(self, "_on_body_exited"))


func set_tilemap_reference(tm: TileMap) -> void:
	if tm == null:
		return
	tilemap_ref = tm
	if tilemap_ref.tile_set:
		tile_size = tilemap_ref.tile_set.tile_size
	_apply_visuals()
	queue_redraw()


func _apply_visuals() -> void:
	if sprite:
		sprite.visible = false  # highlight is drawn in _draw() now
	if collision and collision.shape:
		var s = collision.shape
		if s is RectangleShape2D:
			s.size = tile_size
		collision.position = Vector2.ZERO
		collision.disabled = true
	if label:
		# On-tile "Press C" hint removed — keep the label permanently hidden.
		label.visible = false
		label.text = ""


func _draw() -> void:
	if not active:
		return
	var h := tile_size * 0.5
	var p := 0.5 + 0.5 * sin(_pulse * 4.0)  # 0..1
	# soft fill
	var fill := FILL
	fill.a = 0.14 + 0.12 * p
	draw_rect(Rect2(-h, tile_size), fill, true)
	# pulsing border
	var edge := EDGE
	edge.a = 0.6 + 0.4 * p
	draw_rect(Rect2(-h, tile_size), edge, false, 1.0)
	# corner ticks
	var t := h.x * 0.45
	var corners := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(-h.x, h.y), Vector2(h.x, h.y)]
	var sx := [1, -1, 1, -1]
	var sy := [1, 1, -1, -1]
	for i in range(4):
		var c: Vector2 = corners[i]
		draw_line(c, c + Vector2(t * sx[i], 0), edge, 1.5)
		draw_line(c, c + Vector2(0, t * sy[i]), edge, 1.5)


func _process(delta: float) -> void:
	if active:
		_pulse += delta
		queue_redraw()
		if player_in_zone and not canal_built and Input.is_action_just_pressed("build_canal"):
			emit_signal("build_requested", tile_position)


func activate_zone() -> void:
	active = true
	visible = true
	if collision:
		collision.disabled = false
	queue_redraw()


func deactivate_zone() -> void:
	active = false
	visible = false
	if label:
		label.visible = false
	if collision:
		collision.disabled = true
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if _is_player(body) and not canal_built:
		player_in_zone = true


func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		player_in_zone = false
		if label:
			label.visible = false


func _is_player(body: Node) -> bool:
	if body == null:
		return false
	if body.name == "Player":
		return true
	return body.has_method("is_in_group") and body.is_in_group("Player")


func force_build() -> void:
	if canal_built:
		return
	canal_built = true
	if label:
		label.visible = false
	if collision:
		collision.disabled = true
	deactivate_zone()
	emit_signal("canal_built_signal", tile_position)
