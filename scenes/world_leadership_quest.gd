extends Node2D

@export var quest_id: String = "leadership_quest_1"
@export var domain: String = "Leadership"
@export var return_scene: String = "res://scenes/maps/LeadershipHouse.tscn"
@export var exit_x_threshold: float = 380.0
@export var auto_return_delay: float = 1.8

var quest_started_ms: int = 0
var quest_finished: bool = false

@onready var player: Node2D = get_node_or_null("player")
@onready var tracker: Node = get_node_or_null("NPCTracker")

func _ready() -> void:
	quest_started_ms = Time.get_ticks_msec()
	print("[LeadershipWorldQuest] Started. Reach the right-side exit to complete.")

func _process(_delta: float) -> void:
	if quest_finished or player == null:
		return

	if player.global_position.x >= exit_x_threshold:
		_complete_quest()

func _complete_quest() -> void:
	if quest_finished:
		return
	quest_finished = true

	var survivors: int = 0
	if tracker and tracker.has_method("get_alive_count"):
		survivors = int(tracker.get_alive_count())

	var elapsed_seconds: float = maxf(0.0, float(Time.get_ticks_msec() - quest_started_ms) / 1000.0)
	var stars_earned: int = _calculate_stars(survivors, elapsed_seconds)

	# Never overwrite a better previous run.
	var best_stars: int = maxi(stars_earned, int(StarManager.get_quest_stars(quest_id)))

	StarManager.record_quest_stars(quest_id, domain, best_stars, 5)
	EndingManager.complete_quest(quest_id, domain, best_stars)

	if DomainInteractionManager:
		var bonuses = DomainInteractionManager.get_bonuses_for_domain(domain)
		LegacyAchievementManager.check_cross_domain_achievements(bonuses.size())
	LegacyAchievementManager.check_star_achievements()
	LegacyAchievementManager.check_speed_achievements()

	print("[LeadershipWorldQuest] Completed | survivors=", survivors, " elapsed=", elapsed_seconds, "s stars=", stars_earned, " best=", best_stars)

	await get_tree().create_timer(auto_return_delay).timeout
	get_tree().change_scene_to_file(return_scene)

func _calculate_stars(survivors: int, elapsed_seconds: float) -> int:
	if survivors <= 0:
		return 0

	var stars: int = 2  # At least one survivor makes progress.
	if survivors >= 2:
		stars = 3
	if survivors >= 3:
		stars = 4

	if elapsed_seconds <= 90.0:
		stars += 1
	elif elapsed_seconds >= 240.0:
		stars -= 1

	return clampi(stars, 0, 5)
