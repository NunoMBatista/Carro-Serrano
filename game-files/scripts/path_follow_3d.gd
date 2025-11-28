extends PathFollow3D

@export var cur_speed := 0.0

const MAX_SPEED := 3
const ACCEL_STRENGTH := 3.5
const BRAKE_STRENGTH := 6.0
const MIN_SPEED := 0.0
const FULLSTOP_SPEED := 0.5     # Speed at which the car suddenly stops and bounces back

func _process(delta):
	progress += cur_speed * delta

	# ---------- ACCELERATION (smooth / sigmoid-like) ----------
	# Exponential easing:
	#   diff = MAX_SPEED - cur_speed
	#   cur_speed += diff * (1 - exp(-ACCEL_STRENGTH * delta))
	# Large acceleration at low speeds, softer at high speeds.
	if not Input.is_action_pressed("Brakes"):
		var diff := MAX_SPEED - cur_speed
		cur_speed += diff * (1.0 - exp(-ACCEL_STRENGTH * delta))

	# ---------- BRAKING (reverse sigmoid behavior + full stop bounce) ----------
	else:
		# Normal braking curve:
		#   brake_power = BRAKE_STRENGTH * (cur_speed / MAX_SPEED)
		# Stronger brakes at high speeds, softer at low speeds.
		var brake_power := BRAKE_STRENGTH * (cur_speed / MAX_SPEED)
		cur_speed -= brake_power * delta

		# ---------- FULL STOP ----------
		# When speed gets very low during braking, real cars dip down
		# and rebound slightly when the suspension decompresses.
		#
		# We simulate that:
		#   - If speed falls below FULLSTOP_SPEED, full stop instantly
		if cur_speed <= FULLSTOP_SPEED:
			cur_speed = MIN_SPEED				# Full stop
