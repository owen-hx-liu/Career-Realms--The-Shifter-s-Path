extends Control

signal dialogue_finished

@export_file("*.json") var d_file
var dialogue: Array = []
var current_dialogue_id: int = -1
var d_active: bool = false

func _ready():
	$NinePatchRect.visible = false
	set_process_input(true)
	focus_mode = Control.FOCUS_ALL
	print("🟢 DialogueUI ready. Input enabled. File:", d_file)

func set_dialogue_file(path: String):
	d_file = path
	print("📁 Dialogue file set to:", d_file)

func start():
	print("▶️ Starting dialogue with file:", d_file)
	if d_active or d_file == "":
		print("⚠️ Dialogue already active or file missing.")
		return

	dialogue = load_dialogue()
	print("📦 Loaded dialogue:", dialogue)

	if dialogue.is_empty():
		print("❌ Dialogue file failed to load or was empty.")
		return

	current_dialogue_id = -1
	d_active = true
	$NinePatchRect.visible = true
	print("🪟 Dialogue UI made visible.")
	next_script()

func load_dialogue() -> Array:
	var file = FileAccess.open(d_file, FileAccess.READ)
	if file:
		var content = JSON.parse_string(file.get_as_text())
		if typeof(content) == TYPE_ARRAY:
			return content
		else:
			print("❌ Dialogue file is not an array.")
	else:
		print("❌ Failed to open file:", d_file)
	return []

func _unhandled_input(event):
	if d_active and (event.is_action_pressed("ui_accept") or event.is_action_pressed("talk")):
		print("🟢 Dialogue advance input detected.")
		next_script()

func next_script():
	if !d_active:
		print("⚠️ Dialogue not active — skipping.")
		return

	current_dialogue_id += 1
	if current_dialogue_id >= dialogue.size():
		print("✅ Dialogue finished.")
		d_active = false
		$NinePatchRect.visible = false
		emit_signal("dialogue_finished")
		return

	var line = dialogue[current_dialogue_id]
	var name_text = line.get("name", "???")
	var body_text = line.get("text", "")

	print("🗣️ Displaying line:", name_text, "-", body_text)
	$NinePatchRect.get_node("name").text = str(name_text)
	$NinePatchRect.get_node("text").text = str(body_text)
