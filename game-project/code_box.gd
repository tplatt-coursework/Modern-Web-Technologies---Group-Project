extends Node

var player: Node = null

#just to find the player node....
func _recursive_find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _recursive_find_node(child, target_name)
		if found:
			return found
	return null

func _ready():
	var root = get_tree().get_root()
	var gamebox = _recursive_find_node(root, "GameBox")
	if gamebox:
		player = gamebox.get_node_or_null("player")

func _on_run_button_pressed() -> void:
	var user_code = $CodeEdit.text.split("\n")
	for line in user_code:
		_parse_and_execute(line.strip_edges())
	print(user_code)
	
func _parse_and_execute(line: String):
	match line:
		"jump()":
			#tried with player jump	
			if player:
				player.jump()
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
