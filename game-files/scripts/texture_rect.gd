extends TextureRect


func _ready():
	update_position()

func _process(_delta):
	update_position()

func update_position():
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var screen_size = get_viewport().get_visible_rect().size
		position = (screen_size) / 2
	else:
		position = get_viewport().get_mouse_position()
	
