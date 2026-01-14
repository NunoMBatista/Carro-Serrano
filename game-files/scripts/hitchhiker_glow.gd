extends Node3D

@export var glow_color: Color = Color(0.4, 0.5, 0.8, 1.0)
@export var glow_energy: float = 3.0
@export var glow_range: float = 3.0

var _glow_light: OmniLight3D = null

func _ready() -> void:
	# Create a glowing light that follows the hitchhiker
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = glow_color
	_glow_light.light_energy = glow_energy
	_glow_light.omni_range = glow_range
	_glow_light.omni_attenuation = 2.0
	_glow_light.shadow_enabled = false

	# Position the light at the hitchhiker's center (roughly chest height)
	_glow_light.position = Vector3(0, 1.2, 0)

	add_child(_glow_light)
	print("Hitchhiker glow light created - Color: ", glow_color, " Energy: ", glow_energy)
