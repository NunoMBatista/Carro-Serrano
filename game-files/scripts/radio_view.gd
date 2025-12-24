extends CanvasLayer
## 2D Radio view overlay with volume, power, and song controls

signal closed

@onready var background: TextureRect = $Background
@onready var hint_label: Label = $HintLabel
@onready var song_label: Label = $SongLabel
@onready var volume_slider: VSlider = $VolumeSlider
@onready var power_button: Button = $PowerButton
@onready var next_button: Button = $NextButton
@onready var prev_button: Button = $PrevButton

func _ready() -> void:
	hint_label.text = "RMB to leave"

	# Setup volume slider from RadioManager state
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = RadioManager.volume
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.mouse_entered.connect(Callable(self, "_on_control_mouse_entered"))
	volume_slider.mouse_exited.connect(Callable(self, "_on_control_mouse_exited"))


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

func _process(_delta: float) -> void:
	_update_song_label()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _is_mouse_over_slider():
				volume_slider.value = min(volume_slider.value + 0.05, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _is_mouse_over_slider():
				volume_slider.value = max(volume_slider.value - 0.05, 0.0)

func _is_mouse_over_slider() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	var slider_rect = volume_slider.get_global_rect()
	return slider_rect.has_point(mouse_pos)

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

func _find_node(root: Node, name: String) -> Node:
	if not root:
		return null
	if str(root.name) == name:
		return root
	for child in root.get_children():
		if child and child is Node:
			var res = _find_node(child, name)
			if res:
				return res
	return null
func _on_volume_changed(value: float) -> void:
	RadioManager.set_volume(value)

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

func close() -> void:
	closed.emit()
	queue_free()
