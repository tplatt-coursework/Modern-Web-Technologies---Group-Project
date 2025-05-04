extends Control



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AudioStreamPlayer2D.volume_db = global.musicVolume
	if global.isDriver: 
		print("Driver")
		$GameBox/NavMap.visible = false
		$CanvasLayer/CodeBox/CodeEdit.editable = true
		$CanvasLayer/CodeBox/RunButton.disabled = false
		$CanvasLayer/CodeBox/Network_Timer.start()
	elif global.isNavigator: 
		print("Navigator")
		$GameBox/NavMap.visible = true
		$CanvasLayer/CodeBox/CodeEdit.editable = false
		$CanvasLayer/CodeBox/RunButton.disabled = true
		$CanvasLayer/CodeBox/Network_Timer.stop()
	else: 
		print("No role")
		$GameBox/NavMap.visible = true
		$CanvasLayer/CodeBox/CodeEdit.editable = false
		$CanvasLayer/CodeBox/RunButton.disabled = true
		$CanvasLayer/CodeBox/Network_Timer.stop()
		
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$CanvasLayer/NetworkData.text = $NetworkingNode/Connection_Status.text
	if Input.is_action_just_pressed("Pause"):
		pauseMenu()
	pass

var pause = false 
func pauseMenu():
	if pause:
		$CanvasLayer/ESCMenu.hide()
	else:
		$CanvasLayer/ESCMenu.show()
	pause = !pause


func _on_code_box_uc_jump(x) -> void:
	$GameBox/player.PC_jump(x)


func _on_code_box_uc_left(x) -> void:
	$GameBox/player.PC_left(x)


func _on_code_box_uc_right(x) -> void:
	$GameBox/player.PC_right(x)


func _on_code_box_ns_run() -> void:
	$NetworkingNode.send_run()


func _on_code_box_ns_code_box(x) -> void:
	$NetworkingNode.send_codebox(x)


func _on_networking_node_net_run() -> void:
	$CanvasLayer/CodeBox.run()


func _on_code_box_uc_reset() -> void:
	$GameBox/player.position = $GameBox/Spawnpoint.position
	$GameBox/player.PC_reset()


func _on_networking_node_net_code_box(x: Variant) -> void:
	$CanvasLayer/CodeBox/CodeEdit.text = str(x)


#func _on_check_button_toggled(toggled_on: bool) -> void:
	#if toggled_on:
		#$CanvasLayer/CodeBox/CodeEdit.editable = true
		#$CanvasLayer/CodeBox/RunButton.disabled = false
		#$CanvasLayer/CodeBox/Network_Timer.start()
		#isNavigator = false
		#isDriver = true
	#if !toggled_on:
		#$CanvasLayer/CodeBox/CodeEdit.editable = false
		#$CanvasLayer/CodeBox/RunButton.disabled = true
		#$CanvasLayer/CodeBox/Network_Timer.stop()
		#isNavigator = true
		#isDriver = false
	#if isDriver: 
		#$GameBox/NavMap.visible = false
	#else: 
		#$GameBox/NavMap.visible = true


func _on_code_box_uc_syntax_error(pc, x, clear):
	if !clear:
		$CanvasLayer/ErrorOutput.text = "Syntax Error on line "+str(pc+1)+": "+str(x)
	else: 
		$CanvasLayer/ErrorOutput.text = ""


func _on_esc_menu_volume() -> void:
	$AudioStreamPlayer2D.volume_db = global.musicVolume
	pass # Replace with function body.


func _on_esc_menu_net_toggle() -> void:
	if global.showNet:
		$CanvasLayer/NetworkData.show()
		$CanvasLayer/NetworkInfo.show()
	else:
		$CanvasLayer/NetworkData.hide()
		$CanvasLayer/NetworkInfo.hide()
