extends StaticBody3D

@export var dialogue: DialogueResource


func interact():
	print("bebe foi tocado")
	DialogueManager.show_dialogue_balloon(dialogue)
	
	
