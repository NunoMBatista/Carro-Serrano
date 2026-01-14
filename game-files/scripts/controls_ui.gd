extends Control

var _controls_visible := false
var _hint_label: Label
var _controls_panel: PanelContainer
var _controls_label: Label

func _ready() -> void:
	# Create hint label (top-left, always visible)
	_hint_label = Label.new()
	_hint_label.text = "Press TAB to check controls"
	_hint_label.position = Vector2(20, 20)

	# Load custom font
	var font = load("res://fonts/SpecialElite-Regular.ttf")
	if font:
		_hint_label.add_theme_font_override("font", font)

	# Style the hint label
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", Color.WHITE)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_label.add_theme_constant_override("outline_size", 4)

	add_child(_hint_label)

	# Create controls panel (top-left, initially hidden)
	_controls_panel = PanelContainer.new()
	_controls_panel.position = Vector2(20, 60)
	_controls_panel.visible = false

	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.8)
	style_box.border_color = Color.WHITE
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	_controls_panel.add_theme_stylebox_override("panel", style_box)

	# Create controls text label
	_controls_label = Label.new()
	_controls_label.text = """CONTROLS:

WASD - Move
SPACE - Jump / Brake
LEFT MOUSE - Interact
RIGHT MOUSE - Leave Screen
L - Turn On/Off Lights
ENTER - Skip Dialogue / Confirm Choice
UP/DOWN ARROWS - Select Dialogue Option
ESC - Toggle Mouse"""

	if font:
		_controls_label.add_theme_font_override("font", font)

	# Style the controls label
	_controls_label.add_theme_font_size_override("font_size", 20)
	_controls_label.add_theme_color_override("font_color", Color.WHITE)
	_controls_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_controls_label.add_theme_constant_override("outline_size", 3)
	_controls_label.add_theme_constant_override("line_spacing", 4)

	# Add padding to the label
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(_controls_label)

	_controls_panel.add_child(margin)
	add_child(_controls_panel)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_controls_visible = not _controls_visible
		_controls_panel.visible = _controls_visible
		get_viewport().set_input_as_handled()
