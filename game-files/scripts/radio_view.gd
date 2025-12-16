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
	
	# Setup buttons
	power_button.pressed.connect(_on_power_pressed)
	next_button.text = "NEXT"
	next_button.pressed.connect(_on_next_pressed)
	prev_button.text = "PREV"
	prev_button.pressed.connect(_on_prev_pressed)
	
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
