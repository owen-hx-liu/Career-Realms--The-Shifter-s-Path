extends Node
# Headless functional test for the reworked Dyson Swarm quest.
# Run: Godot --headless --path . res://tools/dyson_check.tscn
# Verifies phases, the mirror economy, efficiency-weighted energy, star tiers,
# flare shielding, and that completion records stars to the managers.

const QUEST := preload("res://scenes/dyson_swarm.tscn")
var _pass := 0
var _fail := 0

func _ok(label: String, cond: bool) -> void:
	if cond: _pass += 1
	else: _fail += 1
	print(("PASS " if cond else "FAIL "), label)

func _ready() -> void:
	# ---- Phase gating ----
	var q = QUEST.instantiate()
	q.record_on_win = false
	q.auto_return_delay = 0.0
	add_child(q)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok("starts in BRIEFING", q.phase == q.Phase.BRIEFING)
	_ok("ship inactive during briefing", q.ship.active == false)

	q._start_play()
	_ok("PLAY after _start_play", q.phase == q.Phase.PLAY)
	_ok("ship active in PLAY", q.ship.active == true)

	# ---- Mirror economy + placement ----
	var ship = q.ship
	var start_left: int = ship.mirrors_left
	ship.selected_ring = 2
	var before = ship.ring_mirror_counts[2]
	ship.angle = 0.0
	ship.drop_mirror()
	_ok("deploy decrements reserve", ship.mirrors_left == start_left - 1)
	_ok("deploy increments ring count", ship.ring_mirror_counts[2] == before + 1)
	await get_tree().process_frame
	_ok("placed mirror joins group", get_tree().get_nodes_in_group("mirror").size() >= 1)

	# ---- Efficiency actually drives energy ----
	var m = get_tree().get_nodes_in_group("mirror")[0]
	q.total_energy = 0.0
	m.efficiency = 1.0
	q._collect_energy(1.0)
	var e_full = q.total_energy
	q.total_energy = 0.0
	m.efficiency = 0.3
	q._collect_energy(1.0)
	var e_old = q.total_energy
	print("energy fresh=", e_full, " aged=", e_old)
	_ok("fresh mirror out-collects aged mirror", e_full > e_old and e_old > 0.0)

	# ---- Star thresholds (new curve) ----
	var checks := {92: 5, 72: 4, 52: 3, 32: 2, 10: 1}
	for e in checks:
		q.total_energy = float(e)
		_ok("stars@%d == %d" % [e, checks[e]], q.get_star_count() == checks[e])

	# ---- Flare shield geometry ----
	ship.angle = 1.0
	_ok("ship shields its own sector", ship.angle_in_sector(1.0, 0.5))
	_ok("ship does not shield far sector", not ship.angle_in_sector(1.0 + PI, 0.5))

	# ---- Completion records to managers ----
	var q2 = QUEST.instantiate()
	q2.record_on_win = true
	q2.auto_return_delay = 0.0
	add_child(q2)
	await get_tree().process_frame
	await get_tree().process_frame
	q2._start_play()
	q2.total_energy = 78.0
	q2._finish(true)
	await get_tree().process_frame
	_ok("RESULT phase after finish", q2.phase == q2.Phase.RESULT)
	_ok("global.dyson_stars set to 4", global.dyson_stars == 4)
	var sm = get_node_or_null("/root/StarManager")
	_ok("StarManager recorded 4 stars", sm != null and int(sm.get_quest_stars("engineering_quest_2")) == 4)
	var em = get_node_or_null("/root/EndingManager")
	_ok("EndingManager marks quest complete", em != null and em.is_quest_completed("engineering_quest_2", "Engineering"))

	# ---- Failure caps the reward ----
	var q3 = QUEST.instantiate()
	q3.record_on_win = false
	q3.auto_return_delay = 0.0
	add_child(q3)
	await get_tree().process_frame
	await get_tree().process_frame
	q3._start_play()
	q3.total_energy = 92.0    # would be 5 stars on success
	q3._finish(false)
	_ok("losing the ship caps stars at 2", global.dyson_stars == 2)

	print("DYSON_CHECK_DONE pass=%d fail=%d" % [_pass, _fail])
	get_tree().quit()
