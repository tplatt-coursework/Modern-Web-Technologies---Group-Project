extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CodeBox/CodeEdit.editable = false
	$CodeBox/RunButton.disabled = true
	$CodeBox/Network_Timer.stop()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_code_box_uc_jump(x) -> void:
	$HBoxContainer/SubViewportContainer/SubViewport/GameBox/player.PC_jump(x)


func _on_code_box_uc_left(x) -> void:
	$HBoxContainer/SubViewportContainer/SubViewport/GameBox/player.PC_left(x)


func _on_code_box_uc_right(x) -> void:
	$HBoxContainer/SubViewportContainer/SubViewport/GameBox/player.PC_right(x)


func _on_code_box_ns_run() -> void:
	$NetworkingNode.send_run()


func _on_code_box_ns_code_box(x) -> void:
	$NetworkingNode.send_codebox(x)


func _on_networking_node_net_run() -> void:
	$CodeBox.run()


func _on_networking_node_net_code_box(x: Variant) -> void:
	$CodeBox/CodeEdit.text = str(x)


func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$CodeBox/CodeEdit.editable = true
		$CodeBox/RunButton.disabled = false
		$CodeBox/Network_Timer.start()
	if !toggled_on:
		$CodeBox/CodeEdit.editable = false
		$CodeBox/RunButton.disabled = true
		$CodeBox/Network_Timer.stop()
