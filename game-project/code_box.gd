extends Node

func _on_run_button_pressed() -> void:
	var user_code = $CodeEdit.text.split("\n")
	for line in user_code:
		_parse_and_execute(line.strip_edges())
	print(user_code)
	
func _parse_and_execute(line: String):
	match line:
		"jump()":
			print("jumping")
			# call  jump function here
		"move_left()":
			print("moving 1 unit left")
			# call move left function here
		"move_right()":
			print("moving 1 unit right")
			# call move right function here
		_:
			print("Error: unknown command ", line)
