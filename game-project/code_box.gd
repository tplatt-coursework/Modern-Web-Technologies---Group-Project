extends Node

# Naming convention: NS_ for Network Send
signal NS_run
signal NS_CodeBox()

# Naming convention: UC_ for User Code
signal UC_left(x)
signal UC_right(x)
signal UC_jump(x)
signal UC_reset()
signal UC_syntax_error(pc,x)

var player: Node = null
var user_code
var PROGRAM_COUNTER
var R_LEFT = RegEx.new()
var R_RIGHT = RegEx.new()
var R_JUMP = RegEx.new()
var R_RJUMP = RegEx.new()
var R_LJUMP = RegEx.new()
var R_INT = RegEx.new()
var R_WAIT = RegEx.new()
var R_RESET = RegEx.new()

@onready var esc_menu = $ESCMenu
var pause = false 

func _process(delta):
	if Input.is_action_just_pressed("Pause"):
		pauseMenu()

func pauseMenu():
	if pause:
		esc_menu.hide()
	else:
		esc_menu.show()
		
	pause = !pause
		


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
	R_LEFT.compile("\\bmove_left\\([0-9]*\\)")
	R_RIGHT.compile("\\bmove_right\\([0-9]*\\)")
	R_RJUMP.compile("\\bjump_right\\([0-9]*\\)")
	R_LJUMP.compile("\\bjump_left\\([0-9]*\\)")
	R_JUMP.compile("\\bjump\\([0-9]*\\)")
	R_INT.compile("[0-9]+")
	R_RESET.compile("\\breset\\(\\)")
	R_WAIT.compile("\\bwait\\([0-9]*\\)")
	
	#var root = get_tree().get_root()
	#var gamebox = _recursive_find_node(root, "GameBox")
	#if gamebox:
		#player = gamebox.get_node_or_null("player")

func _on_run_button_pressed() -> void:
	UC_syntax_error.emit(0,"",true)
	NS_CodeBox.emit($CodeEdit.text)
	NS_run.emit()
	run()

func run():
	$Parse_Clock.stop()
	$Parse_Clock.set_wait_time(0.5)
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
		var param = get_parameter(line)
		print("main/CodeBox: emitting UC_left("+str(param)+")")
		UC_left.emit(param)
		
	elif R_RIGHT.search(line):
		var param = get_parameter(line)
		print("main/CodeBox: emitting UC_right("+str(param)+")")
		UC_right.emit(param)
	
	elif R_RJUMP.search(line):
		var param = get_parameter(line)
		print("main/CodeBox: emitting UC_jump("+str(param)+")")
		print("main/CodeBox: emitting UC_right("+str(param)+")")
		UC_jump.emit(param)
		UC_right.emit(param)
		
	elif R_LJUMP.search(line):
		var param = get_parameter(line)
		print("main/CodeBox: emitting UC_jump("+str(param)+")")
		print("main/CodeBox: emitting UC_left("+str(param)+")")
		UC_jump.emit(param)
		UC_left.emit(param)
	
	elif R_JUMP.search(line):
		var param = get_parameter(line)
		print("main/CodeBox: emitting UC_jump("+str(param)+")")
		UC_jump.emit(param)

	elif R_RESET.search(line):
		UC_reset.emit()
	
	elif R_WAIT.search(line):
		$Parse_Clock.stop()
		$Parse_Clock.set_wait_time(0.5)
		var param = get_parameter(line)
		if param == null: param = 1
		await get_tree().create_timer(param).timeout
		$Parse_Clock.start()
	
	else: 
		$Parse_Clock.stop()
		print("main/CodeBox: Syntax Error on line "+str(PROGRAM_COUNTER+1)+": "+str(line))
		UC_syntax_error.emit(PROGRAM_COUNTER,line,false)


func _on_network_timer_timeout() -> void:
	NS_CodeBox.emit($CodeEdit.text)
