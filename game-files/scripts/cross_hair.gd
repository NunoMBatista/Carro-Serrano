extends Control

@onready var crosshair_texture = $TextureRect
@export var textures_default: Array[Texture2D] = []
@export var textures_colliding: Array[Texture2D] = []
@export var textures_close: Array[Texture2D] = []


@export var interval := 0.2 # 12 FPS
var time_passed := 0.0
var current_index := 0

@export var raycast: RayCast3D #nao esquecer de arrastar o raycast3D objeto para o crosshair Inspector


var is_colliding_state := false
var space_held := false
var _force_colliding := false
var _force_dragging := false
var _lift_mode := false


func _ready():
	if textures_default.is_empty():
		textures_default = [
			load("res://assets/point_1.png"),
			load("res://assets/point_2.png"),
			load("res://assets/point_3.png"),
			load("res://assets/point_4.png"),
		]
	if textures_colliding.is_empty():
		textures_colliding = [
			load("res://assets/open_1.png"),
			load("res://assets/open_2.png"),
			load("res://assets/open_3.png"),
			load("res://assets/open_4.png"),
		]
	if textures_close.is_empty():
		textures_close = [
			load("res://assets/close_1.png"),
			load("res://assets/close_2.png"),
			load("res://assets/close_3.png"),
			load("res://assets/close_4.png"),
		]

	if not textures_default.is_empty():
		crosshair_texture.texture = textures_default[0]
		crosshair_texture.visible = true


func _input(event):
	if _lift_mode:
		return

	# Don't handle mouse motion, let it pass to camera
	if event is InputEventMouseMotion:
		return

	if event.is_action_pressed("ui_select") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		space_held = true
		_update_crosshair_immediate()
		_try_interact()
	elif event.is_action_released("ui_select") or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		space_held = false
		_update_crosshair_immediate()



func _update_crosshair_immediate():  #para ser imediato
	var textures_array: Array[Texture2D]

	if is_colliding_state:
		if space_held or _force_dragging:
			textures_array = textures_close
		else:
			textures_array = textures_colliding
	else:
		textures_array = textures_default

	if not textures_array.is_empty():
		crosshair_texture.texture = textures_array[current_index]




func _process(delta):
	var is_currently_colliding = false
	if not _lift_mode:
		is_currently_colliding = (_force_colliding) or (raycast and raycast.is_colliding()) #se existe e esta a colidir

	if is_currently_colliding != is_colliding_state:
		is_colliding_state = is_currently_colliding
		time_passed = 0.0
		current_index = 0

		if is_colliding_state:
			if not textures_colliding.is_empty():
				crosshair_texture.texture = textures_colliding[0]
		else:
			if not textures_default.is_empty():
				crosshair_texture.texture = textures_default[0]

	var textures_array: Array[Texture2D]
	if is_colliding_state and not _lift_mode:
		if space_held or _force_dragging:
			textures_array = textures_close
		else:
			textures_array = textures_colliding
	else:
		textures_array = textures_default


	if textures_array.is_empty():
		return

	time_passed += delta
	if time_passed >= interval:
		time_passed = 0.0
		current_index = (current_index + 1) % textures_array.size()
		crosshair_texture.texture = textures_array[current_index]


func _try_interact():
	if _lift_mode:
		return

	if not raycast or not raycast.is_colliding():
		return

	# Don't allow interaction during dialogue
	if _is_dialogue_active():
		return

	var collider = raycast.get_collider()
	if collider and collider.has_method("interact"):
		collider.interact()


func set_ui_hovering(enabled: bool) -> void:
	_force_colliding = enabled
	_update_crosshair_immediate()


func set_ui_dragging(dragging: bool) -> void:
	_force_dragging = dragging
	_update_crosshair_immediate()


func simulate_click(duration: float = 0.12) -> void:
	space_held = true
	_update_crosshair_immediate()
	await get_tree().create_timer(duration).timeout
	space_held = false
	_update_crosshair_immediate()


func _is_dialogue_active() -> bool:
	# Only block interaction when response choices are showing (cursor is hidden)
	# During regular dialogue text, cursor is captured and player can interact
	if DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_HIDDEN:
		return true

	return false


func set_lift_mode() -> void:
	_lift_mode = true
	# Load lift crosshair textures (non-interactive animated cursor)
	var frames: Array[Texture2D] = []
	var dir := DirAccess.open("res://assets/lift_crosshair")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				var tex = load("res://assets/lift_crosshair/" + file_name)
				if tex and tex is Texture2D:
					frames.append(tex)
			file_name = dir.get_next()
		dir.list_dir_end()

	frames.sort_custom(func(a, b): return a.resource_path < b.resource_path)
	if frames.is_empty():
		return

	textures_default = frames.duplicate()
	textures_colliding = frames.duplicate()
	textures_close = frames.duplicate()
	is_colliding_state = false
	space_held = false
	_force_colliding = false
	_force_dragging = false
	time_passed = 0.0
	current_index = 0
	if not textures_default.is_empty():
		crosshair_texture.texture = textures_default[0]

	# Make lift mode cursor bigger
	crosshair_texture.scale = Vector2(1.5, 1.5)
