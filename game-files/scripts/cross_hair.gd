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
		if space_held:
			textures_array = textures_close
		else:
			textures_array = textures_colliding
	else:
		textures_array = textures_default

	if not textures_array.is_empty():
		crosshair_texture.texture = textures_array[current_index]




func _process(delta):
	var is_currently_colliding = (_force_colliding) or (raycast and raycast.is_colliding()) #se existe e esta a colidir

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
	if is_colliding_state:
		if space_held:
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
	if not raycast or not raycast.is_colliding():
		return

	var collider = raycast.get_collider()
	if collider and collider.has_method("interact"):
		collider.interact()


func set_ui_hovering(enabled: bool) -> void:
	_force_colliding = enabled
	_update_crosshair_immediate()


func simulate_click(duration: float = 0.12) -> void:
	space_held = true
	_update_crosshair_immediate()
	await get_tree().create_timer(duration).timeout
	space_held = false
	_update_crosshair_immediate()
