extends Area2D
# Player-controlled collector ship. Orbits outside the rings; the player steers
# its orbit speed to line up with sectors, picks a target ring, and deploys
# collector mirrors from a limited, slowly-regenerating reserve.

@export var orbit_radius: float = 320.0
@export var orbit_speed: float = 1.0

var angle: float = 0.0
var selected_ring: int = 0
const MIN_SPEED: float = 0.3
const MAX_SPEED: float = 3.0
var health: int = 3
var is_invincible: bool = false

const RING_RADII = [100, 175, 250]
const MAX_MIRRORS_PER_RING = [4, 6, 8]   # ring 1 / 2 / 3 capacity
var ring_mirror_counts = [0, 0, 0]

# --- Mirror economy (set by the quest controller for difficulty) ---
var active: bool = false                 # gameplay only runs once the mission starts
var mirrors_left: int = 10               # current reserve
var mirror_reserve_cap: int = 999999     # effectively no limit on what you can hold
var regen_interval: float = 4.0          # seconds between reserve regenerations
var regen_amount: int = 2                # mirrors granted each regeneration
var mirror_lifetime: float = 20.0        # lifetime handed to each deployed mirror
var _regen_timer: float = 0.0

var scene = preload("res://scenes/dyson_mirror.tscn")

func _ready():
	add_to_group("ship")
	area_entered.connect(_on_area_entered)

func _process(delta):
	if not active:
		return

	# Steer orbit speed.
	if Input.is_action_pressed("ui_right"):
		orbit_speed = min(orbit_speed + 0.05, MAX_SPEED)
	if Input.is_action_pressed("ui_left"):
		orbit_speed = max(orbit_speed - 0.05, MIN_SPEED)

	angle += orbit_speed * delta
	position = Vector2(cos(angle), sin(angle)) * orbit_radius
	rotation = angle + PI / 2

	# Pick a target ring.
	if Input.is_action_just_pressed("ui_1"):
		selected_ring = 0
	if Input.is_action_just_pressed("ui_2"):
		selected_ring = 1
	if Input.is_action_just_pressed("ui_3"):
		selected_ring = 2

	# Regenerate the reserve up to the cap.
	if mirrors_left < mirror_reserve_cap:
		_regen_timer += delta
		if _regen_timer >= regen_interval:
			_regen_timer -= regen_interval
			mirrors_left = min(mirrors_left + regen_amount, mirror_reserve_cap)
	else:
		_regen_timer = 0.0

	# Deploy a mirror onto the selected ring.
	if Input.is_action_just_pressed("ui_drop"):
		drop_mirror()

# Returns true if a mirror was actually deployed. Self-guards so the reserve can
# never go negative and a ring can never exceed its capacity.
func drop_mirror() -> bool:
	if mirrors_left <= 0:
		return false
	if ring_mirror_counts[selected_ring] >= MAX_MIRRORS_PER_RING[selected_ring]:
		return false
	var mirror = scene.instantiate()
	mirror.orbit_radius = RING_RADII[selected_ring]
	mirror.orbit_angle = angle
	mirror.orbit_speed = 0.3
	mirror.ring_index = selected_ring
	mirror.lifetime = mirror_lifetime
	mirror.is_placed = true
	mirror.position = Vector2(cos(angle), sin(angle)) * RING_RADII[selected_ring]
	get_parent().add_child(mirror)
	mirrors_left -= 1
	ring_mirror_counts[selected_ring] += 1
	return true

func on_mirror_destroyed(index: int):
	ring_mirror_counts[index] = max(0, ring_mirror_counts[index] - 1)

# --- Flare shielding -----------------------------------------------------
# True when the ship's current orbital angle sits inside the given sector.
func angle_in_sector(center_angle: float, half_width: float) -> bool:
	var d = abs(fmod(angle - center_angle + PI, TAU) - PI)
	return d <= half_width

func flash_shield():
	var tw = create_tween()
	modulate = Color(0.5, 0.9, 1.0)
	tw.tween_property(self, "modulate", Color(1, 1, 1), 0.45)

# --- Damage --------------------------------------------------------------
func _on_area_entered(area):
	if area.is_in_group("debris") and not is_invincible:
		take_damage()

func take_damage():
	health -= 1
	is_invincible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.3, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.tween_property(self, "modulate:a", 0.3, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	await tween.finished
	is_invincible = false

	if health <= 0:
		var dyson = get_parent()
		if dyson and dyson.has_method("on_ship_destroyed"):
			dyson.on_ship_destroyed()
