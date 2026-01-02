extends Node3D

## Old Car Headlights Controller
## Simple toggle system for vintage incandescent headlights
## Press L to toggle headlights on/off

@export_group("Light Properties")
@export var light_color := Color(1.0, 0.85, 0.5)  ## Warm incandescent yellow
@export var light_energy := 80.0  ## Brightness of the headlights
@export var light_volumetric_fog_energy := 5.0  ## How lights interact with fog
@export var spot_range := 50.0  ## How far the light reaches
@export var spot_attenuation := 1.5  ## Light falloff (higher = faster falloff)
@export var spot_angle := 10.0  ## Cone width in degrees
@export var spot_angle_attenuation := 2.5  ## Edge sharpness
@export var shadow_enabled := true  ## Cast shadows

@export_group("Cone Mesh Appearance")
@export var cone_color := Color(1.0, 0.85, 0.5)  ## Beam color (RGB only)
@export var cone_alpha_near := 0.15  ## Opacity at light source (0-1)
@export var cone_alpha_far := 0.0  ## Opacity at far end (0-1)
@export var fade_duration := 0.5  ## Time in seconds for fade in/out

@onready var left_light: SpotLight3D = $LeftHeadlight
@onready var right_light: SpotLight3D = $RightHeadlight
@onready var left_cone: MeshInstance3D = $LeftHeadlight/ConeMesh
@onready var right_cone: MeshInstance3D = $RightHeadlight/ConeMesh

var lights_on := false
var current_fade := 0.0  ## 0.0 = off, 1.0 = full brightness

func _ready() -> void:
	_apply_light_properties()
	_apply_cone_properties()
	current_fade = 0.0
	_update_light_intensity(0.0)
	left_light.visible = true
	right_light.visible = true
	left_cone.visible = true
	right_cone.visible = true

func _apply_light_properties() -> void:
	for light in [left_light, right_light]:
		if light:
			light.light_color = light_color
			light.light_energy = light_energy
			light.light_volumetric_fog_energy = light_volumetric_fog_energy
			light.spot_range = spot_range
			light.spot_attenuation = spot_attenuation
			light.spot_angle = spot_angle
			light.spot_angle_attenuation = spot_angle_attenuation
			light.shadow_enabled = shadow_enabled

func _apply_cone_properties() -> void:
	# Calculate cone dimensions to match spotlight
	var cone_height = spot_range
	var cone_radius = spot_range * tan(deg_to_rad(spot_angle / 2.0)) * 0.75

	for cone in [left_cone, right_cone]:
		if cone:
			# Update mesh dimensions
			var mesh = cone.mesh as CylinderMesh
			if mesh:
				mesh.height = cone_height
				mesh.bottom_radius = cone_radius
				mesh.top_radius = 0.0

			# Position cone so it projects from the light
			cone.position.z = -cone_height / 2.0

			# Create or update material with gradient alpha
			var mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED

			# Create gradient texture for alpha fade
			var gradient = Gradient.new()
			var near_color = Color(cone_color.r, cone_color.g, cone_color.b, cone_alpha_near)
			var far_color = Color(cone_color.r, cone_color.g, cone_color.b, cone_alpha_far)
			gradient.set_color(0, near_color)  # Top (light source) - more opaque
			gradient.set_color(1, far_color)   # Bottom (far end) - transparent

			var gradient_texture = GradientTexture1D.new()
			gradient_texture.gradient = gradient

			mat.albedo_texture = gradient_texture
			mat.uv1_scale = Vector3(1, 1, 1)

			cone.material_override = mat

func _update_light_intensity(intensity: float) -> void:
	## Update light energy and cone alpha based on fade intensity (0.0 to 1.0)
	if left_light:
		left_light.light_energy = light_energy * intensity
	if right_light:
		right_light.light_energy = light_energy * intensity

	# Update cone materials with faded alpha
	for cone in [left_cone, right_cone]:
		if cone and cone.material_override:
			var mat = cone.material_override as StandardMaterial3D
			if mat and mat.albedo_texture:
				var gradient_texture = mat.albedo_texture as GradientTexture1D
				if gradient_texture and gradient_texture.gradient:
					var gradient = gradient_texture.gradient
					var near_color = Color(cone_color.r, cone_color.g, cone_color.b, cone_alpha_near * intensity)
					var far_color = Color(cone_color.r, cone_color.g, cone_color.b, cone_alpha_far * intensity)
					gradient.set_color(0, near_color)
					gradient.set_color(1, far_color)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_headlights"):
		toggle_lights()

	# Animate fade
	var target_fade = 1.0 if lights_on else 0.0
	if current_fade != target_fade:
		var fade_speed = 1.0 / fade_duration if fade_duration > 0 else 999.0
		if lights_on:
			current_fade = min(current_fade + fade_speed * _delta, 1.0)
		else:
			current_fade = max(current_fade - fade_speed * _delta, 0.0)
		_update_light_intensity(current_fade)

func toggle_lights() -> void:
	lights_on = !lights_on

func _set_lights_state(on: bool) -> void:
	if left_light:
		left_light.visible = on
	if right_light:
		right_light.visible = on
	if left_cone:
		left_cone.visible = on
	if right_cone:
		right_cone.visible = on
