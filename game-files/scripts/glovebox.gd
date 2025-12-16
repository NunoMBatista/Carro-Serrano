extends StaticBody3D
## Clickable glovebox that opens a 2D view when interacted with

const GLOVEBOX_VIEW = preload("res://scenes/glovebox_view.tscn")
const GLOVEBOX_SFX = preload("res://assets/audio/sfx/glove_box_sfx.mp3")

var _view_open: bool = false
var _audio_player: AudioStreamPlayer

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = GLOVEBOX_SFX
	_audio_player.bus = "Master"
	add_child(_audio_player)

func interact() -> void:
	if _view_open:
		return
	
	_view_open = true
	_audio_player.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var view = GLOVEBOX_VIEW.instantiate()
	get_tree().root.add_child(view)
	view.closed.connect(_on_view_closed)

func _on_view_closed() -> void:
	_view_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
