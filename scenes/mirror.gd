extends Area2D
# Orbital collector mirror for the Dyson Swarm quest.
# A placed mirror orbits the star, loses efficiency as it ages, and finally
# burns out (freeing its ring slot) so the player must keep refreshing the
# swarm rather than placing everything once and idling.

var orbit_radius: float = 0.0
var orbit_angle: float = 0.0
var orbit_speed: float = 0.5
var is_placed: bool = false
var ring_index: int = 0          # which ring this mirror belongs to (0..2)

var age: float = 0.0
var lifetime: float = 20.0       # seconds before the mirror burns out
const EFF_FLOOR := 0.30          # efficiency never collects below this until burnout
var efficiency: float = 1.0      # 1.0 (fresh) -> EFF_FLOOR (old); read by the collector

var _expired := false            # guard so burnout only fires once

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("mirror")

func _process(delta):
	if not is_placed:
		return

	# Orbit the star.
	orbit_angle += orbit_speed * delta
	position = Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	rotation = orbit_angle + PI * 1.25

	# Age + efficiency falloff.
	age += delta
	var t: float = clamp(age / lifetime, 0.0, 1.0)
	efficiency = lerp(1.0, EFF_FLOOR, t)

	# Visual feedback: bright + cyan when fresh, dim + red when spent. Blink
	# in the final stretch so the player knows to replace it.
	var warn := t > 0.78
	var blink := 1.0
	if warn:
		blink = 0.55 + 0.45 * sin(age * 14.0)
	modulate = Color(1.0, 0.55 + 0.45 * efficiency, 0.35 + 0.45 * efficiency, blink)

	# Burn out and free the ring slot.
	if age >= lifetime and not _expired:
		_expired = true
		queue_free()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if not is_inside_tree():
			return
		var tree = get_tree()
		if tree == null:
			return
		var ship = tree.get_first_node_in_group("ship")
		if ship and ship.has_method("on_mirror_destroyed"):
			ship.on_mirror_destroyed(ring_index)
