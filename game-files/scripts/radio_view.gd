extends Node
## 2D Radio view overlay with volume, power, and song controls

signal closed

@onready var root: Control = $UILayer/Root
@onready var background: TextureRect = $BackgroundLayer/Background
@onready var hint_label: Label = $UILayer/Root/HintLabel
@onready var song_label: Label = $UILayer/Root/SongLabel
@onready var volume_knob: TextureRect = $UILayer/Root/VolumeKnob
@onready var volume_display: Control = $UILayer/Root/VolumeDisplay
@onready var volume_bar: ColorRect = $UILayer/Root/VolumeDisplay/VolumeBar
@onready var power_button: Button = $UILayer/Root/PowerButton
@onready var next_button: Button = $UILayer/Root/NextButton
@onready var prev_button: Button = $UILayer/Root/PrevButton

var mouse_over_knob: bool = false

func _ready() -> void:
	hint_label.text = "RMB to leave"

	# Setup volume knob from RadioManager state
	_update_knob_rotation(RadioManager.volume)
	_update_volume_bar(RadioManager.volume)

	# Connect knob mouse events for hover detection
	volume_knob.mouse_entered.connect(_on_knob_mouse_entered)
	volume_knob.mouse_exited.connect(_on_knob_mouse_exited)


	# Setup buttons
	power_button.pressed.connect(_on_power_pressed)
	power_button.mouse_entered.connect(Callable(self, "_on_control_mouse_entered"))
	power_button.mouse_exited.connect(Callable(self, "_on_control_mouse_exited"))
	power_button.pressed.connect(Callable(self, "_on_control_pressed"))

	next_button.text = "NEXT"
	next_button.pressed.connect(_on_next_pressed)
	next_button.mouse_entered.connect(Callable(self, "_on_control_mouse_entered"))
	next_button.mouse_exited.connect(Callable(self, "_on_control_mouse_exited"))
	next_button.pressed.connect(Callable(self, "_on_control_pressed"))

	prev_button.text = "PREV"
	prev_button.pressed.connect(_on_prev_pressed)
	prev_button.mouse_entered.connect(Callable(self, "_on_control_mouse_entered"))
	prev_button.mouse_exited.connect(Callable(self, "_on_control_mouse_exited"))
	prev_button.pressed.connect(Callable(self, "_on_control_pressed"))

	_update_display()

	# Ensure background uses its texture native size and is positioned at (0,0)
	#if background and background.texture:
		# don't set Control-specific rect properties (API differences across Godot versions)
		# we'll only read the texture size below for layout calculations

	# Initial layout and connect to viewport resize
	_update_layout()
	var vp = get_viewport()
	if vp:
		vp.size_changed.connect(Callable(self, "_update_layout"))

func _process(_delta: float) -> void:
	_update_song_label()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		elif mouse_over_knob and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Increase volume
			var new_volume = clamp(RadioManager.volume + 0.05, 0.0, 1.0)
			RadioManager.set_volume(new_volume)
			_update_knob_rotation(new_volume)
			_update_volume_bar(new_volume)
		elif mouse_over_knob and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Decrease volume
			var new_volume = clamp(RadioManager.volume - 0.05, 0.0, 1.0)
			RadioManager.set_volume(new_volume)
			_update_knob_rotation(new_volume)
			_update_volume_bar(new_volume)

func _on_knob_mouse_entered() -> void:
	mouse_over_knob = true
	_set_crosshair_hover(true)

func _on_knob_mouse_exited() -> void:
	mouse_over_knob = false
	_set_crosshair_hover(false)

func _update_knob_rotation(volume: float) -> void:
	# Map volume (0-1) to rotation angle
	# Start at -135 degrees (bottom left), end at +135 degrees (bottom right)
	var angle = -135.0 + (volume * 270.0)
	volume_knob.rotation_degrees = angle

func _update_volume_bar(volume: float) -> void:
	# Update the width of the green bar based on volume
	if volume_bar and volume_display:
		var max_width = volume_display.size.x
		volume_bar.size.x = max_width * volume

func _on_control_mouse_entered() -> void:
	_set_crosshair_hover(true)

func _on_control_mouse_exited() -> void:
	_set_crosshair_hover(false)

func _on_control_pressed() -> void:
	_simulate_crosshair_click()

func _on_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_simulate_crosshair_click()

func _set_crosshair_hover(enabled: bool) -> void:
	var cross = _get_crosshair()
	if cross and cross.has_method("set_ui_hovering"):
		cross.set_ui_hovering(enabled)

func _simulate_crosshair_click() -> void:
	var cross = _get_crosshair()
	if cross and cross.has_method("simulate_click"):
		cross.simulate_click()

func _get_crosshair():
	var scene = get_tree().get_current_scene()
	if not scene:
		return null
	if scene.has_node("Player/Control/CrossHair"):
		return scene.get_node("Player/Control/CrossHair")
	return _find_node(scene, "CrossHair")

func _find_node(node: Node, target_name: String) -> Node:
	if not node:
		return null
	if str(node.name) == target_name:
		return node
	for child in node.get_children():
		if child and child is Node:
			var res = _find_node(child, target_name)
			if res:
				return res
	return null


func _on_power_pressed() -> void:
	RadioManager.toggle_power()
	_update_display()

func _on_next_pressed() -> void:
	RadioManager.next_song()
	_update_song_label()

func _on_prev_pressed() -> void:
	RadioManager.prev_song()
	_update_song_label()

func _update_display() -> void:
	if RadioManager.is_on:
		power_button.text = "POWER [ON]"
	else:
		power_button.text = "POWER [OFF]"
	_update_song_label()

func _update_song_label() -> void:
	song_label.text = RadioManager.get_current_song_name()


func _update_layout() -> void:
	if not background or not background.texture:
		return

	var vsize: Vector2 = get_viewport().get_visible_rect().size
	var tex_size: Vector2 = background.texture.get_size()

	# weakest-link fit: scale so the full texture fits inside the viewport
	var uniform_scale = max(vsize.x / tex_size.x, vsize.y / tex_size.y)

	# Apply uniform scale to the root control so all children scale together
	root.scale = Vector2(uniform_scale, uniform_scale)

	# Center the scaled content in the viewport (using position)
	root.position = (vsize - tex_size * uniform_scale) / 2.0

	# Also position and scale the background (on its own CanvasLayer) so it visually
	# matches the UI root. Use CanvasItem properties to avoid Control-specific APIs.
	if background:
		background.scale = Vector2(uniform_scale, uniform_scale)
		background.position = (vsize - tex_size * uniform_scale) / 2.0

func close() -> void:
	closed.emit()
	queue_free()
