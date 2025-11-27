extends PathFollow3D

@export var cur_speed = 5.0

const MAX_SPEED = 5.0
const BRAKE_SPEED = 0.01
const MIN_SPEED = 0


func _process(delta):
	progress += cur_speed * delta
	if Input.is_action_pressed("Brakes"):
		cur_speed = max(cur_speed - BRAKE_SPEED, MIN_SPEED)
	else:
		cur_speed = min(cur_speed + BRAKE_SPEED, MAX_SPEED)


		
