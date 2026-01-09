extends Node3D
class_name CarInteriorCollision

## Adds simple collision shapes for car interior to prevent objects from falling through
## Attach this to your car and configure the collision boxes in the inspector

@export_group("Passenger Area")
@export var passenger_floor_size: Vector3 = Vector3(1.5, 0.1, 1.0)
@export var passenger_floor_offset: Vector3 = Vector3(0.5, 0.0, 0.0)

@export_group("Driver Area")
@export var driver_floor_size: Vector3 = Vector3(1.5, 0.1, 1.0)
@export var driver_floor_offset: Vector3 = Vector3(-0.5, 0.0, 0.0)

@export_group("Dashboard")
@export var enable_dashboard_collision: bool = true
@export var dashboard_size: Vector3 = Vector3(2.0, 0.3, 0.5)
@export var dashboard_offset: Vector3 = Vector3(0.0, 0.5, -0.8)

@export_group("Seats")
@export var enable_seat_collision: bool = true
@export var passenger_seat_size: Vector3 = Vector3(0.5, 0.4, 0.5)
@export var passenger_seat_offset: Vector3 = Vector3(0.5, 0.2, 0.2)
@export var driver_seat_size: Vector3 = Vector3(0.5, 0.4, 0.5)
@export var driver_seat_offset: Vector3 = Vector3(-0.5, 0.2, 0.2)

var collision_bodies: Array[StaticBody3D] = []

func _ready() -> void:
	# Create floor collision for passenger area
	_create_collision_box("PassengerFloor", passenger_floor_size, passenger_floor_offset)

	# Create floor collision for driver area
	_create_collision_box("DriverFloor", driver_floor_size, driver_floor_offset)

	# Create dashboard collision
	if enable_dashboard_collision:
		_create_collision_box("Dashboard", dashboard_size, dashboard_offset)

	# Create seat collisions
	if enable_seat_collision:
		_create_collision_box("PassengerSeat", passenger_seat_size, passenger_seat_offset)
		_create_collision_box("DriverSeat", driver_seat_size, driver_seat_offset)

	print("Car interior collision helper initialized with ", collision_bodies.size(), " collision boxes")

func _create_collision_box(box_name: String, size: Vector3, offset: Vector3) -> StaticBody3D:
	# Create static body
	var static_body = StaticBody3D.new()
	static_body.name = box_name
	add_child(static_body)

	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	collision_shape.position = offset
	static_body.add_child(collision_shape)

	# Set collision layers - same as car body
	static_body.collision_layer = 1
	static_body.collision_mask = 0

	# Optional: Add visual debug mesh (comment out for production)
	if OS.is_debug_build():
		_add_debug_visual(static_body, size, offset)

	collision_bodies.append(static_body)
	return static_body

func _add_debug_visual(parent: Node3D, size: Vector3, offset: Vector3) -> void:
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size

	# Semi-transparent material for debugging
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.8, 0.2, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.position = offset
	parent.add_child(mesh_instance)

## Call this to adjust collision boxes at runtime if needed
func adjust_collision(box_name: String, new_size: Vector3, new_offset: Vector3) -> void:
	for body in collision_bodies:
		if body.name == box_name:
			var collision_shape = body.get_child(0) as CollisionShape3D
			if collision_shape and collision_shape.shape is BoxShape3D:
				collision_shape.shape.size = new_size
				collision_shape.position = new_offset
			break
