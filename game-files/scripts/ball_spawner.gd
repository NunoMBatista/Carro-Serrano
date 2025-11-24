extends Node3D


var ball_scene = preload("res://scenes/ball.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("dev_spawn_ball"):
		_spawn_ball()



func _spawn_ball():
	var ball = ball_scene.instantiate()		# Create an instance
	ball.global_transform.origin = global_transform.origin + Vector3(randi()%2*0.5, 0, randi()%2*0.5)/20
	ball.linear_velocity = Vector3(randi()%2*0.2, randi()%2*0.2, randi()%2*0.2) * randf()*5
	get_tree().current_scene.add_child(ball)
