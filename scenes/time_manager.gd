extends Node

@export var time_limit: float = 360.0  # 6 minutes in seconds
@export var quest_id: String = "leadership_quest_2"
@export var domain: String = "Leadership"
var time_remaining: float = 360.0
var is_running: bool = false

@onready var timer_label = get_node("../UILayer/TimerPanel/TimerLabel")

func _ready():
	print("TimerManager ready")
	print("Timer label exists: ", timer_label != null)
	
	if timer_label:
		print("Timer label visible: ", timer_label.visible)
		print("Timer label position: ", timer_label.global_position)
		
		# Check parent visibility
		var ui_layer = get_node("../UILayer")
		print("UILayer visible: ", ui_layer.visible if ui_layer else "UILayer not found")
		
		var timer_panel = get_node("../UILayer/TimerPanel")
		print("TimerPanel visible: ", timer_panel.visible if timer_panel else "TimerPanel not found")
		
	print("TimerManager ready")
	
	# Force timer to top-right corner
	var timer_panel = get_node("../UILayer/TimerPanel")
	if timer_panel:
		timer_panel.position = Vector2(1050, 50)  # Top-right area
	
	time_remaining = time_limit
	update_display()
	await get_tree().create_timer(0.5).timeout
	start_timer()

func start_timer():
	is_running = true
	print("Mission timer started: ", time_limit, " seconds")

func _process(delta):
	if is_running:
		time_remaining -= delta
		
		if time_remaining <= 0:
			time_remaining = 0
			time_up()
		
		update_display()

func update_display():
	if timer_label:
		var minutes = int(time_remaining / 60)
		var seconds = int(time_remaining) % 60
		
		var time_text = "TIME\n%d:%02d" % [minutes, seconds]
		timer_label.text = time_text
		
		# Change color when time is low
		if time_remaining <= 60:
			timer_label.add_theme_color_override("font_color", Color.RED)
		elif time_remaining <= 120:
			timer_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			timer_label.add_theme_color_override("font_color", Color.WHITE)

func time_up():
	is_running = false
	print("TIME'S UP!")
	show_results()
	

func show_results():
	# Get final score
	var score_mgr = get_node("../ScoreManager")
	var final_score = score_mgr.total_points if score_mgr else 0
	var completed = score_mgr.completed_locations if score_mgr else 0
	
	# SAVE TO MISSIONDATA BEFORE CHANGING SCENE
	MissionData.set_results(final_score, completed)
	_save_quest_results(MissionData.get_stars())
	print("Mission complete! Saving results: ", final_score, " points, ", completed, " tasks")
	
	# Return to original map (change this to your main map scene name)
	get_tree().change_scene_to_file("res://scenes/World2.tscn")

func _save_quest_results(stars_earned: int) -> void:
	var best_stars: int = maxi(stars_earned, int(StarManager.get_quest_stars(quest_id)))
	StarManager.record_quest_stars(quest_id, domain, best_stars, 5)
	EndingManager.complete_quest(quest_id, domain, best_stars)
	
	if DomainInteractionManager:
		var bonuses = DomainInteractionManager.get_bonuses_for_domain(domain)
		LegacyAchievementManager.check_cross_domain_achievements(bonuses.size())
	LegacyAchievementManager.check_star_achievements()
	LegacyAchievementManager.check_speed_achievements()
	
	print("[MapViewQuest] Saved stars for ", quest_id, ": earned=", stars_earned, " best=", best_stars)
