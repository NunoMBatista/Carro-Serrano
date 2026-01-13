extends Node3D

@export var rotation_speed: float = 2.0  # Radians per second (Z-axis rotation)
@export var bob_speed: float = 2.0  # Frequency of up/down bobbing
@export var bob_distance: float = 1.0  # How far to bob up and down

var _initial_position: Vector3
var _sketchfab_scene: Node3D


func _ready() -> void:
	_sketchfab_scene = get_node_or_null("Sketchfab_Scene")
	if _sketchfab_scene:
		_initial_position = _sketchfab_scene.position
	else:
		push_warning("Sketchfab_Scene node not found as child of arrow")

func _process(delta: float) -> void:
	if _sketchfab_scene == null:
		return

	# Rotate on Z axis
	_sketchfab_scene.rotation.y += rotation_speed * delta

	# Bob up and down using sin function
	var bob_offset = sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_distance + bob_distance/2
	_sketchfab_scene.position = _initial_position + Vector3(0, bob_offset, 0)
