extends Node3D

# This is the variable you want to change
@onready var empathy_score: int = 0

# Optional: A helper function if you want to print logic
func change_empathy(amount: int):
	empathy_score += amount
	print("Empathy is now: ", empathy_score)

func _process(delta: float) -> void:
	prints("gangsta: ", empathy_score)
