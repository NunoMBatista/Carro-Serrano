extends Node3D

## Headlight Controller
## Toggles headlights on/off with the L key
## Creates two spotlights aimed at the ground in front of the car

## Headlight properties - easy to tune
@export_group("Light Properties")
@export var light_energy := 50.0  ## Brightness of the headlights
@export var light_range := 100.0  ## How far the light reaches
@export var spot_angle := 20.0  ## Cone width in degrees (narrower = more focused)
@export var spot_angle_attenuation := 3.0  ## Edge sharpness (higher = sharper cone edges)
@export var attenuation := 2.0  ## Light falloff (higher = faster falloff, more focused)

@export_group("Positioning")
@export var light_offset_x := 0.4  ## Left/right offset from center
@export var light_offset_y := 0.3  ## Height offset
@export var light_offset_z := 1.2  ## Forward offset from car origin
@export var aim_angle := 20.0  ## Downward angle in degrees (higher = aims lower)

@export_group("Appearance")
@export var light_color := Color(1.0, 0.95, 0.9)  ## Warm white color
@export var shadow_enabled := true  ## Cast shadows (performance cost)

var left_light: SpotLight3D
var right_light: SpotLight3D
var lights_on := false

func _ready() -> void:
	_create_headlights()
	_set_lights_state(false)

func _create_headlights() -> void:
	# Left headlight
	left_light = SpotLight3D.new()
	add_child(left_light)
	left_light.position = Vector3(-light_offset_x, light_offset_y, light_offset_z)
	left_light.rotation_degrees = Vector3(-aim_angle, 0, 0)
	_setup_light_properties(left_light)

	# Right headlight
	right_light = SpotLight3D.new()
	add_child(right_light)
	right_light.position = Vector3(light_offset_x, light_offset_y, light_offset_z)
	right_light.rotation_degrees = Vector3(-aim_angle, 0, 0)
	_setup_light_properties(right_light)

func _setup_light_properties(light: SpotLight3D) -> void:
	light.light_energy = light_energy
	light.light_color = light_color
	light.spot_range = light_range
	light.spot_angle = spot_angle
	light.spot_attenuation = attenuation
	light.spot_angle_attenuation = spot_angle_attenuation
	light.shadow_enabled = shadow_enabled

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_headlights"):
		toggle_lights()

func toggle_lights() -> void:
	lights_on = !lights_on
	_set_lights_state(lights_on)

func _set_lights_state(on: bool) -> void:
	if left_light:
		left_light.visible = on
	if right_light:
		right_light.visible = on
