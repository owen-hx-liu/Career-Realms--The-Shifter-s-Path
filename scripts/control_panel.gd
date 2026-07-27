extends Control

# --- DRAG YOUR BUTTONS HERE IN THE INSPECTOR ---
@export_group("Fan 1")
@export var f1_heat: Button
@export var f1_cool: Button
@export var f1_off: Button

@export_group("Fan 2")
@export var f2_heat: Button
@export var f2_cool: Button
@export var f2_off: Button

@export_group("Fan 3")
@export var f3_heat: Button
@export var f3_cool: Button
@export var f3_off: Button

func _ready():
	visible = false
	
	# --- CONNECT FAN 1 ---
	f1_heat.pressed.connect(func(): _set_fan(0, 1))
	f1_cool.pressed.connect(func(): _set_fan(0, -1))
	f1_off.pressed.connect(func(): _set_fan(0, 0))

	# --- CONNECT FAN 2 ---
	f2_heat.pressed.connect(func(): _set_fan(1, 1))
	f2_cool.pressed.connect(func(): _set_fan(1, -1))
	f2_off.pressed.connect(func(): _set_fan(1, 0))

	# --- CONNECT FAN 3 ---
	f3_heat.pressed.connect(func(): _set_fan(2, 1))
	f3_cool.pressed.connect(func(): _set_fan(2, -1))
	f3_off.pressed.connect(func(): _set_fan(2, 0))
	
	# Set initial colors
	_update_ui_visuals()

func toggle():
	visible = !visible
	if visible:
		_update_ui_visuals() # Refresh colors when opening

func _set_fan(fan_index: int, state: int):
	# Update the global data
	global.fan_states[fan_index] = state
	print("Fan ", fan_index + 1, " set to ", state)
	
	# Update the button colors immediately
	_update_ui_visuals()

func _update_ui_visuals():
	# Helper function to color a set of 3 buttons based on state
	# State: 1=Heat, -1=Cool, 0=Off
	_color_buttons(global.fan_states[0], f1_heat, f1_cool, f1_off)
	_color_buttons(global.fan_states[1], f2_heat, f2_cool, f2_off)
	_color_buttons(global.fan_states[2], f3_heat, f3_cool, f3_off)

func _color_buttons(state, btn_heat, btn_cool, btn_off):
	# Reset all to gray first
	btn_heat.modulate = Color(1, 1, 1) # White/Normal
	btn_cool.modulate = Color(1, 1, 1)
	btn_off.modulate = Color(1, 1, 1)
	
	# Highlight the active one
	if state == 1:
		btn_heat.modulate = Color(1, 0, 0) # Red
	elif state == -1:
		btn_cool.modulate = Color(0, 0.5, 1) # Blue
	else:
		btn_off.modulate = Color(0.5, 0.5, 0.5) # Dark Gray (Off)
