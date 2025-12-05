extends PathFollow3D

<<<<<<< Updated upstream
@export var speed = 1.0
=======
@export var cur_speed := 0.0

const MAX_SPEED := 10
const ACCEL_STRENGTH := 3.5
const BRAKE_STRENGTH := 6.0
const MIN_SPEED := 0.0
const FULLSTOP_SPEED := 0.5     # Speed at which the car suddenly stops and bounces back
>>>>>>> Stashed changes

func _process(delta):
	progress += speed * delta
