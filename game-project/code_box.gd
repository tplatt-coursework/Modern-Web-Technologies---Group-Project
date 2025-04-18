extends Node

# Naming convention: NS_ for Network Send
signal NS_run
signal NS_CodeBox()

# Naming convention: UC_ for User Code
signal UC_left(x)
signal UC_right(x)
signal UC_jump(x)

var player: Node = null
var user_code
var PROGRAM_COUNTER
var R_LEFT = RegEx.new()
var R_RIGHT = RegEx.new()
var R_JUMP = RegEx.new()
var R_INT = RegEx.new()

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
	user_code = PackedStringArray()
	R_LEFT.compile("move_left([0-9]*)")
	R_RIGHT.compile("move_right([0-9]*)")
	R_JUMP.compile("jump([0-9]*)")
	R_INT.compile("[0-9]+")
	
	#var root = get_tree().get_root()
	#var gamebox = _recursive_find_node(root, "GameBox")
	#if gamebox:
		#player = gamebox.get_node_or_null("player")

func _on_run_button_pressed() -> void:
	NS_CodeBox.emit($CodeEdit.text)
	NS_run.emit()
	run()

func run():
	PROGRAM_COUNTER = 0
	user_code.clear()
	user_code = $CodeEdit.text.split("\n")
	$Parse_Clock.start()

func _on_parse_clock_timeout() -> void:
	if PROGRAM_COUNTER < user_code.size():
		_parse_and_execute(user_code[PROGRAM_COUNTER].strip_edges())
		PROGRAM_COUNTER += 1
	else: 
		$Parse_Clock.stop()

func get_parameter(line):
	var param = R_INT.search(line)
	if param == null: 
		param = -1
	else: 
		param = int(param.get_string())
	return param

func _parse_and_execute(line: String):
	if R_LEFT.search(line):
		var param = get_parameter(line) *10
		print("main/CodeBox: emitting UC_left("+str(param)+")")
		UC_left.emit(param)
		
	elif R_RIGHT.search(line):
		var param = get_parameter(line) *10
		print("main/CodeBox: emitting UC_right("+str(param)+")")
		UC_right.emit(param)
	
	elif R_JUMP.search(line):
		var param = get_parameter(line) *10
		print("main/CodeBox: emitting UC_jump("+str(param)+")")
		UC_jump.emit(param)
		

func _on_network_timer_timeout() -> void:
	NS_CodeBox.emit($CodeEdit.text)



	
	#match line:
		#"jump()":
			#print("main/CodeBox: emitting UC_jump")
			#UC_jump.emit()
			###tried with player jump	
			##if player:
				##player.jump()
			#
		#"move_left()":
			#print("main/CodeBox: emitting UC_left")
			#UC_left.emit()
			#
		#"move_right()":
			#print("main/CodeBox: emitting UC_right")
			#UC_right.emit()
			#
			#
		#_:
			#print("main/CodeBox: Error: unknown command ", line)
