extends StaticBody3D
## Clickable glovebox that opens a 2D view when interacted with

const GLOVEBOX_VIEW = preload("res://scenes/glovebox_view.tscn")

var _view_open: bool = false

func interact() -> void:
	if _view_open:
		return
	
	_view_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var view = GLOVEBOX_VIEW.instantiate()
	get_tree().root.add_child(view)
	view.closed.connect(_on_view_closed)

func _on_view_closed() -> void:
	_view_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
