extends CanvasLayer

@onready var control_node = $Control
@onready var message_label = $Control/MessageLabel
@onready var prompt_label = $Control/PromptLabel

var steps := [
	"URGENT: Extreme weather front approaching. Get inside the BARN immediately!",
	"Warning: Once you enter, the emergency doors will be SEALED for 5 minutes.",
	"The storm has hit. Lockdown is now active. You are trapped until the timer clears.",
	"Your priority: Keep the 6 animals in their safe temperature zones.",
	"If they are unhappy, your score (S) will drop every second.",
	"Use the Weather Board (E) to check the storm intensity outside.",
	"Use the Control Board (E) to toggle vents. If it errors out, fix it in the Control Room.",
	"The lockdown ends in 5 minutes. Protect the animals. Good luck."
]

var current_step := 0
var bar_height := 200.0

func _ready():
	# --- 1. FORCE THE LAYOUT ---
	control_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var screen_width = get_viewport().get_visible_rect().size.x
	message_label.position = Vector2(0, 0)
	message_label.custom_minimum_size = Vector2(screen_width, bar_height)
	message_label.add_theme_font_size_override("font_size", 24)
	
	# --- Setup the Prompt (Bottom Right, Small Text) ---
	prompt_label.text = "Press Space to Continue"
	
	# 1. Give it a much wider minimum width (300 pixels is safe)
	prompt_label.custom_minimum_size = Vector2(300, 40)
	
	# 2. Make sure it doesn't try to wrap or scroll
	if prompt_label is RichTextLabel:
		prompt_label.scroll_active = false
		prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# 3. Align the text to the right side of that 300px box
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	# 4. Position it
	# We move it further left (screen_width - 320) to account for the wider 300px box
	prompt_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	prompt_label.position = Vector2(screen_width - 320, bar_height - 40)
	
	prompt_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)

	# --- 2. CONNECT DRAWING ---
	control_node.draw.connect(_on_control_draw)

	# --- 3. THE "FIRST TIME ONLY" LOGIC ---
	# We check the global variable. If it's true, we hide this entire UI 
	# and do nothing. It won't even show the first line of text.
	if global.has_narrator_been_shown():
		self.visible = false
		# If the quest is already active but the narrator is done, 
		# we don't need to do anything here.
	else:
		show_narrator()

func _input(event):
	if not self.visible: return

	if event.is_action_pressed("place_filter") or event.is_action_pressed("ui_accept"):
		current_step += 1
		if current_step < steps.size():
			update_text()
		else:
			close_narrator()

func _unhandled_input(event):
	# Allow the player to manually see instructions again with 'Q'
	if event.is_action_pressed("reopen_narrator"):
		show_narrator()

func _on_control_draw():
	var screen_width = get_viewport().get_visible_rect().size.x
	var rect = Rect2(0, 0, screen_width, bar_height)
	control_node.draw_rect(rect, Color(0, 0, 0, 0.8), true) 
	control_node.draw_line(Vector2(0, bar_height), Vector2(screen_width, bar_height), Color.WHITE, 2.0)

func show_narrator():
	current_step = 0
	self.visible = true
	update_text()
	control_node.queue_redraw()

func update_text():
	message_label.text = steps[current_step]

func close_narrator():
	self.visible = false
	# This ensures it never "auto-pops" again
	global.mark_narrator_shown() 
	
	# START THE QUEST: Now that they've read the warning, the timer starts
	if not global.quest_active:
		global.start_barn_quest()
