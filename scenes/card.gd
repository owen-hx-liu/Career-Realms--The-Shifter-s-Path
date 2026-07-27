extends Panel

# Pixel-art battle card. Frames, portraits and stat icons are loaded from the
# generated atlas in assets/generated/immune/ (see tools/make_immune.py).
const ART := "res://assets/generated/immune/"

@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var portrait_holder: Panel = $Margin/VBox/PortraitHolder
@onready var portrait: TextureRect = $Margin/VBox/PortraitHolder/Portrait
@onready var type_label: Label = $Margin/VBox/TypeLabel
@onready var stats_row: HBoxContainer = $Margin/VBox/StatsRow
@onready var hp_icon: TextureRect = $Margin/VBox/StatsRow/HPIcon
@onready var hp_label: Label = $Margin/VBox/StatsRow/HPLabel
@onready var atk_icon: TextureRect = $Margin/VBox/StatsRow/ATKIcon
@onready var attack_label: Label = $Margin/VBox/StatsRow/AttackLabel
@onready var ability_label: Label = $Margin/VBox/AbilityLabel
@onready var selected_mark: TextureRect = $SelectedMark

var card_data: Dictionary
var is_pathogen: bool = false
var is_selected: bool = false
var is_clickable: bool = true
var compact: bool = false

signal card_clicked(card)

# Palette (consistent with the immune-quest art)
const COL_IMMUNE_TEXT := Color("cfeaf7")
const COL_PATHOGEN_TEXT := Color("f4c6cf")
const COL_TYPE := Color("8fa6b4")
const COL_ABILITY_IMMUNE := Color("a9e7d2")
const COL_ABILITY_PATHO := Color("e8a08c")
const COL_HP := Color("ff8a96")
const COL_ATK := Color("ffd88a")

var _tex := {}
var _base_pos_y := 0.0
var _hover_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for n in ["frame_immune", "frame_pathogen", "frame_slot", "icon_hp", "icon_atk", "badge_good"]:
		var p: String = ART + n + ".png"
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
	# crisp pixels everywhere on the card
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if portrait:
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if hp_icon:
		hp_icon.texture = _tex.get("icon_hp")
	if atk_icon:
		atk_icon.texture = _tex.get("icon_atk")
	if selected_mark:
		selected_mark.texture = _tex.get("badge_good")
	if portrait_holder:
		portrait_holder.add_theme_stylebox_override("panel", _frame_box("frame_slot", 4, 2))
	hp_label.add_theme_color_override("font_color", COL_HP)
	attack_label.add_theme_color_override("font_color", COL_ATK)
	type_label.add_theme_color_override("font_color", COL_TYPE)


func _load_portrait(id: String) -> void:
	var p: String = ART + id + ".png"
	if portrait and ResourceLoader.exists(p):
		portrait.texture = load(p)


func setup_pathogen(data: Dictionary) -> void:
	card_data = data
	is_pathogen = true
	is_clickable = false
	name_label.text = data.name
	name_label.add_theme_color_override("font_color", COL_PATHOGEN_TEXT)
	type_label.text = str(data.type).to_upper()
	hp_label.text = str(data.hp)
	attack_label.text = str(data.attack)
	ability_label.text = "Weak to: " + str(data.get("weakness", "?"))
	ability_label.add_theme_color_override("font_color", COL_ABILITY_PATHO)
	tooltip_text = str(data.get("fact", ""))
	_load_portrait(str(data.get("id", "")))
	add_theme_stylebox_override("panel", _frame_box("frame_pathogen"))
	_apply_compact()


func setup_immune(data: Dictionary) -> void:
	card_data = data
	is_pathogen = false
	is_clickable = true
	name_label.text = data.name
	name_label.add_theme_color_override("font_color", COL_IMMUNE_TEXT)
	type_label.text = str(data.type).to_upper()
	hp_label.text = str(data.hp)
	attack_label.text = str(data.attack)
	ability_label.text = str(data.get("ability", ""))
	ability_label.add_theme_color_override("font_color", COL_ABILITY_IMMUNE)
	tooltip_text = str(data.get("fact", ""))
	_load_portrait(str(data.get("id", "")))
	add_theme_stylebox_override("panel", _frame_box("frame_immune"))
	_apply_compact()


func set_compact(value: bool) -> void:
	compact = value
	if is_inside_tree():
		_apply_compact()


func _apply_compact() -> void:
	# drafted-team cards are smaller: drop the flavour rows, shrink the portrait
	if not is_node_ready():
		return
	ability_label.visible = not compact
	type_label.visible = not compact
	if compact:
		custom_minimum_size = Vector2(118, 150)
		portrait_holder.custom_minimum_size = Vector2(0, 52)
		name_label.add_theme_font_size_override("font_size", 11)
	else:
		custom_minimum_size = Vector2(156, 212)
		portrait_holder.custom_minimum_size = Vector2(0, 66)
		name_label.add_theme_font_size_override("font_size", 13)


func set_selected(selected: bool) -> void:
	is_selected = selected
	is_clickable = not (selected and not is_pathogen)
	if selected_mark:
		selected_mark.visible = selected and not is_pathogen
	if selected:
		modulate = Color(0.62, 0.66, 0.7, 1.0)
	else:
		modulate = Color(1, 1, 1, 1)
		_set_frame_mod(Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_clickable and not is_pathogen and not is_selected:
			card_clicked.emit(self)


func _mouse_enter() -> void:
	if is_pathogen or is_selected:
		return
	_set_frame_mod(Color(1.18, 1.18, 1.18))
	_lift(-6.0)


func _mouse_exit() -> void:
	if is_pathogen or is_selected:
		return
	_set_frame_mod(Color.WHITE)
	_lift(0.0)


func _lift(dy: float) -> void:
	if _base_pos_y == 0.0 and position.y != 0.0:
		_base_pos_y = position.y
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "position:y", _base_pos_y + dy, 0.12)


func _set_frame_mod(c: Color) -> void:
	var sb := get_theme_stylebox("panel")
	if sb is StyleBoxTexture:
		sb.modulate_color = c


# 9-slice pixel frame (falls back to a flat box if the art is missing)
func _frame_box(frame_name: String, content_margin: int = 0, tmargin: int = 6) -> StyleBox:
	var tex: Texture2D = _tex.get(frame_name)
	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = tmargin
		sb.texture_margin_top = tmargin
		sb.texture_margin_right = tmargin
		sb.texture_margin_bottom = tmargin
		sb.content_margin_left = content_margin
		sb.content_margin_right = content_margin
		sb.content_margin_top = content_margin
		sb.content_margin_bottom = content_margin
		return sb
	var f := StyleBoxFlat.new()
	f.bg_color = Color("122231") if not is_pathogen else Color("261320")
	f.border_color = Color("3f8cc0") if not is_pathogen else Color("b5476a")
	f.set_border_width_all(2)
	return f
