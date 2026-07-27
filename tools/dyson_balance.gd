extends Node
# Balance probe for the Dyson Swarm quest. Runs full missions at high time-scale
# under simple automated policies and reports final energy + stars, so the star
# curve can be tuned against real play (flares + debris included).
# Run: Godot --path . res://tools/dyson_balance.tscn   (windowed; needs the sim to tick)

const QUEST := preload("res://scenes/dyson_swarm.tscn")

const TRIALS := 5

# ring policy (-1 = spread across all rings), whether to shield flares, label
const POLICIES := [
	{"ring": -1, "shield": false, "name": "spread, casual (no shield)"},
	{"ring": -1, "shield": true,  "name": "spread, engaged (shield)"},
	{"ring": 2,  "shield": true,  "name": "outer + shield (skilled)"},
	{"ring": 0,  "shield": false, "name": "inner only (turtle)"},
]

# Choose the ring with the most free capacity (ties -> outer), for spread play.
func _spread_ring(ship) -> int:
	var best := -1
	var best_free := -1
	for r in range(3):
		var free: int = ship.MAX_MIRRORS_PER_RING[r] - ship.ring_mirror_counts[r]
		if free >= best_free:
			best_free = free
			best = r
	return best

func _ready() -> void:
	Engine.time_scale = 8.0
	for p in POLICIES:
		var sum_e := 0
		var min_s := 99
		var max_s := 0
		var stars_list := []
		for trial in range(TRIALS):
			var q = QUEST.instantiate()
			q.record_on_win = false
			q.auto_return_delay = 0.0
			add_child(q)
			await get_tree().process_frame
			await get_tree().process_frame
			q._start_play()

			var guard := 0
			while q.phase != q.Phase.RESULT and guard < 6000:
				guard += 1
				var ship = q.ship
				var r: int = p.ring if p.ring >= 0 else _spread_ring(ship)
				if ship.mirrors_left > 0 and ship.ring_mirror_counts[r] < ship.MAX_MIRRORS_PER_RING[r]:
					ship.selected_ring = r
					ship.drop_mirror()
				# Steer (not teleport) toward a telegraphed flare so placement is not corrupted.
				if p.shield and q._active_flare != null:
					var diff = wrapf(q._active_flare.center - ship.angle, -PI, PI)
					ship.orbit_speed = clamp(diff * 3.0, -ship.MAX_SPEED, ship.MAX_SPEED)
				await get_tree().process_frame

			var st: int = q.get_star_count()
			sum_e += int(round(q.total_energy))
			stars_list.append(st)
			min_s = min(min_s, st)
			max_s = max(max_s, st)
			q.queue_free()
			await get_tree().process_frame

		print("BAL  avg_energy=%d  stars(min..max)=%d..%d  list=%s  | %s" % [
			sum_e / TRIALS, min_s, max_s, str(stars_list), p.name])

	Engine.time_scale = 1.0
	print("BAL_DONE")
	get_tree().quit()
