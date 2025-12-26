extends Node
## FogController
## Links fog density (and optional light volumetric fog) to empathy.
## Lower empathy -> thicker fog. Higher empathy -> lighter fog.

@export var world_environment_path: NodePath
@export var directional_light_path: NodePath

## Fog density range (Environment.volumetric_fog_density)
@export var min_density: float = 0.02   # lightest fog
@export var max_density: float = 0.18   # densest fog

## Optional light volumetric contribution (DirectionalLight3D.light_volumetric_fog_energy)
## Leave both at 0 to keep lights unchanged.
@export var min_light_volumetric: float = 0.0
@export var max_light_volumetric: float = 0.3

## Smoothing (seconds). Set to 0 for instant jumps.
@export var smoothing_time: float = 0.2

var _env: Environment
var _light: DirectionalLight3D
var _df  # DialogueFlow autoload
var _gm  # GameManager autoload
var _density: float
var _light_vol: float

func _ready() -> void:
	_df = get_node_or_null("/root/DialogueFlow")
	_gm = get_node_or_null("/root/GameManager")
	_env = _resolve_environment()
	_light = _resolve_light()
	_density = _env.volumetric_fog_density if _env else min_density
	_light_vol = _light.light_volumetric_fog_energy if _light else min_light_volumetric
	set_process(_env != null)

func _process(delta: float) -> void:
	if not _env:
		return

	var empathy := _get_empathy()
	var t: float = clamp(empathy / 100.0, 0.0, 1.0)  # 0 = lowest empathy, 1 = highest

	var target_density: float = lerp(max_density, min_density, t)
	_density = _smooth(_density, target_density, delta)
	_env.volumetric_fog_density = _density

	if _light:
		var target_light: float = lerp(max_light_volumetric, min_light_volumetric, t)
		_light_vol = _smooth(_light_vol, target_light, delta)
		_light.light_volumetric_fog_energy = _light_vol

func _resolve_environment() -> Environment:
	var env_node: WorldEnvironment = null
	if world_environment_path != NodePath():
		env_node = get_node_or_null(world_environment_path)
	if env_node == null:
		env_node = get_tree().current_scene.get_node_or_null("WorldEnvironment")
	if env_node and env_node is WorldEnvironment:
		return env_node.environment
	return null

func _resolve_light() -> DirectionalLight3D:
	if directional_light_path == NodePath():
		return null
	var n = get_node_or_null(directional_light_path)
	return n if n is DirectionalLight3D else null

func _get_empathy() -> float:
	if _df:
		return float(_df.empathy)
	if _gm and _gm.has_variable("empathy_score"):
		return float(_gm.empathy_score)
	return 50.0

func _smooth(current: float, target: float, delta: float) -> float:
	if smoothing_time <= 0.0:
		return target
	var alpha: float = clamp(delta / smoothing_time, 0.0, 1.0)
	return lerp(current, target, alpha)
