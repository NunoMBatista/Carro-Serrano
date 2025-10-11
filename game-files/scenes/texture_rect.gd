extends TextureRect


func _ready():
	update_position()

func _process(_delta):
	update_position()

func update_position():
	var screen_size = get_viewport().get_visible_rect().size
	position = (screen_size) / 2
	
